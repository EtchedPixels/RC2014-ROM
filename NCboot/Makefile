all:	nc100.rom nc150.rom nc200.rom

nc100.rom: nc100.s
	zmac nc100.s
	dd if=zout/nc100.cim of=nc100.rom bs=131072 conv=sync

nc150.rom: nc100.s
	zmac nc100.s
	dd if=zout/nc100.cim of=nc150.rom bs=262144 conv=sync

nc200.rom: nc200.s
	zmac nc200.s
	dd if=zout/nc200.cim of=nc200.rom bs=524288 conv=sync
