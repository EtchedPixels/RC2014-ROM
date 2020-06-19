;
;	We are loaded at $0200.
;	0000-7FFF are RAM 8000-FFFF ROM (except I/O)
;
;	We load an image from 0400-FDFF
;	and then jump to 0402 if the marker is right
;

	ORG $0200

	FCB $63
	FCB $03
start:
	; Map the full 64K to RAM
	LDAA #34
	STAA $FE7A
	LDAA #35
	STAA $FE7B
	; Our map is now 32 33 34 35

	LDS #$01FF	; Stack out of the way
	LDX #$0400

	LDAA #$01	; 0 is the partition/boot block
	STAA sector

	BSR waitready

	LDAA #$E0
	STAA $FE16	; Make sure we are in LBA mode
dread:
	BSR waitready
	LDAA #'.'
	BSR outchar
	LDAA sector
	CMPA #$7D	; loaded all of the image ?
	BEQ load_done
	INC sector
	STAA $FE13
	LDAA #$01
	STAA $FE12	; num sectors (drives may clear this each I/O)
	BSR waitready
	LDAA #$20
	STAA $FE17	; read command

	BSR waitdrq

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
	BRA dread

load_done:
	LDD $0400		; check signature
	CMPA #$03
	BNE bad_load
	CMPB #$63
	BNE bad_load

	LDX #running
	BSR outstring
	JMP $0402		; jump to byte following

bad_load:
	LDX #badimg
	BSR outstring
stop:
	BRA stop

waitready:
	LDAA $FE17
	ANDA #$40
	BEQ waitready
	RTS

waitdrq:
	LDAA $FE17
	ANDA #$09
	BEQ waitdrq
	RORA
	BCC wait_drq_done
	LDAA $FE11
	BSR outcharhex
	BRA bad_load

wait_drq_done:
	RTS

outstring:
	LDAA ,X
	BEQ outdone1
	BSR outchar
	INX
	JMP outstring

outcharhex:
	TAB
	RORA
	RORA
	RORA
	RORA
	BSR outcharhex1
	TBA
outcharhex1:
	ANDA #$0F
	ADDA #$30
	CMPA #$3A
	BCC outchar
	ADDA #7
outchar:
	PSHA
outcharw:
	LDAA $11	; FIXME: use TIM
	ANDA #$20
	BEQ outcharw
	PULA
	STAA $13
outdone1:
	RTS
badimg:
	FCB 13,10
	FCC "Image not bootable."
running:
	FCB 13,10,0

sector:
	FCB 0
