;
;	TMS9995
;
	.code

	.export hexdigit
;
;	Vectors. Not quite the same as most processors because the
;	TMS9995 has no stack as such.
;

reset_wp	.equ	0xF000
l1int_wp	.equ	0xF020
l23int_wp	.equ	0xF040
l4int_wp	.equ	0xF060
nmi_wp		.equ	0xF080

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

	li	r1, io_setup
	;	Length in bytes of set up block
	li	r4, io_end - io_setup

	bl	@io_op

	li	r1,hello
	bl	@prints

	; RAM check
	;
	; Set a word to 0, check it reads 0, increment it check it no longer
	; reads 0

	li	r0,0x8000
	clr	*r0
 	mov	*r0,r1
	jne	@not_ram
	inc	*r0
	mov	*r0,r1
	jeq	@not_ram

	;
	; RAM present to begin with - linear 32K/32K
	;
	li	r1,ram32
	bl	@prints
	jmp	@ram_done

	;
	; We may have a 512K/512K card
	;
not_ram:
	li	r1, mmu_setup
	li	r4, mmu_end - mmu_setup
	bl	@io_op

	li	r0,0x8000
	clr	*r0
	mov	*r0,r1
	jne	@fault_ram
	inc	*r0
	mov	*r0,r1
	jeq	@fault_ram

	li	r1,ram512
	bl	@prints

	jmp	@ram_done

fault_ram:
	li	r1, rambad
	bl	@prints
wait:
	jmp	@wait

;
;	We now have ROM low, RAM high regardless of memory card
;
ram_done:

monitor:
	mov	@addr,r0
	bl	@phex4
	li	r1,prompt
	bl	@prints
	bl	@input
	li	r2,buffer
	movb	*r2+,r0
	jeq	@readmem_next
	bl	@spaces
	ci	r0,'A' * 256
	jeq	@setaddr
	ci	r0, 'B' * 256
	ljeq	@bootstrap
	ci	r0,'G' * 256
	jeq	@goto
	ci	r0,'R' * 256
	jeq	@readmem
error:
	li	r1,syntax
	bl	@prints
	jmp	@monitor

setaddr:
	bl	@hex4
	jne	@error
	mov	r0,@addr
	jmp	@monitor

goto:
	bl	@hex4
	jne	@error
	b	r0

readmem:
	bl	@hex4
	jne	@error
	mov	r0,@addr
readmem_next:
	mov	@addr,r0
	bl	@phex4
	mov	@addr,r4
	li	r5,16
rmlp:
	li	r0,' ' * 256
	bl	@putchar	
	movb	*r4+,r0
	bl	@phex2
	dec	r5
	jne	@rmlp
	mov	r4,@addr
	li	r1,newline
	bl	@prints
	jmp	@monitor

spaces:	movb	*r2+,r1
	srl	r1,8
	ci	r1,' '
	jeq	@spaces
	dec	r2
	rt

io_op:
	clr	r2
io_loop:
	; The TMS99xx is weird, a byte read ends up in the top half of
	; the register. We want it in the low half so we form an address
	movb	*r1+,r2
	swpb	r2
	movb	*r1+,r3
	; r2 is now the I/O address to use
	movb	r3,@0xFE00(r2)
	swpb	r2			; keep the other half clear
	dect	r4
	jne	@io_loop
	rt


input:
	mov	r11,r10			; save link register
	li	r4, buffer
	li	r5, 63
inputlp:
	bl	@read
	ci	r0,13 * 256
	jeq	@input_nl
	ci	r0,8 * 256 
	jeq	@input_bs
	ci	r0,127 * 256
	jeq	@input_bs
	jgt	@inputlp
	ci	r0,32 * 256
	jlt	@inputlp
	ci	r5,0
	jeq	@inputlp
	movb	r0,*r4+
	bl	@putchar
	dec	r5
	jmp	@inputlp
input_nl:
	clr	r0
	movb	r0,*r4
	li	r1, newline
	bl	@prints
	mov	r10,r11
	rt
input_bs:
	ci	r5,63
	jeq	@inputlp
	li	r1, bsout
	bl	@prints
	inc	r5
	jmp	@inputlp


hexdigit:
	srl	r0,8
	ai	r0, -'0'
	ci	r0, 9
	jle	@hexgood
	ci	r0, 7
	jlt	@badhex
	ai	r0, -7
	ci	r0, 15
	jle	@hexgood
badhex:
	li	r1,1
	rt
hexgood:
	li	r1,0		; clr doesnt affect flags
	rt

hex2:
	mov	r11,r10
	movb	*r2+,r0
	bl	@hexdigit
	jne	@badhexr
	mov	r0,r3
	sla	r3,4
	movb	*r2+,r0
	bl	@hexdigit
	jne	@badhexr
	a	r3,r0
	mov	r10,r11
	li	r1,0
	rt
badhexr:
	li	r1,1
	mov	r10,r11
	rt

hex4:
	mov	r11,r10
	movb	*r2+,r0
	bl	@hexdigit
	jne	@badhexr
	mov	r0,r3
	sla	r3,4
	movb	*r2+,r0
	bl	@hexdigit
	jne	@badhexr
	a	r0,r3
	swpb	r3		; fastest shift by 8
	movb	*r2+,r0
	bl	@hexdigit
	jne	@badhexr
	sla	r0,4
	a	r0,r3
	movb	*r2+,r0
	bl	@hexdigit
	jne	@badhexr
	a	r3,r0
	mov	r10,r11
	li	r1,0
	rt

phex4:
	mov	r11,r9
	mov	r0,r4
	bl	@phex2
	mov	r4,r0
	swpb	r0
	bl	@phex2
	mov	r9,r11
	rt

;
;	Print in hex the value in the byte (upper) half of R0
;
phex2:
	; R0 upper byte is the bits we need - swap then and shift them
	; to index the array
	mov	r11,r10
	srl	r0,8			; clear upper, byte to lower
	mov	r0,r3			; save
	mov 	r0,r2			; can't index using r0
	srl	r2,4			; 4bits we want
	movb	@hextab(r2),r0		; look them up
	bl	@putchar		; print it
	mov	r3,r0			; recover byte
	andi	r3,15			; low 4 bits only
	movb	@hextab(r3),r0		; look it up
	bl	@putchar		; print it
	mov	r10,r11
	rt

bootstrap:
	li	r0,0x01EF		; 1 and set features
	movb	r0,@0xFE11
	swpb	r0
	movb	r0,@0xFE17
	bl	@waitready
	li	r0,0xAA55
	movb	r0,@0xFE13
	cb	r0,@0xFE13
	jne	@no_media
	swpb	r0
	movb	r0,@0xFE13
	cb	r0,@0xFE13
	jne	@no_media
	li	r0,0x0100
	movb	r0,@0xFE13
	clr	@0xFE14
	li	r0,0x0120		; 1 sector and read
	movb	r0,@0xFE12
	swpb	r0
	movb	r0,@0xFE17
	bl	@waitdrq
	li	r0,0xFC00
	li	r1, 256
bootin:
	movb	@0xFE10,r2
	swpb	r2
	movb	@0xFE10,r2
	swpb	r2
	mov	r2,*r0+
	dec	r1
	jne	@bootin
	mov	@0xFC00,r0
	ci	r0,0x9599
	jne	@badboot
	b	@0xFC02
badboot:
	li	r1,wrongboot
	bl	@prints
	b	@monitor
no_media:
	li	r1,nomedia
	bl	@prints
	b	@monitor

waitready:
	movb	@0xFE17,r0
	andi	r0,0x4000
	jeq	@waitready
	rt

waitdrq:
	movb	@0xFE17,r0
	andi	r0,0x0900
	jeq	@waitdrq
	mov	r0,r1
	andi	r1,0x0100
	jne	@diskerr
	rt
diskerr:
	bl	@phex2
	li	r1,diskerror
	bl	@prints
	b	@monitor

;
;	16x50 UART drivers (used for now)
;

putchar:
	movb	@0xFEC5,r1		; bit 5 is ready
	andi	r1,0x2000
	jeq	@putchar
	movb	r0,@0xFEC0
	rt

prints:
	movb	@0xFEC5,r0		; bit 5 is ready
	andi	r0,0x2000
	jeq	@prints
	movb	*r1+,r0
	jeq	@print_done
	movb	r0,@0xFEC0
	jmp	@prints
print_done:
	rt

read:
	movb	@0xFEC5,r0
	andi	r0,0x0100
	jeq	@read
	clr	r0
	movb	@0xFEC0,r0
	rt
;
;	TMS9902 UART driver for future use
;
init_9902:
	li	r12,0
	sbo	31
	ldcr	@cntrl9902,8
	ldcr	@intvl9902,8
	ldcr	@dr9902,11
	ldcr	@dr9902,12
	sbo	16
	rt

cntrl9902:
	 .byte	0x83		; 8N1
	.even
intvl9902:
	.word	0xFFFF		; Unused
dr9902:
	.word	0x001A		; 19200 I think


prints_9902:
	; Assumes R12 is set up and SB0 16 was done at init
	tb	22
	jne	@prints_9902
	movb	*r1,r0
	jeq	@print_done
	ldcr	*r1+,8
	jmp	@prints_9902

read_9902:
	tb	21
	jne	@read_9902
	stcr	r0,8
	sbz	18
	rt
	
l1int_entry:
	li	r0,0x01
err:
	movb	r0,@0xFE00
	b 	@wait
l23int_entry:
	li	r0,0x02
	jmp	@err
l4int_entry:
	li	r0,0x04
	jmp	@err
nmi_entry:
	li	r0,0xF0
	jmp	@err

io_setup:
	; Debug
	.byte	0x80, 0xAA
	; UART
	.byte	0xC3, 0x80		; Switch to set clock 
	.byte	0xC0, 0x01		;
	.byte	0xC1, 0x00		; 115200
	.byte	0xC3, 0x03		; Switch back, set up mode
	.byte	0xC4, 0x02
	.byte	0xC2, 0x87
	.byte	0xC0, 'R'		; and init char visible
io_end:

mmu_setup:
	.byte	0x80, 0x01		; Debug
	.byte	0x78, 0x00		; ROM 0 low
	.byte	0x79, 0x01		; ROM 1
	.byte	0x7A, 0x22		; RAM 2
	.byte	0x7B, 0x23		; RAM 3
	.byte	0x7C, 0x01		; Enable
	.byte	0x80, 0x03
mmu_end:

hello:
	.ascii	"C2014 Boot ROM for TMS9995 v0.02"
	.byte	13,10
	.byte	13,10
	.ascii	'RAM check: '
	.byte	0
ram32:
	.ascii	'32K RAM / 32K ROM'
	.byte	13,10,0
ram512:
	.ascii	'512K RAM / 512K ROM'
newline:
	.byte	13,10,0
rambad:
	.ascii	'Failed'
	.byte	13,10,0
bsout:
	.byte	8,32,8,0
prompt:
	.ascii	'* '
	.byte	0
syntax:
	.ascii	'?'
	.byte	13,10,0
wrongboot:
	.ascii	'Not bootable'
	.byte	13,10,0
nomedia:
	.ascii	'No media'
	.byte	13,10,0
diskerror:
	.ascii	' - disk error'
	.byte	13,10,0

	.even
hextab:
	.ascii	"0123456789ABCDEF"
	.even

	.bss

buffer:
	.ds	64
addr:
	.word	0
