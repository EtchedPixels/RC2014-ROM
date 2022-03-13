;
;	The SD boot code hands us
;	A = card type
;	X = I/O base ($F000)
;	Y = our base
;	S = internal RAM somewere at F1FF or so
;	P = interrupts off
;
;	IO at F000, IRAM at F000 (with some overlap)
;

	ORG $0000

CTMMC	EQU	1
CTSD2	EQU	2
CTSDBLK	EQU	3
CTSD1	EQU	4

SPCR	EQU	$28
SPSR	EQU	$29
SPDR	EQU	$2A
PDDR	EQU	$08
DDRD	EQU	$09

	FDB	$6811
START:
	BRA GO

LBAINC:	FDB	$200
CARDTYPE:
	FCB	$00
CMD17:
	FCB $51,0,0,0,0,$01

GO:
	; Block or byte LBA - set LBAINC accordingly
	STAA CARDTYPE
	CMPA #CTSDBLK
	BNE BYTEMODE
	LDD #1
	STD LBAINC
BYTEMODE:
	LDAA #$50		; SPI on master, faster
	STAA SPCR,X

	LDAA #$23
	STAA $FE7B		; RAM 3 in place of ROM

	LDY #$0200
	LDAA #$77		; $EE00 bytes ($0200-$EFFF)

LOADLOOP:
	PSHA			; Save count

	PSHY			; Save pointer whist we do the command
	LDY #CMD17
	; Move on an LBA block
	LDD 3,Y			; Update the offset or LBA number
	ADDD LBAINC
	STD 3,Y
	JSR SENDCMD		; Send a read command
	BNE SDFAIL
WAITDATA:
	BSR SENDFF		; Wait for the FE marker
	CMPB #$FE
	BNE WAITDATA
	PULY			; Recover data pointer
	CLRA			; Copy count (512 bytes)
DATALOOP:
	BSR SENDFF
	STAB ,Y
	BSR SENDFF
	STAB 1,Y
	INY
	INY
	DECA
	BNE DATALOOP
	BSR CSRAISE		; End command
	LDAA #'.'
	BSR OUTCH
	PULA			; Recover counter
	DECA
	BNE LOADLOOP		; Done ?
	LDAA #$0D
	BSR OUTCH
	LDAA #$0A
	BSR OUTCH
	JMP $0200		; And run

SDFAIL: LDAA #'E'
FAULT:	BSR OUTCH
STOPB:	BRA STOPB

OUTCH:
	BRCLR $2E,X $80 OUTCH
	STAA $2F,X
	RTS

CSLOWER:
	BCLR PDDR,X $20
	RTS
;
;	This lot must preserve A
;
CSRAISE:
	BSET PDDR,X $20
SENDFF:
	LDAB #$FF
SEND:
	STAB SPDR,X
SENDW:
	BRCLR SPSR,X $80 SENDW
	LDAB SPDR,X
	RTS

SENDCMD:
	BSR CSRAISE
	BSR CSLOWER
WAITFF:
	BSR SENDFF
	INCB
	BNE WAITFF
NOWAITFF:
	; Command, 4 bytes data, CRC all preformatted
	LDAA #6
SENDLP:
	LDAB ,Y
	BSR SEND
	INY
	DECA
	BNE SENDLP
	BSR SENDFF
WAITRET:
	BSR SENDFF
	BITB #$80
	BNE WAITRET
	CMPB #$00
	RTS
