all: rom loader

rom: rom.bin
	dd if=rom.bin of=rom bs=524288 count=1 conv=sync

rom.bin: rom.o
	ld8070 -b rom.o -o rom.bin

rom.o: rom.s
	as8070 rom.s -o rom.o

loader: loader.bin
	dd if=loader.bin bs=256 skip=2 | dd of=loader bs=350 count=1

loader.bin: loader.o
	ld8070 -b loader.o -o loader.bin

loader.o: loader.s
	as8070 loader.s -o loader.o

clean:
	rm -f rom rom.o rom.bin
	rm -f loader loader.o loader.bin
	rm -f *~

