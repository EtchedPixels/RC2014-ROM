
all: test bootrom

test: test.s
	asz8 test.s
	ldz8 -b test.o -o test.bin -m test.map
	dd if=test.bin of=test bs=32768 conv=sync

bootrom: bootrom.o bootstrap.o
	ldz8 -b -C 0x0000 -D 0xE000 -o bootrom.bin -m bootrom.map \
		bootrom.o bootstrap.o /opt/fcc/lib/z8/libz8.a
	dd if=bootrom.bin of=bootrom bs=524288 count=1 conv=sync

bootrom.o: bootrom.S
	fcc -c -mz8 bootrom.S

bootstrap.o: bootstrap.c
	fcc -c  -X -mz8 bootstrap.c

clean:
	rm -f *~ *.o *.bin
	rm -f test bootrom

