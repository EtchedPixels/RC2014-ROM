	.abs
	.org	0

start:
	ldi	#0xFE
	phi	6
	ldi	#0x80
	plo	6
	ldi	#0xAA
	str	6
loop:	br	loop
