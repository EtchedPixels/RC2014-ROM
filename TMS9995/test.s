		.code

	.word	0xF000
	.word	go
go:
	li	r0,0xAA00
	movb	r0,@0xFE80
	jmp	go
