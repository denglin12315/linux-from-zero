#ifndef _KERNEL_H
#define _KERNEL_H

//void verify_area(void * addr,int count);
//void panic(const char * str);
//volatile void do_exit(long error_code);
int printk(const char* fmt, ...);

//#define suser() (current->euid == 0)

#endif
