all: test rom rom512

test: test.s
	as9995 test.s -l test.lst
	ld9995 -b test.o -o test.bin
	dd if=test.bin of=test bs=32768 conv=sync

rom.bin: rom.s
	as9995 rom.s
	ld9995 -b -C 0 -B 32768 rom.o -o rom.bin -m rom.map

rom: rom.bin
	dd if=rom.bin of=rom bs=32768 conv=sync

rom512: rom.bin
	dd if=rom.bin of=rom512 bs=524288 conv=sync

clean:
	rm -f *~ test.o test.bin test rom rom512 rom.o rom.bin
	rm -f rom.map test.map
