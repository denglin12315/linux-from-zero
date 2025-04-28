<<<<<<< HEAD
as -o bootsect.o bootsect.S 
ld -m elf_x86_64 -Ttext 0x0 -s --oformat binary -o linux.img bootsect.o
=======
as -o 1_1_bootsect.o 1_1_bootsect.S 
ld -m elf_x86_64 -Ttext 0x0 -s --oformat binary -o linux.img 1_1_bootsect.o
>>>>>>> 3f67baa (linux kernel from 0)

qemu-system-x86_64 -boot a -fda linux.img
