all: rom cubix.512

CFLAGS = -O2 -Wall -pedantic
#
#	Simple test ROM
#
rom: rom.s19
	objcopy --input-target=srec --output-target=binary rom.s19 rom

rom.s19: rom.asm
	lwasm -9 --format=srec --output=rom.s19 rom.asm

#
#	CUBIX for 6809 RC2014 512/512K
#
cubixio: cubixio.s19
	objcopy --input-target=srec --output-target=binary cubixio.s19 cubixio

cubixio.s19: cubixio.asm
	lwasm -9 --format=srec --output=cubixio.s19 cubixio.asm --map=cubixio.map

fixcubix: fixcubix.c

patchrom: patchrom.c

cubix.rom: cubixio cubix.base fixcubix patchrom
	./fixcubix <cubix.base >cubix.tmp
	# Patch F9CC onwards in the 8K ROM
	dd bs=6604 seek=1 if=cubixio conv=notrunc of=cubix.tmp
	./patchrom <cubix.tmp >cubix.rom
	
cubix.512:cubix.rom
	cat cubix.rom cubix.rom | dd of=cubix.512 bs=512k count=1 conv=sync

clean:
	rm -f rom *.s19 *~ fixcubix cubix.rom cubixio cubix.tmp cubixio.map patchrom cubix.512
