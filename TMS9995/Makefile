all: test rom

test: test.s
	as9995 test.s -l test.lst
	ld9995 -b test.o -o test.bin
	dd if=test.bin of=test bs=32768 conv=sync

rom: rom.s
	as9995 rom.s
	ld9995 -b rom.o -o rom.bin -m rom.map
	dd if=rom.bin of=rom bs=32768 conv=sync

clean:
	rm -f *~ test.o test.bin test rom rom.o rom.bin
