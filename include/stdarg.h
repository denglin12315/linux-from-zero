#ifndef _STDARG_H
#define _STDARG_H

typedef char *va_list;

/* 确保任何类型的参数都占用4字节栈空间 */
#define __va_rounded_size(TYPE)  \
      (((sizeof (TYPE) + sizeof (int) - 1) / sizeof (int)) * sizeof (int))

/* 计算传入printk的倒数第二个参数(实际上就是fmt上面那个参数,看栈视图) */
#ifndef __sparc__
#define va_start(AP, LASTARG)                       \
     (AP = ((char *) &(LASTARG) + __va_rounded_size (LASTARG)))
#else
#define va_start(AP, LASTARG)                       \
     (__builtin_saveregs (),                        \
        AP = ((char *) &(LASTARG) + __va_rounded_size (LASTARG)))
#endif

#define va_end(AP)      /* 空操作，x86上va_end啥也不做 */

/* 返回AP地址对应的args的值 */
#define va_arg(AP, TYPE)                        \
     (AP += __va_rounded_size (TYPE),                   \
        *((TYPE *) (AP - __va_rounded_size (TYPE))))

#endif /* _STDARG_H */


