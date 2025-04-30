INITSEG = 0x9000
SYSSEG  = 0x1000
SETUPSEG = 0x9020

.code16
.text
.globl _start_setup

_start_setup:
    movw %cs, %ax
    movw %ax, %ds
    movw %ax, %es

    # print setup module notice info
    movw $setup_msg, %ax
    movw %ax, %bp
    movw $0x01301, %ax
    movw $0x0c, %bx
    movw $16, %cx
    movb $3, %dh
    movb $0, %dl
    int  $0x010

    # goto 0x9000, rewrite bootsect zone by hw info
    movw $INITSEG, %ax
    movw %ax, %ds

    # get cursor pos and shape
    movb $0x03, %ah     # int 0x10 func id: get cursor position and shape
    xor  %bh,  %bh
    int  $0x10
    movw %dx, (0)       # save cursor position to 0x9000:0 addr

    # get extended memory size (beyond 640k)
    movb $0x88, %ah
    int  $0x15
    movw %ax, (2)       # save extend memory size(KB) to 0x9000:2 addr
    
    # get current video mode
    movb $0x0f, %ah
    int  $0x10
    movw %bx, (4)       # video mode & cursor page
    movw %ax, (6)       # video page(usually 0)

    movb $0x12, %ah     # vesa extend
    movb $0x10, %bl     # get ega/vga info
    int  $0x10
    movw %ax, (8)       # EGA>VGA hardware cap
    movw %bx, (10)      # number of frame bufer page and hardware info
    movw %cx, (12)
    movw $0x5019, (14)  # a magic number for PS/2 machine flag

    # copy 1st hard disk parms(create by bios) to 0x9000:0080
    movw $0x0000, %ax
    movw %ax, %ds
    ldsw (4 * 0x41), %si
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0080, %di
    movw $0x10, %cx     #copy size 16 bytes
    rep
    movsb

    /* get 2st hard disk parms(create by bios) */
    movw $0x0000, %ax
    movw %ax, %ds
    ldsw (4 * 0x46), %si
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0090, %di
    movw $0x10, %cx
    rep
    movsb

    # check if bios support 2st harddisk and 2st harddisk present
    movw $0x1500, %ax   #ah=0x15, Disk System Extensions - Check Extensions Present
    movb $0x81, %dl     # 0x00 the first floppy, 0x80 the first harddisk, 0x81 the 2st harddisk
    int  $0x13          # 0x13 is floppy/harddisk int service of bios
    jc   no_disk1       # if 0x13 service is success, CF=0, and ah return the ret code
    cmpb $3, %ah
    je   is_disk1

    # clear 2st hard disk parms
no_disk1:
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0090, %di
    movw $0x10, %cx
    movw $0x00, %ax
    rep
    stosb

is_disk1:
    /* prepare for protection mode */
    cli                 # Clear Interrupt Flag
    
    movw $0x0000, %ax
    cld                 # Clear Direction Flag, set string addr from low to high

    /* move system image from 0x1000:0x0000(64KB begin) to 0x0000:0x0000, size is 0x8000 */
do_move:
    movw %ax, %es
    addw $0x1000, %ax
    cmpw $0x9000, %ax
    jz   end_move
    movw %ax, %ds
    subw %di, %di
    subw %si, %si
    movw $0x8000, %cx
    rep
    movsw
    jmp  do_move

end_move:
    # print "setup is running"
    movw $0xb800, %ax       #text mode frame buffer segment base
    movw %ax, %gs
    movb $0xf, %ah          # the properties of char "A", eg: color ....
    movb $0x41, %al         # char A
    movl $0x100, %edi       # the 128st byte of frame buffer
    movw %ax, %gs:(%di)     # wirte char "A" and properties to frame buffer

    # load gdt
    movw $SETUPSEG, %ax
    movw %ax, %ds
    lidt idt_48             # load a null int desp table, bacause int are not enabled
    lgdt gdt_48             # load global desp table

    # open a20 address bus
    call empty_8042
    movb $0xD1, %al
    outb %al,  $0x64        # write 0xd1 to 0x64 port, prepare write
    call empty_8042
    movb $0xDF, %al
    outb %al,  $0x60        # open A20 bus
    call empty_8042

    # config PIC - 8259, BIOS默认情况下，硬件中断的中断号是0x08开始（硬件中断号和CPU异常重叠了，比如8号是双错异常）。
    # Linux重映射PIC，使硬件中断起始从0x20（32）开始，避免和CPU异常冲突。
    # 过程：
    /*
     * | 阶段   | 主 PIC 端口 | 从 PIC 端口 | 作用                                 |
     * |--------|-------------|-------------|--------------------------------------|
     * | ICW1   | `outb $0x11, $0x20` | `outb $0x11, $0xA0` | 初始化，边沿触发，要求 ICW4         |
     * | ICW2   | `outb $0x20, $0x21` | `outb $0x28, $0xA1` | IRQ 中断向量起始号                  |
     * | ICW3   | `outb $0x04, $0x21` | `outb $0x02, $0xA1` | 主从连接关系设置（级联 IR2）        |
     * | ICW4   | `outb $0x01, $0x21` | `outb $0x01, $0xA1` | 8086 模式运行                        |
     */
    movb $0x11, %al
    outb %al,  $0x20            # init cmd for master pic
    .word 0x00eb, 0x00eb        # short delay
    outb %al,  $0xA0            # init cmd for slave pic
    .word 0x00eb, 0x00eb

    movb $0x20, %al             # Master起始中断向量号 0x20 (32)
    outb %al, $0x21
    .word 0x00eb, 0x00eb
    movb $0x28, %al
    outb %al,   $0xA1           # Slave起始中断向量号 0x28 (40)
    .word 0x00eb, 0x00eb

    movb $0x04, %al             # 0x04 = 00000100b，表示 IR2（第3位）被用来连接从 PIC
    outb %al, $0x21             # 主 PIC 告诉自己“从 PIC 接在我的 IR2（IRQ2）线上
    .word 0x00eb, 0x00eb
    movb $0x02, %al
    outb %al, $0xA1             # 从 PIC 告诉自己“我被连接到主 PIC 的 IRQ2（IR编号2）
    
    .word 0x00eb, 0x00eb
    movb $0x01, %al
    outb %al, $0x21
    .word 0x00eb, 0x00eb
    outb %al, $0xA1             # int finish

    .word 0x00eb, 0x00eb
    movb $0xff, %al
    outb %al, $0x21             # forbiden int
    .word 0x00eb, 0x00eb
    outb %al, $0xA1

    # enter protected mode(set PE<protection enable>)
    movl %cr0, %eax
    xorb $1, %al
    movl %eax, %cr0

    # jmp to head.s entry
    .byte 0x66, 0xea        # 0x66, 操作数大小前缀（32位指令）, 0xea, ljmp指令（远跳转）
    # ljmp to 段选择子 0x08（the first entry of gdt 代码段）: 偏移0x00000000
    .long 0x0
    .word 0x8

# wait 8042 intput buffer null, we could send cmd continue
empty_8042:
    .word 0x00eb, 0x00eb    #0x00eb is the machine code of instruction "jmp $+0", here used to little delay
    inb $0x64, %al
    testb $2, %al
    jnz empty_8042
    ret

gdt:
    # null seg
    .word 0,0,0,0
    # code seg
    .word 0x07ff
    .word 0x0000
    .word 0x9A00
    .word 0x00C0
    # data seg
    .word 0x07ff
    .word 0x0000
    .word 0x9200
    .word 0x00c0
    # a seg for frame buffer
    .word 0xffff
    .word 0x8000
    .word 0x920b
    .word 0x00c0
idt_48:
    .word 0
    .word 0,0
gdt_48:
    .word 0x800                 # size of gdt
    .word 512+gdt, 0x9          # addr of gdt

setup_msg:
  .ascii "setup is running"


