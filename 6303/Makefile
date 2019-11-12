all: rom loader

rom: rom.obj
	dd if=rom.obj bs=16384 skip=3 | dd of=rom bs=524288 count=1 conv=sync

rom.obj: rom.s
	as1 rom.s -b

loader: loader.obj
	dd if=loader.obj bs=256 skip=2| dd of=loader bs=350 count=1

loader.obj: loader.s
	as1 loader.s -b

clean:
	rm -f rom rom.obj rom.lst *~
	rm -f loader loader.obj loader.lst
