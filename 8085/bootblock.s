!
!	A simple bootblock to run at 0x8000
!
.sect .text
.sect .rom
.sect .data
.sect .bss
.sect .text

	.data2 0x8085

start:
	lxi h,helloworld
	call print
	hlt

print:
	in 0xC5
	ani 0x20
	jz print
	mov a,m
	ora a
	rz
	out 0xC0
	inx h
	jmp print

.sect .data

helloworld:
	.asciz 'Hello World'
