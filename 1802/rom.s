	.abs
	.org	0

	.export uarttab
	.export call
	.export return

start:
	dis
	.byte	0		; X = P = 0, IRQ off

	ldi	#0xFF
	phi	6
	ldi	#0x80
	plo	6
	str	6		; Lights

	;
	;	R3 will become our program counter
	;
	ldi	#<setup
	plo	3
	ldi	#>setup
	phi	3
	sep	3
setup:
	;
	;	SCRT set up table
	;
	ldi	#<inittab
	plo	7
	ldi	#>inittab
	phi	7
	;
	;	Set up our registers for SCRT
	;	0 free (DMA pointer)
	;	1 interrupts (fixed by CPU)
	;	2 stack
	;	3 pc
	;	4 scrt call
	;	5 scrt return
	;	6 last return address (thus inline arguments)
	;
	lda	7		; IRQ
	phi	1
	lda	7
	plo	1
	lda	7		; SP
	phi	2
	lda	7
	plo	2
	lda	7		; SCRT Call
	phi	4
	lda	7
	plo	4
	lda	7		; SCRT Ret
	phi	5
	lda	7
	plo	5

	sex	2

	ldi	#0xFF
	phi	6
	ldi	#0x80
	plo	6
	ldi	#0xC0
	str	6		; Lights

	; call iosetup(uarttab)
	sep	4
	.word	iosetup
	.word	uarttab	
loop:
	sep	4
	.word	print
	.ascii	"Hello World"
	.byte	0

	br loop


;
;	Read byte pairs from a table until a \0 terminator and use those
;	as the low byte to configure an I/O. Uses 7 and 8.
;
iosetup:
	lda	6
	phi	8
	lda	6
	plo	8
	sex	8
	ldi	#0xFF
	phi	7
setup_next:
	ldxa
	bz	do_return
	plo	7
	ldxa
	str	7
	br	setup_next
do_return:
	sep	5

;
;	Print a string of text uses 7, 8
;
print:
	ldi	#0xFF
	phi	7
	ldi	#<hex20
	plo	8
	ldi	#>hex20
	phi	8
	ldi	#0xFF
	phi	14
	ldi	#0x80
	plo	14
waitch:
	ldi	#0xC5
	plo	7
	ldn	7
	str	14
	sex	8
	and
	sex	6
	bz waitch
	ldi	#0xC0
	plo	7
	ldxa
	bz	do_return
	str	7
	br	waitch

;
;	SCRT with interrupt support
;
callagain:
	sep	3		; Back to the old code
call:				; as we are really a co-routine...
	sex	4		; X = PC
	dis			; disable interrupts
	.byte	0x24
	phi	15		; Save D
	ghi	6		; Stack 6
	stxd
	glo	6
	stxd
	ghi	3		; get the caller PC (new return)
	phi	6		; and stuff it into 6
	glo	3
	plo	6
	lda	6		; caller followed call with new pc
	phi	3		; so get that into R3
	lda	6
	plo	3
	ghi	15		; recover D
	sex	4		; X = PC
	ret			; interrupts back on
	.byte	0x24
	br	callagain	; round the co-routine

returnagain:
	sep	3		; back to old code
return:				; as we are really a co-routine...
	sex	5		; X = PC
	dis			; disable interrupts
	.byte	0x25
	phi	15		; save D
	ghi	6		; copy 6 into 3
	phi	3
	glo	6
	plo	3
	sex	2		; X = stack
	inc	2		; bump 2 bytes up
	ldxa			; get old 'last caller'
	plo	6		; back off stack
	ldx
	phi	6
	ghi	15		; recover D
	sex	5		; enable interrupts
	ret
	.byte	0x25
	br	returnagain	; round the co-routine
	
inittab:
	.word	0		; No IRQ handler yet
	.word	0xFEFF		; Stack at memory top
	.word	call
	.word	return
hex20:
	.byte	0x20		; For and on uart
uarttab:
	.byte	0xC3
	.byte	0x80
	.byte	0xC0
	.byte	0x03		; 38400
	.byte	0xC1
	.byte	0x00
	.byte	0xC3
	.byte	0x03		; 8N1
	.byte	0xC4
	.byte	0x02		; RTS
	.byte	0xC2
	.byte	0x87		; FIFO on, reset FIFO
	.byte	0x00
