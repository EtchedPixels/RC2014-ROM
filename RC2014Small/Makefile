rc2014.rom: rom.asm
	zmac rom.asm
	dd if=zout/rom.cim of=rom bs=8192 conv=sync
	dd if=zout/rom.cim of=rom8 bs=8192 conv=sync count=1
	dd if=rom of=rom512 bs=524288 conv=sync
	cat rom8 rom8 rom8 rom8 >rom32

cpm80.rom: system.asm
	zmac system.asm
	dd if=zout/system.cim of=tram bs=256 seek=1

tram: tram.asm
	zmac tram.asm
	dd if=zout/tram.cim of=tram bs=256 count=2

clean:
	rm -rf *~ zout cpm.sys rom rom8 rom32 rom512
