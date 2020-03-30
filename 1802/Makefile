all: test

test: test.s
	as1802 test.s
	ld1802 -b test.o -o test.bin
	dd if=test.bin of=test bs=32768 conv=sync

clean:
	rm -f *~ test.o test.bin test

