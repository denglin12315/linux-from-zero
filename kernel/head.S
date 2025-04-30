.code32
.text
.global startup_32

startup_32:
    movl $0x10, %eax    /* data seg seletor(2st gdt element) */
    movw %ax,%ds
    movw %ax,%es
    movw %ax,%fs
    movl $0x18, %eax    /* frame buffer seg seletor(3st gdt element) */
    movw %ax, %gs

    /* 构造一个idt */
    call setup_idt
    int $0x80           # descriptor_address = IDT_base + 0x80 * 8

    movl $0x18, %eax
    movw %ax,%gs
    movl $0x0, %edi
    movb $0xf, %ah
    movb $0x42, %al
    movw %ax, %gs:(%edi)
loop:
    jmp loop

setup_idt:
    leal ignore_int, %edx   # 中断处理函数 ignore_int 的地址加载到 %edx
    movl $0x00080000, %eax  # 这里的seletor字段是8意味着，当这个中断发生的时候，用该selector找到GDT中对应
                            # 描述符，就找到了该中断你的处理函数所在的内存地址
    movw %dx, %ax           # 到这里%eax变成: [segment selector: 0x0008] [16-bit offset]
    movw $0x8e00, %dx       # 设置 IDT 描述符的属性位
    leal idt, %edi          # 把IDT的起始地址加载到 %edi，用于后续向 IDT 表写入内容
    movl $256, %ecx         # 一次写256个IDT element
rp_sidt:
    /* 写一个idt element */
    movl %eax, (%edi)
    movl %edx, 4(%edi)
    /* 移动到下一个idt element */
    addl $8, %edi
    decl %ecx       # 待填充的表项数目减1
    jne rp_sidt

    /* 重新加载新的idt */
    lidt idt_descr
    ret

setup_gdt:
    lgdt gdt_descr
    ret

/* 我们现在还没有printk函数，通过向显存直接写入字符来模拟它 */
ignore_int:
    # 中断现场保存
    pushl %eax
    pushl %ecx
    pushl %edx
    pushw %ds
    pushw %es
    pushw %fs
    # 切换到frame buffer
    movl $0x10, %eax
    movw %ax, %ds
    movw %ax, %es
    movw %ax,%fs
    # 调用printk函数
    movl $0x96, %edi
    movb $'D', %al
    movb $0x0c, %ah
    movw %ax, %gs:(%edi)

    # 中断退出恢复现场
    popw %fs
    popw %es
    popw %ds
    popl %edx
    popl %ecx
    popl %eax
    iret

.align 4
.word 0
idt_descr:
    .word 256 *8-1
    .long idt

.align 4
.word 0
gdt_descr:
    .word 256 * 8 - 1
    .long gdt

.align 8
idt:
    .fill 256,8,0

/*
 * gdt在setup.S中已经被配置过了，为什么在head.S中还要重新配置一次(两次配置完全一样)?
 * 原因是setup中使用的GDT位于setup所在的内存，也就是0x90200位置，但是内核真正运行起来
 * 以后的GDT应该位于内核数据结构中，所以进入head.S以后就需要重新设置，设置很简单，只需
 * 要和setup中的GDT保持一致就行了
 */
gdt:
    .quad 0x0000000000000000
    .quad 0x00c09a0000000fff
    .quad 0x00c0920000000fff
    .quad 0x00c0f20b8000ffff
    .quad 0x0000000000000000
    .fill 251, 8,0

