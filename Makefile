SRC_NAME = main

all:
	nasm -f elf32 $(SRC_NAME).asm && ld -m elf_i386 $(SRC_NAME).o

run:
	./a.out
nc:
	nc -nvlp 8443

