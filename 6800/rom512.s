;
;	6800 / 6808 boot ROM
;
;	512K RAM/ROM card with 16x50A UART
;
	.abs

	.org $C000

start:
	sei
	ldx #$FE00			; I/O window
;
;	LED pattern
;
	ldaa #$AA
	staa $80,x

	ldaa #$80	; DLAB on
	staa $C3,x
	ldaa #$01	; 115200
	staa $C0,x
	deca
	staa $C1,x
	ldaa #$03	; DLAB off 8N1
	staa $C3,x	
	deca
	staa $C4,x	; RTS (2)
	ldaa #$87
	staa $C2,x	; FIFO on and reset
	ldaa #'R'
	staa $C0,x	; say something

;
;	Set up the memory map
;
boot:
	clra
	staa $7B,x	; Keep top 16K as our ROM image
	ldaa #$20
	staa $78,x	; Low 48K of RAM into the low 48K
	inca
	staa $79,x
	inca
	staa $7A,x
	ldaa #1
	staa $7C,x	; MMU on

	ldaa #$CF
	staa $80,x

	ldx #$7FFF
	txs
	ldx #hello
	jsr outstring
	
	ldaa #$FF
	staa $FE80

;
;	Wait a while so the CF adapter has time to initialize itself
;	and start talking sense
;
	ldaa #10
	ldx #0
sleep2:
	dex
	bne sleep2
	staa $FE80
	deca
	bne sleep2

;
;	Try and boot. We must wait for the adapter before we can do
;	anything.
;
	bsr waitready
;
;
;
	ldaa #$E0		; Drive 0, LBA
	staa $FE16
	bsr waitready

	jsr dumpreg

	ldx #loading
	jsr outstring
;
;	8bit mode
;
	ldaa #$01
	staa $FE11
	ldaa #$EF
	staa $FE17

	bsr waitready
	bsr dumpreg

	clra
	staa $FE13
	staa $FE14
	staa $FE15
	inca
	staa $FE12
	ldaa #$20
	staa $FE17
	bsr waitdrq

	bsr dumpreg

	ldx #$0000
	clrb
bytes:
	ldaa $FE10
	staa ,x
	inx
	ldaa $FE10
	staa ,x
	inx
	decb
	bne bytes

	bsr waitready
	ldaa @$0
	cmpa #$63
	bne badload
	ldab @$1
	cmpb #$03
	bne badload
	ldx #booted
	bsr outstring
	jmp @$2

badload:
	ldaa @$0
	bsr outcharhex
	ldab @$1
	bsr outcharhex
	ldx #bad
outdie:
	bsr outstring
stop:
	bra stop

waitready:
	ldaa #$F0
	staa $FE80
waitloop:
	ldaa $FE17
	anda #$40
	beq waitloop
	ldaa #$0F
	staa $FE80
	rts

waitdrq:
	ldaa $FE17
	anda #$09
	beq waitdrq
	anda #$01
	beq wait_drq_done
	ldaa $FE11
	bsr outcharhex
	bra badload

wait_drq_done:
	rts

dumpreg:
	ldaa #'['
	bsr outchar
	ldaa $FE11
	bsr outcharhex
	ldaa $FE12
	bsr outcharhexspc
	ldaa $FE13
	bsr outcharhexspc
	ldaa $FE14
	bsr outcharhexspc
	ldaa $FE15
	bsr outcharhexspc
	ldaa $FE16
	bsr outcharhexspc
	ldaa $FE17
	bsr outcharhexspc
	ldaa #']'
	bsr outchar
outdone1:
	rts
	
outstring:
outstringl:
	ldaa ,x
	beq outdone1
	bsr outchar
	inx
	bra outstringl

outcharhexspc:
	psha
	ldaa #' '
	bsr outchar
	pula
outcharhex:
	psha
	lsra
	lsra
	lsra
	lsra
	bsr outcharhex1
	pula
outcharhex1:
	anda #$0F
	adda #$30
	cmpa #$3A
	bcs outchar
	adda #7
outchar:
	psha
outcharw:
	ldaa $FEC5
	bita #$20
	beq outcharw
	pula
	staa $FEC0
	rts

dovec:
	ldx #vecstr
	jmp outdie

donmi:
	ldx #nmistr
	jmp outdie

hello:
	.ascii "C2014 6800/6808 512K RAM/ROM 0.01"
	.byte 13,10,13,10,0
loading:
	.ascii "Loading..."
	.byte 13,10,0
booted:
	.ascii "OK"
	.byte 13,10,0
bad:
	.ascii "not bootable"
	.byte 13,10,0
nmistr:
	.ascii "NMI"
	.byte 0
vecstr:
	.ascii "VEC"
	.byte 0


	.org $FFF0

	.word dovec
	.word dovec
	.word dovec
	.word dovec
	.word dovec
	.word dovec
	.word donmi
	.word start
