all: rom loader rom512

rom: rom.bin
	dd if=rom.bin bs=16384 skip=2 | dd of=rom bs=32768 count=1 conv=sync

rom.bin: rom.o
	ld68 -b rom.o -o rom.bin

rom.o: rom.s
	as68 rom.s -o rom.o

rom512: rom512.bin
	dd if=rom512.bin bs=16384 skip=3 count=1 | dd of=rom512 bs=524288 count=1 conv=sync

rom512.bin: rom512.o
	ld68 -b rom512.o -o rom512.bin

rom512.o: rom512.s
	as68 rom512.s -o rom512.o


loader: loader.bin
	dd if=loader.bin bs=256 skip=2| dd of=loader bs=350 count=1

loader.bin: loader.o
	ld68 -b loader.o -o loader.bin

loader.o: loader.s
	as68 loader.s -o loader.o

clean:
	rm -f rom rom.o rom.bin
	rm -f rom512 rom512.o rom512.bin
	rm -f loader loader.o loader.bin
	rm -f *~

