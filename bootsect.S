SYSSIZE = 0x3000
SETUPLEN = 4
BOOTSEG = 0x7c0
INITSEG = 0x9000
SETUPSEG = 0x9020
SYSSEG = 0x1000
ENDSEG = SYSSEG + SYSSIZE
ROOT_DEV = 0x0000

.code16
.text

.global _start

# the entry of bootsect
_start:
    jmpl $BOOTSEG, $start2

# move bootsect itself from 0x7c00 to 0x90000
start2:
    movw $BOOTSEG, %ax  # src
    movw %ax, %ds
    movw $INITSEG, %ax  # dest
    movw %ax, %es
    movw $256,%cx       # size
    subw %si, %si       # clr %si
    subw %di, %di       # clr %di

    rep                 # repeat exec the next inst until %cx is 0
    movsw               # mov dword, [ds:si] -> [es:di]

# goto 0x90000
    jmpl $INITSEG, $go
go:
    # set seg selector and sp
    movw %cs, %ax       # 0x9000
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movw $0xFF00, %sp   # stack 0x9000:0xff00

load_setup:
    movw $0x0000, %dx   # dl=0 means the first floppy or harddisk
    movw $0x0002, %cx   # ch=0 means sylinder num, cl=2 means the 2st sector
    movw $0x0200, %bx   # read 2st sector data to [es:bx] -> [0x9000:0x200]
    # read floppy or harddisk
    movb $SETUPLEN, %al # the num of sectors(4)
    movb $0x02, %ah     # int func 0x2 -> read sector
    int $0x13
    # read ok(CF=0), jump to...
    jnc ok_load_setup
    # fail, reset floppy or harddisk
    movw $0x0000, %dx
    movw $0x0000, %ax
    int $0x13
    jmp load_setup      # read again because fail

ok_load_setup:
    # print some info
    movw $msg, %ax
    movw %ax, %bp
    movw $0x01301, %ax
    movw $0x0c, %bx
    movw $21, %cx
    movb $0, %dl
    int $0x010

    # long jump to [0x9020:0x0] -> actually, go to protect mode
    jmpl $SETUPSEG, $0

msg:
    .ascii "Setup has been loaded"

.org 508
root_dev:
    .word ROOT_DEV
boot_flag:
    .word 0xaa55

