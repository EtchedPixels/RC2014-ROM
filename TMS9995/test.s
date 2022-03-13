;
;	TMS9995
;
	.code
;
;	Vectors. Not quite the same as most processors because the
;	TMS9995 has no stack as such.
;

reset_wp	.equ	0xF000
l1int_wp	.equ	0xF010
l23int_wp	.equ	0xF020
l4int_wp	.equ	0xF030
nmi_wp		.equ	0xF040

reset:
	.word	reset_wp
	.word	reset_entry
l1int:
	.word	l1int_wp
	.word	l1int_entry
l23int:
	.word	l23int_wp
	.word	l23int_entry
l4int:
	.word	l4int_wp
	.word	l4int_entry

	.ds	48

; XOP vectors live between 0x0040 and 0x007F but we are not using them
; at this point

	.ds	128


;
;	At this point we are running from ROM but have internal RAM
;	at 0xF000 to F0FB and FFFC to FFFF (for the NMI vector)
;
reset_entry:
	li	r0, nmi_wp
	mov	r0, @0xFFFC
	li	r0, nmi_entry
	mov	r0, @0xFFFE

	; Debug lights

	li	r0,0xAA
	movb	r0,@0xFE00

	; Serial

	li	r1,regval
	movb	*r1+,@0xFEC3
	movb	*r1+,@0xFEC0
	clr	@0xFEC1
	movb	*r1+, @0xFEC3
	movb	*r1+, @0xFEC4
	movb	*r1+, @0xFEC2
	movb	*r1+, @0xFEC0

	li	r1,hello
	bl	@prints
wait:
	jmp	wait



prints:
	movb	@0xFEC5,r0		; bit 5 is ready
	andi	r0,0x0020
	jeq	prints
	movb	*r1+,r0
	jeq	print_done
	movb	r0,@0xFEC0
	jmp	prints
print_done:
	b	*r11


l1int_entry:
	li	r0,0x01
err:
	movb	r0,@0xFE00
	jmp 	wait
l23int_entry:
	li	r0,0x02
	jmp	err
l4int_entry:
	li	r0,0x04
	jmp	err
nmi_entry:
	li	r0,0xF0
	jmp	err


regval:
	db	0x80,0x01,0x03,0x02,0x87,'R'
hello:
	.ascii	"Hello World"
	.byte	0
