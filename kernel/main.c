#define __LIBRARY__

#include <linux/tty.h>

void main(void)
{
    tty_init();

    __asm__ __volatile__(
        "loop:\n\r"
        "jmp loop"
        ::);
}

