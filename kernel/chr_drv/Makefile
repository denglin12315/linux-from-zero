AR  := ar
LD  := ld
GCC := gcc
CCFLAG := -m32 -I../../include -nostdinc -ffreestanding -fno-pic -Wall -fomit-frame-pointer -fno-stack-protector -c
OBJS   := tty_io.o console.o

chr_drv.a : $(OBJS)
		$(AR) rcs $@ $^
		sync

tty_io.o : tty_io.c
		$(GCC) $(CCFLAG) -o $@ $<


console.o : console.c
		$(GCC) $(CCFLAG) -o $@ $<

clean : 
		rm -f *.o
		rm -f chr_drv.a

