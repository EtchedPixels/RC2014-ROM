
	.zeropage

ptr1:	.res	2

	.segment "CODE"

;
;	6502 mini boot rom for 512K ROM/RAM card
;
;	Our address map has the low and high 32K inverted so whilst we
;	program the bank registers the same as other CPU ports we are in
;	fact locating the ROM in the upper 32K
;
;	At the point of entry the first ROM bank is mapped over the full 64K
;	This code must run in the top 16K (as the 6502 sees it)
;

start:
	sei
	cld
	lda #1				; Map the ROM backwards so that we keep 
	sta $C078			; the vectors the same (at FFFx)
	lda #0
	sta $C079
	lda #32				; High 32K as card sees it, low as
	sta $C07A			; 6502 sees it becomes RAM
	lda #33
	sta $C07B
	lda #1
	sta $C07C			; Banking on, map changes here
;
;	Something resembling sanity now exists. We have 32K RAM low, 32K ROM
;	high and the world is good
;
	ldx #0
	txs
;
;	UART: 38400 8N1, RTS on, FIFO on
;
	lda #$80
	sta $C0C3
	lda #$03
	sta $C0C0
	lda #$00
	sta $C0C1
	lda #$03
	sta $C0C3
	lda #$02
	sta $C0C4
	lda #$87
	sta $C0C2
;
;	Display something
;
	lda #'R'
	sta $C0C0
	ldx #>hello
	lda #<hello
	jsr outstring
;
;	Try and boot
;
	lda #$E0		; Drive 0, LBA
	sta $C016
	jsr waitready

	ldx #>loading
	lda #<loading
	jsr outstring
;
;	8bit mode
;
	lda #$01
	sta $C011
	lda #$EF
	sta $C017

	jsr waitready

	lda #0
	sta $C013
	sta $C014
	sta $C015
	lda #1
	sta $C012
	lda #$20
	sta $C017
	jsr waitdrq

	lda #$00
	sta ptr1
	lda #$02
	sta ptr1+1
	ldy #0

bytes1:
	lda $C010
	sta (ptr1),y
	iny
	bne bytes1
	inc ptr1+1
bytes2:
	lda $C010
	sta (ptr1),y
	iny
	bne bytes2
	jsr waitready
	lda $0200
	cmp #$65
	bne badload
	lda $0201
	cmp #$02
	bne badload
	ldx #>booted
	lda #<booted
	jsr outstring
	jmp $0202

badload:
	ldx #>bad
	lda #<bad
outdie:
	jsr outstring
stop:
	jmp stop

waitready:
	lda $C017
	and #$40
	beq waitready
	rts

waitdrq:
	lda $C017
	and #$08
	beq waitdrq
	rts

outstring:
	sta ptr1
	stx ptr1+1
	ldy #0
outstringl:
	lda (ptr1),y
	cmp #0
	beq outdone1
	jsr outchar
	iny
	jmp outstringl
outchar:
	pha
outcharw:
	lda $C0C5
	and #$20
	beq outcharw
	pla
	sta $C0C0
outdone1:
	rts

dobrk:
	ldx #>brkstr
	lda #<brkstr
	jmp outdie

donmi:
	ldx #>nmistr
	lda #<brkstr
	jmp outdie

hello:
	.byte "C2014 6502 512K RAM/ROM",13,10,13,10,0
loading:
	.byte "Loading...",13,10,0
booted:
	.byte "OK",13,10,0
bad:
	.byte "not bootable",13,10,0
nmistr:
	.byte "NMI",0
brkstr:
	.byte "BRK",0

	.segment "VECTORS"

nmivec:
	.word donmi
resetvec:
	.word start
brkvec:
	.word dobrk
