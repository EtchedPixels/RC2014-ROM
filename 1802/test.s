	.abs
	.org	0

start:
	ldi	#0xFF
	phi	6
	ldi	#0x80
	plo	6
	ldi	#0xFF
	plo	8
loop:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	dec	7
	glo	7
	bnz	loop
	dec	8
	glo	8
	str	6
	br	loop
