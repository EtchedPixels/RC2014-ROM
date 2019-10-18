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

	ORG $C000

start:
	SEI
	LDX #$FE00
;
;	LED pattern
;
	LDAA #$AA
	STAA $80,X

;
;	Program the UART
;
	LDAA #$04			; NRZ, Internal / 16 (115200 baud)
	STAA $10
	LDAA #$0A			; TX/RX enable, no interrupts
					; Only 8N1 supported
	STAA $11
;
;	Display something
;

	LDAA #'R'
	STAA $13

	LDAA #$81
	STAA $80,X
;
;	Now set up the memory mappings
;
;	Do byte wide for now - we can probably do this with two STD
;
	LDAA #32			; Low 32K becomes 6502 RAM
	STAA $78,X			; Needs to be this way up for a 6502
	LDAA #33
	STAA $79,X
	LDAA #1				; Map the ROM backwards so that we keep 
	STAA $7A,X			; the vectors the same (at FFFx)
	CLR $7B,X

	LDAA #$88
	STAA $80,X

	LDAA #1
	STAA $7C,X			; Banking on, map changes here

	LDAA #$8C
	STAA $80,X

;	LDX #0
;sleep4:
;	DEX
;	BNE sleep4

;
;	Something resembling sanity now exists. We have 32K RAM low, 32K ROM
;	high and the world is good
;

	LDAA #$CF
	STAA $80,X

	LDX #$7FFF
	TXS
	LDX #hello
	JSR outstring
	
	LDAA #$FF
	STAA $FE80

;
;	Wait a while so the CF adapter has time to initialize itself
;	and start talking sense
;
	LDAA #10
	LDX #0
sleep2:
;	DEX
;	BNE sleep2
	STAA $FE80
	DECA
	BNE sleep2

;
;	Try and boot. We must wait for the adapter before we can do
;	anything.
;
	BSR waitready
;
;
;
	LDAA #$E0		; Drive 0, LBA
	STAA $FE16
	BSR waitready

	JSR dumpreg

	LDX #loading
	JSR outstring
;
;	8bit mode
;
	LDAA #$01
	STAA $FE11
	LDAA #$EF
	STAA $FE17

	BSR waitready
	BSR dumpreg

	CLRA
	STAA $FE13
	STAA $FE14
	STAA $FE15
	INCA
	STAA $FE12
	LDAA #$20
	STAA $FE17
	BSR waitdrq

	BSR dumpreg

	LDX #$0200
	CLRB
bytes:
	LDAA $FE10
	STAA ,X
	INX
	LDAA $FE10
	STAA ,X
	INX
	DECB
	BNE bytes

	BSR waitready
	LDD $0200
	CMPA #$63
	BNE badload
	CMPB #$03
	BNE badload
	LDX #booted
	BSR outstring
	JMP $0202

badload:
	LDD $0200
	BSR outcharhex
	TBA
	BSR outcharhex
	LDX #bad
outdie:
	BSR outstring
stop:
	BRA stop

waitready:
	LDAA #$F0
	STAA $FE80
waitloop:
	LDAA $FE17
	ANDA #$40
	BEQ waitloop
	LDAA #$0F
	STAA $FE80
	RTS

waitdrq:
	LDAA $FE17
	ANDA #$09
	BEQ waitdrq
	ANDA #$01
	BEQ wait_drq_done
	LDAA $FE11
	BSR outcharhex
	BRA badload

wait_drq_done:
	RTS

dumpreg:
	LDAA #'['
	BSR outchar
	LDAA $FE11
	BSR outcharhex
	LDAA $FE12
	BSR outcharhexspc
	LDAA $FE13
	BSR outcharhexspc
	LDAA $FE14
	BSR outcharhexspc
	LDAA $FE15
	BSR outcharhexspc
	LDAA $FE16
	BSR outcharhexspc
	LDAA $FE17
	BSR outcharhexspc
	LDAA #']'
	BSR outchar
	RTS
	
outstring:
outstringl:
	LDAA ,X
	BEQ outdone1
	BSR outchar
	INX
	BRA outstringl

outcharhexspc:
	PSHA
	LDAA #' '
	BSR outchar
	PULA
outcharhex:
	PSHA
	LSRA
	LSRA
	LSRA
	LSRA
	BSR outcharhex1
	PULA
outcharhex1:
	ANDA #$0F
	ADDA #$30
	CMPA #$3A
	BCS outchar
	ADDA #7
outchar:
	PSHA
outcharw:
	; FIXME: switch to TIM once have a 6303 assembler
	LDAA $11
	ANDA #$20
	BEQ outcharw
	PULA
	STAA $13
outdone1:
	RTS

dovec:
	LDX #vecstr
	JMP outdie

donmi:
	LDX #nmistr
	JMP outdie

hello:
	FCC "C2014 6303 512K RAM/ROM 0.01"
	FCB 13,10,13,10,0
loading:
	FCC "Loading..."
	FCB 13,10,0
booted:
	FCC "OK"
	FCB 13,10,0
bad:
	FCC "not bootable"
	FCB 13,10,0
nmistr:
	FCC "NMI",0
	FCB 0
vecstr:
	FCC "VEC",0
	FCB 0


	ORG $FFF0

	FDB dovec
	FDB dovec
	FDB dovec
	FDB dovec
	FDB dovec
	FDB dovec
	FDB donmi
	FDB start
