;
;	68HC11 Boot ROM for 32K/32K or 512K cards. Not yet got any handling
;	for linear modes.
;
	ORG $7F00
IBUF:
	RMB 64
IBUF_END:
	FCB 0
LBA:
	FDB 0
	FDB 0
CURDSK:
	FCB 0

	ORG $7DFF
STACK:

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
	LDS #$F1FF		; Internal RAM for the moment
	LDAA #$3F
	STAA $F009
	LDAA #$2A
	STAA $F008
	LDX #$FE00
	LDAA #$AA
	STAA $80,X

	LDAA #$00		; 115200 baud
	STAA $F02B		; Set up baud
	LDAA #$00
	STAA $F02C		; 8N1
	LDAA #$0C		; interrupts off, rx/tx enabled
	STAA $F02D

	; The UART comes up non-ready. Wait for it to go ready
UARTWT:
	LDAB $F02E
	ANDB #$80
	BEQ UARTWT
	; Give the poor user a hint their board is at least some level
	; of living
	LDAA #'R'
	STAA $F02F

	; We might be a 512K/512K in which case we are the low 16K of ROM
	; in all banks. Put RAM in the low 48K if so. We don't actually
	; probe - these I/O ports will be unused on a 32K/32K setup

	LDAA #$32
	STAA $78,X
	INCA
	STAA $79,X
	INCA
	STAA $7A,X
	CLR  $7B,X
	INCA
	STAA $7C,X	; MMU ON

	LDAA #$AA
	STAA $2000
	CMPA $2000
	BNE RAMERR
	LDAA #$55
	STAA $2000
	CMPA $2000
	BNE RAMERR

	LDX #INTRO
NCMDE:
	JSR OUTS
	JSR NEWLINE
CMD:
	LDS #STACK
	LDX #PROMPT
	JSR OUTS
	JSR INS
	LDX #IBUF
	JSR SKPBLK
	LDAA ,X
	INX
	CMPA #'B'
	BEQ BOOT
	JSR OUTS
	LDAA #'?'
	JSR OUTCH
	JSR NEWLINE
	BRA CMD

BOOT:
	JSR CFINI
	CLRA
	JSR SETDISK
	CLRA
	CLRB
	LDX #0
	JSR SETLBA
	LDX #$100
	JSR READ
	LDX #$100
	CPX #$6811
	BNE NOTBOOT
	JMP $102
NOTBOOT:
	LDX #NBOO
	BRA NCMDE
NBOO:
	FCC 'Not bootable.'
	FCB 0

RAMERR:
	LDX #RAMBAD
	JSR OUTS
	JSR NEWLINE
RAMSTP:	BRA RAMSTP

RAMBAD:
	FCC 'AM FAIL'
	FCB 0

SETDISK:
	TSTA
	BNE BADDISK
	STAA CURDSK
	SEC
	RTS
BADDISK:
	CLC
	RTS

SETLBA:
	STX LBA
	STAA LBA+2
	STAB LBA+3
	RTS

CFINI:
	LDAA #$E0
	STAA $FE16
	BSR WAITRDY
	LDD #$EF01
	STAB $FE12
	STAA $FE17
	BRA WAITRDY

; TODO: Timeout

WAITRDY:
	LDAA $FE17
	BITA #$40
	BEQ WAITRDY
	RTS

WAITDRQ:
	LDAA $FE17
	ANDA #$09
	BEQ WAITDRQ
	ANDA #$01
	BEQ DRQDN
	; Error TODO
DRQDN:
	RTS

READ:
	BSR WAITRDY
	LDAA CURDSK
	LDAB #$E0
	BEQ DSK0
	LDAB #$F0
DSK0:	PSHB
	STAB $FE16
	BSR WAITRDY
	PULA
	ORAA LBA
	STAA $FE16
	LDAA LBA+1
	STAA $FE15
	LDAA LBA+2
	STAA $FE14
	LDAA LBA+3
	STAA $FE13
	LDD #$2001
	STAB $FE12
	STAA $FE17
	BSR WAITDRQ
	CLRA
RDDAT:	LDAB $FE10
	STAB ,X
	INX
	LDAB $FE10
	STAB ,X
	INX
	INCA
	BNE RDDAT
	RTS

SKPON:
	INX
SKPBLK:
	LDAA ,X
	BEQ SKPDON
	CMPA #32
	BEQ SKPON
	CMPA #9
	BEQ SKPON
SKPDON: RTS

INS:
	LDX #IBUF
INSL:
	BSR INCH
	CMPA #8
	BEQ INSBS
	CMPA #127
	BEQ INSBS
	BGT INSL
	CMPA #13
	BEQ INSNL
	CMPA #10
	BEQ INSNL
	CMPA #32
	BLO INS
	CPX #IBUF_END
	BEQ INSL
	STAA ,X
	BSR OUTCH
	INX
	BRA INSL
INSBS:
	CPX #IBUF
	BEQ INSL
	LDAA #8
	BSR OUTCH
	LDAA #32
	BSR OUTCH
	LDAA #8
	BSR OUTCH
	DEX
	BRA INSL
INSNL:
	CLR ,X
NEWLINE:
	LDAA #13
	BSR OUTCH
	LDAA #10
OUTCH:
	LDAB $F02E
	ANDB #$80
	BEQ OUTCH
	STAA $F02F
OUTDN:	RTS
OUTS:
	LDAA ,X
	BEQ OUTDN
	BSR OUTCH
	INX
	BRA OUTS
INCH:
	LDAA $F02E
	ANDA #$20
	BEQ INCH
	LDAA $F02F
	RTS

INTRO:
	FCC 'C2014 BOOT MONITOR FOR 68HC11'
	FCB 13,10
	FCB 0
PROMPT:
	FCC '> '
	FCB 0


	ORG $FFFE		; if we come up in normal mode
	FDB START
