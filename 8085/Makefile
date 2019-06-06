all: ack2rom rc2014-8085.rom bootblock loader

ack2rom: ack2rom.c

rc2014-8085.rom: ack2rom rom.s
	ack -mcpm -c rom.s
	/opt/ackcc/lib/ack/em_led -b0:0x0000 rom.o -o rom.bin
	./ack2rom <rom.bin | dd bs=524288 conv=sync of=rc2014-8085.rom

bootblock: ack2rom bootblock.s
	ack -mcpm -c bootblock.s
	/opt/ackcc/lib/ack/em_led -b0:0xFE00 bootblock.o -o bootblock.bin
	./ack2rom <bootblock.bin >bootblock

loader: ack2rom loader.s
	ack -mcpm -c loader.s
	/opt/ackcc/lib/ack/em_led -b0:0xFE00 loader.o -o loader.bin
	./ack2rom <loader.bin >loader

clean:
	rm -f ack2rom *.o *.bin rc2014-8085.rom loader bootblock *~
