GCC := gcc
AS := as
OBJCOPY := objcopy
USE_DEBUG :=
CCFLAG := -I../include -nostdinc -ffreestanding -Wall -fomit-frame-pointer -fno-pic -fno-stack-protector -c -m32 $(USE_DEBUG)
LDFLAG := -Ttext 0x0 -s -m elf_i386
INCDIR := ../include


OBJS:=head.o main.o sched.o

system: system.elf
	$(OBJCOPY) -O binary $< $@

system.elf: $(OBJS)
	$(LD) $(LDFLAG) -M -e startup_32 -o $@ $^ > System.map

head.o: head.S
	$(AS) --32 -o $@ $<

main.o: main.c
	$(GCC) $(CCFLAG) -o $@ $<

sched.o: sched.c
	$(GCC) $(CCFLAG) -o $@ $<

clean:
	rm *.o
	rm system
	rm system.elf
	rm System.map

