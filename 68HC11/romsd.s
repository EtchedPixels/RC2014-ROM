;
;	Boot loader for SD card. We want to keep this below 512 byte so that
;	we can fit it into the EEROM of the ROM enabled parts. That will
;	then allow us to omit any ROM in the system proper.
;
;	Load sector 0 from the SD card (512 bytes) at 0 and jump to it with
;	Y = start address X = I/O base, A = card type
;
;	Also does the minimal setup for the serial (115200) and for the
;	banked RAM card if present.
;
	ORG $7F00
CARDTYPE:
	FCB	0
BUF:
	FCB	0,0,0,0

CTMMC	EQU	1
CTSD2	EQU	2
CTSDBLK	EQU	3
CTSD1	EQU	4

SPCR	EQU	$28
SPSR	EQU	$29
SPDR	EQU	$2A
PDDR	EQU	$08
DDRD	EQU	$09

;
;	Link at the EEROM base for boot use, and set port E correctly so
;	that the Buffalo ROM in the CPU boots the EEROM.
;
	ORG $C000

START:
	SEI
	; Move the internal RAM to F000-F1FF with the I/O overlapping
	; F000-F03F. Whilst the iram is important for memory banking it's
	; not what we want in the direct page once we run a real OS
	; Unfortunately we have to set it in the first 64 E clocks so it
	; has to be picked at power up.
	LDAA #$FF
	STAA $103D
	LDX #$F000		; Internal I/O
	LDS #$F1FF		; Internal RAM for the moment
	LDAA #$AA
	STAA $FE80

	LDAA #$00		; 115200 baud
	STAA $2B,X		; Set up baud
	CLR  $2C,X		; 8N1
	LDAA #$0C		; interrupts off, rx/tx enabled
	STAA $2D,X

	; The UART comes up non-ready. Wait for it to go ready
UARTWT:
	BRCLR $2E,X $80 UARTWT
	; Give the poor user a hint their board is at least some level
	; of living
	LDAA #'*'
	STAA $2F,X

	; We might be a 512K/512K in which case we are the low 16K of ROM
	; in all banks. Put RAM in the low 48K if so. We don't actually
	; probe - these I/O ports will be unused on a 32K/32K setup

	LDX #$FE00
	LDAA #$20
	STAA $78,X
	INCA
	STAA $79,X
	INCA
	STAA $7A,X
	CLR  $7B,X
	INCA
	STAA $7C,X	; MMU ON

	LDX #$2000
	LDAA #$AA
	STAA ,X
	CMPA ,X
	BNE RAMERR
	LDAA #$55
	STAA ,X
	CMPA ,X
	BEQ RAMOK
RAMERR:
	LDAA #'R'
	JMP FAULT

RAMOK:
	LDX #$F000

	;
	;	Probe for an SD card and set it up as tightly as we can
	;

	LDAA #$53	; SPI on, master, mode 0, slow
	STAA SPCR,X
	LDAA #$20	; CS pin is an output
	STAA DDRD,X

	;	Raise CS send clocks
	JSR  CSRAISE
	LDAA #20
CSLOOP:
	JSR  SENDFF
	DECA
	BNE CSLOOP
	LDY #CMD0
	BSR  SENDCMD
	DECB	; 1 ?
	BNE SDFAIL
	LDY #CMD8
	BSR SENDCMD
	DECB
	BEQ NEWCARD
	JMP OLDCARD
NEWCARD:
	BSR GET4
	LDD BUF+2
	CMPD #0x01AA
	BNE SDFAIL
WAIT41:
	LDY #ACMD41
	BSR SENDCMD
	BEQ WAIT41
	LDY #CMD58
	BSR SENDCMD
	BNE SDFAIL
	BSR GET4
	LDAA BUF
	ANDA #$40
	BNE BLOCKSD2
	LDAA #CTSD2
INITOK:
	STAA CARDTYPE
	JMP LOADER

SDFAIL:
	LDA #'S'
	JMP FAULT

SENDCMD:
	LDAA ,Y
	BITA #$80
	BEQ SIMCMD
	PSHY
	LDY #CMD55
	BSR SENDCMD
	PULY
SIMCMD:
	BSR CSRAISE
	BSR CSLOWER
	CMPY #CMD0
	BEQ NOWAITFF
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

GET4:
	LDAA #4
	LDY #BUF
GET4L:
	BSR SENDFF
	STAB ,Y
	INY
	DECA
	BNE GET4L
	RTS

SDFAIL2:
	BRA SDFAIL

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

BLOCKSD2:
	LDAA #CTSDBLK
	BRA INITOK
OLDCARD:
	LDY #ACMD41_0	; FIXME _0 check ?
	BSR SENDCMD
	CMPB #2
	BHS MMC
WAIT41_0:
	LDY #ACMD41_0
	BSR SENDCMD
	BNE WAIT41_0
	LDAA #CTSD1
	STAA CARDTYPE
	BRA SECSIZE
MMC:
	LDY #CMD1
	JSR SENDCMD
	BNE MMC
	LDAA #CTMMC
	STAA CARDTYPE
SECSIZE:
	LDY #CMD16
	JSR SENDCMD
	BNE SDFAIL2
LOADER:
	BSR CSRAISE
	LDY #CMD17
	JSR SENDCMD
	BNE SDFAIL2
WAITDATA:
	BSR SENDFF
	CMPB #$FE
	BNE WAITDATA
	LDY #$0
	CLRA
DATALOOP:
	BSR SENDFF
	STAB ,Y
	BSR SENDFF
	STAB 1,Y
	INY
	INY
	DECA
	BNE DATALOOP
	BSR CSRAISE
	LDY #$0
	LDD ,Y
	CPD #$6811
	BNE NOBOOT
	LDAA CARDTYPE
	JMP 2,Y

;
;	Commands
;
CMD0:
	FCB $40,0,0,0,0,$95
CMD1:
	FCB $41,0,0,0,0,$01
CMD8:
	FCB $48,0,0,$01,$AA,$87
CMD16:
	FCB $50,0,0,2,0,$01
CMD17:
	FCB $51,0,0,0,0,$01
CMD55:	
	FCB $95,0,0,0,0,$01
CMD58:
	FCB $98,0,0,0,0,$01
ACMD41_0:
	FCB $41,0,0,0,0,$01
ACMD41:
	FCB $41,$40,0,0,0,$01


NOBOOT: LDA #'N'
FAULT:	BSR OUTCH
STOPB:	BRA STOPB

OUTCH:
	BRCLR $2E,X $80 OUTCH
	STAA $2F,X
	RTS
INCH:
	BRCLR $2E,X $20 INCH
	LDAA $F02F
	RTS
END:

	ORG $FFFE		; if we come up in normal mode
	FDB START
