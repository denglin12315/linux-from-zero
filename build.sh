as -o 1_1_bootsect.o 1_1_bootsect.S 
ld -m elf_x86_64 -Ttext 0x0 -s --oformat binary -o linux.img 1_1_bootsect.o

qemu-system-x86_64 -boot a -fda linux.img
