all: rom loader

rom: rom.tmp
	dd if=rom.tmp of=rom bs=16384 skip=3

rom.tmp: rom.o rom.cfg
	ld65 -C rom.cfg rom.o -o rom.tmp

rom.o: rom.s
	ca65 rom.s

loader: loader.tmp
	dd if=loader.tmp of=loader bs=256 skip=2 count=1

loader.tmp: loader.o loader.cfg
	ld65 -C loader.cfg loader.o -o loader.tmp

loader.o: loader.s
	ca65 loader.s

clean:
	rm -f rom rom.o rom.tmp *~
	rm -f loader loader.o loader.tmp

