all: rom

CC = m68k-linux-gnu-gcc
LD = m68k-linux-gnu-ld
OBJCOPY = m68k-linux-gnu-objcopy

CFLAGS = -Os -Wall -pedantic -fomit-frame-pointer -I.  -m68000

rom: rom.o main.o ff.o platform-p90mb.o libgcc.o
	$(LD) -M -T rom.ld -q rom.o main.o ff.o platform-p90mb.o libgcc.o -o rom.elf >rom.map
	$(OBJCOPY) rom.elf -O binary rom.bin
	dd if=rom.bin of=rom bs=512K count=1 conv=sync

rom.o: rom.S
	$(CC) -m68000 -c rom.S

libgcc.o: libgcc.S
	$(CC) -m68000 -c libgcc.S

ff.o : ff.h ffconf.h diskio.h

clean:
	rm -f rom.map rom.bin rom rom.elf *.o *~
	rm -f rom-mmu.map rom-mmu.bin rom-mmu rom-mmu.elf *.o *~
	rm -f *.o *~

main.o : setjmp.h system.h ff.h ffconf.h diskio.h
platform-p90mb.o : system.h ff.h ffconf.h diskio.h
