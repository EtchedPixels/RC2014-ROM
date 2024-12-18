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
	.export _jump_low

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

	; In case we are using the 4 x 16K MMU
	ld	r9,#0x78
	clr	r0
	lde	@rr8,r0		; ROM bank 0 at 0x0000
	incw	rr8
	inc	r0
	lde	@rr8,r0		; ROM bank 1 at 0x4000
	incw	rr8
	ld	r0,#0x22
	lde	@rr8,r0		; RAM bank 2 at 0x8000
	incw	rr8	
	inc	r0
	lde	@rr8,r0		; RAM bank 3 at 0xC000

	;	and enable
	incw	rr8
	ld	r0,#1
	lde	@rr8,r0		; MMU on

	; At this point either
	;	1. We have no MMU and ROM is in the low 32K
	;	2. We have 56K/8K and ROM is low, RAM in the upper 8K
	;	3. We have 16K x 4 and ROM is low 32K with the RAM pages
	;	   2 and 3 in 8000/C000 (so all RAM is a neat 20/21/22/23)

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

	;	We put our data above 56K so it works for all map types
	ld	r8,#>__bss
	ld	r9,#<__bss
	ld	r10,#<__bss_size
	ld	r11,#>__bss_size
	clr	r12
	incw	rr10
	jr	wipe_next

wipe_bss:
	lde	@rr8,r10
	incw	rr8
wipe_next:
	decw	rr10
	jr	nz, wipe_bss

;	TODO make this work for things other than 512K mapping

	ld	r14,#0xC0
	ld	r15,#0x00
	ld	r12,#0xFF
	ld	r13,#0x7B	; MMU top page
	ld	r1,#0x03	; ROM copy of C0-FF
	ld	r2,#0x23	; RAM copy of C0-FF
	and	2,#0xBF		; I/O on
copy16K:
	ldc	r0,@rr14
	lde	@rr12,r2
	ldc	@rr14,r0
	lde	@rr12,r1
	incw	rr14
	cp	r14,#0
	jr	nz, copy16K

	lde	@rr12,r2	; Switch to the RAM copy
	or	2,#0x10		; I/O off

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

_jump_low:
	; Copy diskbuf into the low 512 bytes of RAM proper
	; and run it. Remember we are in ROM so we need to be careful
	; and play mapping games
	di
	ld	r14,#>strap	; work pointer for helper in rr14
	ld	r15,#<strap
	ld	r13,#0xFF	; MMU in rr12
	ld	r12,#0xFF
	ld	r11,#0xC0	; top 64 bytes for the bootstrap
	ld	r10,#0xFF
copier:
	lde	r0,@rr14
	lde	@rr10,r0
	incw	rr14
	incw	rr10
	cp	r11,#0x00	; Done ?
	jr	nz,copier
	jp	0xFFC0		; run the loaded code
	
;
;	The actual work loop
;
strap:
	and	2,#0xBF		; I/O mode on
	ld	r0,#0x11
	lde	@rr12,r0	; MMU all RAM
	decw	rr12
	lde	@rr12,r0	; On a dual MMU card set C and E MMU the same

	; Do the same magic for the 16K RAM MMU
	ld	r13,#0x78
	ld	r0,#0x20
	lde	@rr12,r0	; 0x0000 is RAM 0
	incw	rr12
	inc	r0
	lde	@rr12,r0	; 0x4000 is RAM 1 (so now RAM0/1/2/3)

	or	2,#0x10		; I/O mode off
	ld	r14,#>_diskbuf
	ld	r15,#<_diskbuf
	clr	r10
	clr	r11
scopy:	
	lde	r0,@rr14
	lde	@rr10,r0
	incw	rr14
	incw	rr10
	cp	r10,#2		; 512 bytes done ?
	jr	nz,scopy
	jp	12		; run the boot block
	
	.data
;
;	So we know this is at E000
;
_diskbuf:
	.ds	512
