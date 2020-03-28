all: rom

CC = m68k-uclinux-gcc
CFLAGS = -O2 -Wall -pedantic -I. 

rom: rom.o main.o ff.o
	m68k-uclinux-ld -M -T rom.ld rom.o main.o -o rom.elf >rom.map
	m68k-uclinux-objcopy rom.elf -O binary rom.bin
	dd if=rom.bin of=rom bs=512K count=1 conv=sync

rom.o: rom.S
	m68k-uclinux-gcc -c rom.S

ff.o : ff.h ffconf.h

clean:
	rm -f rom.map rom.bin rom rom.elf *.o *~

