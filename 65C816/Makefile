all: bootrom

permute_rom: permute_rom.c
	cc -Wall -pedantic permute_rom.c -o permute_rom

bootrom: bootrom.tmp permute_rom
	dd if=bootrom.tmp bs=16384 skip=3 | dd bs=524288 count=1 conv=sync | ./permute_rom > bootrom

bootrom.tmp: bootrom.o bootrom.cfg
	ld65 -C bootrom.cfg bootrom.o -o bootrom.tmp -m bootrom.map

bootrom.o: bootrom.s
	ca65 bootrom.s

clean:
	rm -f *.o *~
	rm -f permute_rom
	rm -f bootrom.map bootrom.tmp bootrom
