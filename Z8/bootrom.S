;
;	Z8 bootstrap
;
;	Register usage
;	15	-	last input char or 0
;
;	16-31	-	working register bank
;
;
	.export _diskbuf

	.code

vectors:
	.word	irq0
	.word	irq1
	.word	irq2
	.word	irq3
	.word	irq4
	.word	irq5

	.export _in
	.export _out
	.export _getchar
	.export _putchar

start:
	; Stack Ptr FF00 (FEFF first byte of stack)
	clr	0xFF
	ld	0xFE,#0xFF
	; P01M Stack external, high address bits enable
	ld	0xF8,#0x92

	srp	#0x10

	ld	246,#1		; P2 MISO is an input rest are output
	ld	247,#0x51	; Set up Port P3 including serial and DM
	and	2,#0xBF		; I/O enable. Upper 32K data is now I/O space
	ld	r8,#0xFF	; FF80 - LED
	ld	r9,#0x80
	ld	r10,#0xAA	; LED pattern
	lde	@rr8,r10	; LED set
	ld	r9,#0xFF	; FFFF - MMU (E)
	ld	r10,#2		; Set E space to ROM with high RAM
	dec	r9
	lde	@rr8,r10	; Set C space to ROM with high RAM
	or	2,#0x40		; I/O disable

	; This assumes a 7.3723MHz clock. We can go up to 16MHz in theory
	; but we need a sane clock for the internal uart to work
	; We need to run t0 to generate 16x baud rate
	; bitrate = clock / (2 x 4 x t0prescaler x t0counter x 16)
	; with the 14.7 Mhz clock it all still works but you get 38400
	ld	245,#0x0D	; prescale divide by 3
	ld	244,#1		; 19200 baud (div by 1)
	ld	241,#3		; internal timer, enable t0

	ld	251,#0x08	; Serial RX interrupts only
	ei

	ld	255,#0x00
	ld	254,#0x00

	;	Our memory map depends a bit on the hardware
	;	32K/32K we are low 32K ROM upper RAM
	;	Bank card we are low 56K ROM upper 8K RAM
	;	New banked MMU card we are low 56K ROM upper 8K RAM in both
	;	code and data space settings.
	;	Not supported: 4 x 16K banked
	ld	r8,#>__bss
	ld	r9,#<__bss
	ld	r10,#<__bss_size
	ld	r11,#>__bss_size
	clr	r12
	incw	rr10
	jr	wipe_next

;
;	TODO: keep a copy of data preinit in ROM
;

wipe_bss:
	lde	@rr8,r10
	incw	rr8
wipe_next:
	decw	rr10
	jr	nz, wipe_bss

	call	_main

	;	Should never return

	and	2,#0xBF
	ld	r8,#0xFF
	ld	r9,#0x80
	ld	r10,#0xA5
	lde	@rr8,r10
dead:
	jr	dead

irq0:
irq1:
irq2:
	iret
irq3:
	; RX
	; Should tm p3,1 jr z, framing error
	; but for now we will just assume all is good
	ld	15,240	; Save the last RX byte for the main code to spot
	iret
irq4:
irq5:
	iret


;	Depending on the board either FFxx is I/O or the upper 32K is I/O
;	if we poke port 2. We use FFxx and poke the port as it works with
;	all cases
;
_in:
	ld	r15,#4
	call	__gargr2
	ld	r12,2
	push	r12
	and	2,#0xBF		; I/O on
	ld	r2,#0xFF	; I/O is at FFxx
	lde	r3,@rr2
	pop	2		; restore I/O (might be on in an intr)
	clr	r2
	jp	__cleanup2

_out:
	ld	r15,#4
	call	__gargr4	; get both args into r0-r1/r2-r3
	ld	r12,2
	and	2,#0xBF		; I/O on
	push	r12
	ld	r0,#0xFF
	lde	@rr0,r3
	pop	2
	jp	__cleanup4

_getchar:
	ld	r3,15		; We use this to hold the last pending char
	or	r3,r3
	jr	z, _getchar
	clr	15
	clr	r2
	ret

_putchar:
	tcm	250,#0x10	; busy flag (tx irq pend flag)
	jr	nz,_putchar
	and	250,#0xEF	; clear flag
	ld	r15,#4
	call	__gargr1
	ld	0xF0,r3		; this will tx and set the flag
	jp	__cleanup1

	.data
;
;	So we know this is at E000
;
_diskbuf:
	.ds	512
