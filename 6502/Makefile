all: rom loader

rom: rom.tmp
	dd if=rom.tmp bs=16384 skip=3 | dd of=rom bs=524288 count=1 conv=sync

rom.tmp: rom.o rom.cfg
	ld65 -C rom.cfg rom.o -o rom.tmp -m rom.map

rom.o: rom.s
	ca65 rom.s

loader: loader.tmp
	dd if=loader.tmp bs=256 skip=2| dd of=loader bs=350 count=1

loader.tmp: loader.o loader.cfg
	ld65 -C loader.cfg loader.o -o loader.tmp

loader.o: loader.s
	ca65 loader.s

clean:
	rm -f rom rom.o rom.tmp rom.map *~
	rm -f loader loader.o loader.tmp

