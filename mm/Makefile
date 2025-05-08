GCC := gcc
LD  := ld
CCFLAG := -I../include -nostdinc -ffreestanding -Wall -fomit-frame-pointer -fno-pic -fno-stack-protector -std=gnu99 -c -m32
LDFLAG := -Ttext 0x0 -s --oformat binary -m elf_i386
INCDIR := ../include
OBJS   := memory.o


mm.o : $(OBJS)
	$(LD) -m elf_i386 -r -o $@ $^

memory.o : memory.c
	$(GCC) $(CCFLAG) -o $@ $<

clean : 
	rm -f *.o
