#include <stdarg.h>
#include <stddef.h>
#include <linux/kernel.h>

static char buf[1024];

extern int vsprintf(char* buf, const char* fmt, va_list args);

int printk(const char* fmt, ...) {
    va_list args;
    int i;

    va_start(args, fmt);
    i = vsprintf(buf, fmt, args);
    va_end(args);

    __asm__("pushw %%fs\n\t"
            "pushw %%ds\n\t"
            "popw  %%fs\n\t"
            "pushl %0\n\t"
            "pushl $buf\n\t"
            "pushl $0\n\t"
            "call  console_print\n\t"
            "addl  $8, %%esp\n\t"
            "popl  %0\n\t"
            "popw  %%fs"
            ::"r"(i):"ax", "cx", "dx");     /* 根据调用约定，eax, ecx, edx是caller-saved */

    return i;
}

void print_sys(int index) {
#ifndef DEBUG
    return;
#endif

    int i;
#if DEBUG != 2
    int filter[] = {
        1,
        2, /* fork */
        4, 5, 6, 
        7, /* waitpid */
        12, 18, 
        27, /* alarm */
        28,
        29, 
        36, /* sync */
        45, 48, 54, 
        63,
        80,
        84, /* lstat */
    };
#else
    int filter[] = {
        1, 2, 3,
        45,
        48,
        54,
        27,
        36,
        29
    };
#endif

    for (i = 0; i < sizeof(filter) / sizeof(int); i++) {
        if (index == filter[i])
            return;
    }
    printk("sys call %d\n", index);
}


