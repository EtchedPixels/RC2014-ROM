rc2014.rom: rom.asm romfix
	zmac rom.asm
	./romfix <zout/rom.cim >rom
	dd if=rom of=rom512 bs=524288 conv=sync

romfix: romfix.c
	gcc -Wall -pedantic -O2 romfix.c -o ./romfix

cpm80.rom: system.asm
	zmac system.asm
	dd if=zout/system.cim of=cpm.sys bs=256 seek=1

clean:
	rm -rf *~ zout cpm.sys rom rom512

