//#include <linux/sched.h>
#include <linux/head.h>
#include <asm/system.h>

extern int system_call();

#define PAGE_SIZE 4096

long user_stack[PAGE_SIZE  >> 2];

struct {
    long *a;
    short b;
} stack_start = {
    &user_stack[PAGE_SIZE >> 2],
    0x10,
};


void sched_init()
{
    set_intr_gate(0x80, &system_call);
}
