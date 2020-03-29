all: rom

CC = m68k-linux-gnu-gcc
LD = m68k-linux-gnu-ld
OBJCOPY = m68k-linux-gnu-objcopy

CFLAGS = -O2 -Wall -pedantic -fomit-frame-pointer -I.  -m68000 -fno-inline-small-functions

rom: rom.o main.o ff.o platform-rc2014.o libgcc.o
	$(LD) -M -T rom.ld rom.o main.o ff.o platform-rc2014.o libgcc.o -o rom.elf >rom.map
	$(OBJCOPY) rom.elf -O binary rom.bin
	dd if=rom.bin of=rom bs=512K count=1 conv=sync

rom.o: rom.S
	$(CC) -m68000 -c rom.S

libgcc.o: libgcc.S
	$(CC) -m68000 -c libgcc.S

ff.o : ff.h ffconf.h diskio.h

clean:
	rm -f rom.map rom.bin rom rom.elf *.o *~

main.o : setjmp.h system.h ff.h ffconf.h diskio.h
platform-rc2014.o : system.h ff.h ffconf.h diskio.h
