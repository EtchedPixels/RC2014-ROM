cpm80.rom: system.asm cpm.raw
	zmac system.asm
	dd if=zout/system.cim of=cpm80.rom bs=65536 count=1 conv=sync
	dd if=cpm.raw of=cpm80.rom bs=256 seek=1 conv=notrunc

clean:
	rm -rf *~ zout cpm80.rom

