rc2014.rom: rom.asm
	zmac rom.asm
	dd if=zout/rom.cim of=rom bs=8192 conv=sync count=1

cpm80.rom: system.asm
	zmac system.asm
	dd if=zout/system.cim of=cpm.sys bs=256 seek=1

clean:
	rm -rf *~ zout cpm.sys rom

