#define __LIBRARY__

#include <linux/tty.h>
#include <linux/kernel.h>

void main(void)
{
    tty_init();

    printk("\r\nhere is ldeng:%d\r\n", 35);

    __asm__ __volatile__(
        "loop:\n\r"
        "jmp loop"
        ::);
}

