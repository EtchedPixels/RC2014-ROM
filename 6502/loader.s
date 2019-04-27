;
;	We are loaded at $0200.
;	0000-7FFF are RAM 8000-FFFF ROM (except I/O)
;
;	We load an image from 0400-FF00 skipping C000-C0FF
;	and then jump to C102 if the marker is right
;

	.zeropage
ptr1:	.res	2
sector:	.res	1

	.segment "CODE"

	.byte $65
	.byte $02
start:
	; Map the full 64K to RAM
	lda #34
	sta $C078
	lda #35
	sta $C079

	lda #$00
	sta ptr1
	lda #$04
	sta ptr1+1

	lda #$01	; 0 is the partition/boot block
	sta sector

dread:
	jsr waitready
	lda #'.'
	sta $C0C0
	lda sector
	cmp #$7D	; loaded all of the image ?
	beq load_done
	inc sector
	sta $C013
	lda #$01
	sta $C012	; num sectors (drives may clear this each I/O)
	lda #$20
	sta $C017	; read command

	jsr waitdrq

	lda ptr1+1	; skip the I/O page
	cmp #$C0
	bne not_io
	inc ptr1+1	; we load to BFFF..C100.... etc up to FF00
not_io:
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
	inc ptr1+1
	jmp dread

load_done:
	lda $C100
	cmp #$02
	bne bad_load
	lda $C101
	cmp #$65
	bne bad_load

	ldx #>running
	lda #<running
	jsr outstring
	jmp $C102

bad_load:
	ldx #>badimg
	lda #<badimg
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


badimg:
	.byte 13,10,"Image not bootable."
running:
	.byte 13,10,0
