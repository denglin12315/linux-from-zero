.code32
.text
.globl system_call

int_msg:
    .asciz  "In kernel interrupt\n\r"

.align 4
system_call:
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
    
    pushl $int_msg
    call printk
    popl %eax
    popw %fs
    popw %es
    popw %ds
    popl %edx
    popl %ecx
    popl %eax

    iret

