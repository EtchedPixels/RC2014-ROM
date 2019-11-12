
	.export nmivec
	.export resetvec
	.export brkvec
	.export start

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
;
;	LED pattern
;
	lda #$AA
	sta $FE80
;
;	UART: 38400 8N1, RTS on, FIFO on
;
	lda #$80
	sta $FEC3
	lda #$03
	sta $FEC0
	lda #$00
	sta $FEC1
	lda #$03
	sta $FEC3
	lda #$02
	sta $FEC4
	lda #$87
	sta $FEC2

;
;	This might just be my board or something but a short nap at start up
;	helps ?
;
	ldx #0
	ldy #$FE
sleep:
	dex
 	bne sleep
	dey
	bne sleep


;	Display something
;

	lda #'R'
	sta $FEC0

	lda #$81
	sta $FE80
;
; Now set up the memory mappings
;
	lda #32				; Low 32K becomes 6502 RAM
	sta $FE78			; Needs to be this way up for a 6502
	lda #33
	sta $FE79
	lda #1				; Map the ROM backwards so that we keep 
	sta $FE7A			; the vectors the same (at FFFx)
	lda #0
	sta $FE7B

	lda #$88
	sta $FE80

	ldx #0
	ldy #$FE
sleep3:
	dex
	bne sleep3
	dey
	bne sleep3

	lda #1
	sta $FE7C			; Banking on, map changes here

	lda #$8C
	sta $FE80

	ldx #0
	ldy #$FE
sleep4:
	dex
	bne sleep4
	dey
	bne sleep4

;
;	Something resembling sanity now exists. We have 32K RAM low, 32K ROM
;	high and the world is good
;

	lda #$CF
	sta $FE80


	ldx #0
	txs
	ldx #>hello
	lda #<hello
	jsr outstring
	
	lda #$FF
	sta $FE80

;
;	Wait a while so the CF adapter has time to initialize itself
;	and start talking sense
;
	lda #10
	tax ; the 1%
	ldy #$FE
sleep2:
	dex
	bne sleep2
	dey
	bne sleep2
	sta $FE80
	clc
	sbc #0
	bne sleep2

;
;	Try and boot. We must wait for the adapter before we can do
;	anything.
;
	jsr waitready
;
;
;
	lda #$E0		; Drive 0, LBA
	sta $FE16
	jsr waitready

	jsr dumpreg

	ldx #>loading
	lda #<loading
	jsr outstring
;
;	8bit mode
;
	lda #$01
	sta $FE11
	lda #$EF
	sta $FE17

	jsr waitready
	jsr dumpreg

	lda #0
	sta $FE13
	sta $FE14
	sta $FE15
	lda #1
	sta $FE12
	lda #$20
	sta $FE17
	jsr waitdrq

	jsr dumpreg
	lda #$00
	sta ptr1
	lda #$02
	sta ptr1+1
	ldy #0

bytes1:
	lda $FE10
	sta (ptr1),y
	jsr outcharhex
	iny
	bne bytes1
	inc ptr1+1
bytes2:
	lda $FE10
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
	lda $0200
	jsr outcharhex
	lda $0201
	jsr outcharhex
	ldx #>bad
	lda #<bad
outdie:
	jsr outstring
stop:
	jmp stop

waitready:
	lda #$F0
	sta $FE80
waitloop:
	lda $FE17
	and #$40
	beq waitloop
	lda #$0F
	sta $FE80
	rts

waitdrq:
	lda $FE17
	and #$09
	beq waitdrq
	and #$01
	beq wait_drq_done
	lda $FE11
	jsr outcharhex
	jmp badload

wait_drq_done:
	rts

dumpreg:
	lda #'['
	jsr outchar
	lda $FE11
	jsr outcharhex
	lda $FE12
	jsr outcharhexspc
	lda $FE13
	jsr outcharhexspc
	lda $FE14
	jsr outcharhexspc
	lda $FE15
	jsr outcharhexspc
	lda $FE16
	jsr outcharhexspc
	lda $FE17
	jsr outcharhexspc
	lda #']'
	jsr outchar
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

outcharhexspc:
	pha
	lda #' '
	jsr outchar
	pla
outcharhex:
	tax
	ror
	ror
	ror
	ror
	jsr outcharhex1
	txa
outcharhex1:
	and #$0F
	clc
	adc #'0'
	cmp #'9'+1
	bcc outchar
	adc #6	; Carry set so actually add 7
outchar:
	pha
outcharw:
	lda $FEC5
	and #$20
	beq outcharw
	pla
	sta $FEC0
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
	.byte "C2014 6502 512K RAM/ROM 0.09",13,10,13,10,0
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
