.code32
.text
.globl startup_32, idt, gdt, pg_dir, tmp_floppy_area

pg_dir:
startup_32:
    # 执行上下文指向代码段
    movl $0x10, %eax
    movw %ax,   %ds
    movw %ax,   %es
    movw %ax,   %fs
    movw %ax,   %gs

    # 设置堆栈指针
    lss  stack_start, %esp

    # 设置idt和gdt
    call setup_idt
    call setup_gdt

    jmp  after_page_tables


# 所有idt元素的内容都是一样，都指向ignore_int
setup_idt:
    leal ignore_int, %edx
    movl $0x00080000, %eax
    movw %dx, %ax
    movw $0x8e00, %dx
    leal idt, %edi
    movl $256, %ecx
rp_sidt:
    movl %eax, (%edi)
    movl %edx, 4(%edi)
    addl $8, %edi
    decl %ecx
    jne  rp_sidt
    lidt idt_descr
    ret

setup_gdt:
    lgdt gdt_descr
    ret

.org 0x1000
pg0:

.org 0x2000
pg1:

.org 0x3000
pg2:

.org 0x4000
pg3:

.org 0x5000

tmp_floppy_area:
.fill 1024, 1, 0

after_page_tables:
/* jump to main here */
    pushl $0
    pushl $0
    pushl $0
    pushl $L6       # main的返回地址， 实际上push + jmp 就等于call
    pushl $main
    jmp setup_paging
L6:
    jmp L6

ignore_int:
    /* we do not have function _printk now, so trick it */
    pushl %eax
    pushl %ecx
    pushl %edx
    pushw %ds
    pushw %es
    pushw %fs
    movl  $0x10, %eax
    movw  %ax, %ds
    movw  %ax, %es
    movw  %ax, %fs
    # gs切换到frame buffer段, write a 'I' char to frame buffer
    movl $0x18, %eax
    movw %ax, %gs
    movl  $0x96, %edi
    movb  $'R', %al
    movb  $0x0c, %ah
    movw  %ax,   %gs:(%edi)
    popw  %fs
    popw  %es
    popw  %ds
    popl  %edx
    popl  %ecx
    popl  %eax
    iret

/*
 * 设置页目录（Page Directory）和页表（Page Table）
 * 打开分页机制（启用 CR0 的 PG 位）
 * 映射内核最初的物理内存页，使其线性地址 = 物理地址（即恒等映射 identity mapping）
 */
.align 4
setup_paging:
    movl $1024*5, %ecx          # 每个页表项占用4个字节，这里一个页包含1024项，共5个页(pg_dir(0地址) + pg0 + pg1 + pg2 + pg3)
    xorl %eax,     %eax
    xorl %edi,     %edi
    cld                         # 确保方向标志为“递增”
    rep                         # rep stosl：用 `eax=0` 向 `edi=0` 开始的位置连续写入 5120 个 DWORD（= 20KB），全部清零
    stosl
    # 将前4个页表地址填入页目录的前4项中
    # +7 表示将低三位设置为 111b，意味着：
    #   Present（P）=1
    #   Read/Write（R/W）=1
    #   User/Supervisor（U/S）=1
    #   所以页表可读写，且对用户空间可访问
    movl $pg0 + 7, pg_dir
    movl $pg1 + 7, pg_dir + 4
    movl $pg2 + 7, pg_dir + 8
    movl $pg3 + 7, pg_dir + 12

    movl $pg3 + 4092, %edi  # %edi = pg3 + 4092`：从 `pg3` 页表的最后一项开始写（逆序写入）
    movl $0xfff007, %eax    # 高位 20 bits 是物理地址：`0xFFF000 = 16MB - 4KB`; 低 12 bits 是页属性（`111b`）
    std                     # `std` + `stosl`：反向写入（`std` 设置方向标志递减）
1:
    stosl
    subl $0x1000, %eax      # 每次`stosl`后,`eax -= 0x1000`（减少一页大小），写下一页
    jge  1b                 # 当`eax`小于0时结束

    xorl %eax, %eax
    movl %eax, %cr3         # 设置页目录基地址：将 CR3 设置为 0，即页目录位于物理地址 0x00000000
    movl %cr0, %eax
    orl  $0x80000000, %eax
    movl %eax, %cr0         # 设置 `CR0` 寄存器的 PG 位（最高位）为 1，打开分页机制

    ret                     # 这个ret很关键, 返回到调用栈中保留的main开始地址 ———— 执行main
    
.align 4
.word 0
idt_descr:
    .word 256*8-1
    .long idt

.align 4
.word 0
gdt_descr:
    .word 256 * 8 - 1
    .long gdt

.align 8
idt:
    .fill 256, 8, 0

gdt:
    .quad 0x0000000000000000
    .quad 0x00c09a0000000fff
    .quad 0x00c0920000000fff
    .quad 0x00c0f20b8000ffff
    .quad 0x0000000000000000
    .fill 251, 8,0

