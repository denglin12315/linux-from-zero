GCC := gcc
AS := as
OBJCOPY := objcopy
USE_DEBUG :=
CCFLAG := -I../include -nostdinc -ffreestanding -Wall -fomit-frame-pointer -fno-pic -fno-stack-protector -c -m32 $(USE_DEBUG)
LDFLAG := -Ttext 0x0 -s --oformat binary -m elf_i386
INCDIR := ../include


OBJS:=head.o sys_call.o main.o sched.o printk.o vsprintf.o chr_drv/chr_drv.a ../mm/mm.o ../lib/lib.a

system: $(OBJS)
	$(LD) $(LDFLAG) -M -e startup_32 -o $@ $^ > System.map

head.o: head.S
	$(GCC) -m32 -traditional -c -o $@ $<

sys_call.o : sys_call.S
	$(GCC) $(USE_DEBUG) -m32 -traditional -c -o $@ $<

main.o: main.c
	$(GCC) $(CCFLAG) -o $@ $<

sched.o: sched.c
	$(GCC) $(CCFLAG) -o $@ $<

printk.o : printk.c
	$(GCC) $(CCFLAG) -o $@ $<

vsprintf.o : vsprintf.c
	$(GCC) $(CCFLAG) -o $@ $<

chr_drv/chr_drv.a: chr_drv/*.c
	cd chr_drv; make chr_drv.a; cd ..

../mm/mm.o : ../mm/*.c
	cd ../mm; make mm.o; cd ../kernel

../lib/lib.a : ../lib/*.c
	cd ../lib; make lib.a; cd ../kernel

clean:
	rm -f *.o
	rm -f system
	rm -f System.map
	cd chr_drv; make clean; cd ..
	cd ../lib; make clean; cd ../kernel

