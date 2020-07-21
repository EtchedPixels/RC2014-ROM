;
;	CUBIX I/O drivers. This is effectively the BIOS for CUBIX and is
;	really small and neat. The only thing that hides elsewhere of note
;	is that you can need a custom 'STTY' command for each platform
;	because the UART drivers don't handle the config the command does
;	direct to chip pokery.
;
;	When we are executed we need to have RAM mapped so we hook ourselves
;	in front of the actual ROM boot vector as well
;
;	The DCB. Passed to us in U for some calls
;
DRIVE	EQU	0
NCYL	EQU	1
NHEAD	EQU	2
NSEC	EQU	3
CYL	EQU	4
HEAD	EQU	5
SEC	EQU	6

;
;	Magic constants. We have F99F to the vectors free, except that on
;	our set up FExx is I/O which means we need to finish at FDFF and
;	we also have to slightly hack CUBIX not to do the initial checksum
;	to FFFF
;
	ORG	$F9CC

SSR	EQU	$E00B
;
;	Called by CUBIX with Y pointing to the table we should
;	complete
;
	JMP	HWINIT
;
;	Preboot - we patch the restart vector to jump here and we then jump
;	to the old one which is patched after
;
	JMP	PREBOOT
BOOTSTRAP:
	JMP	BOOTSTRAP		; patched by builder
;
;	From here onwards life is a bit more normal.	
;
HWINIT:
	LDA	#$8F
	STA	$FE80		; lights progress
	LDX	#RITAB
	LDB	#RISIZ
HWINI1:
	LDA	,X+
	STA	,Y+
	DECB
	BNE	HWINI1
	;
	;	Set up our UART
	;
	LDX	#$FEC0
	JSR	INIT16X50
	LDX	#$FEC8
	JSR	INIT16X50

	LDA	#$9F
	STA	$FE80

	LDA	#$0A
	BSR	WRSER1
	LDA	#$0D
	BSR	WRSER1
	;
	;	And CF adapter
	;
	JSR	WAITRDY
	LDA	#$BF
	STA	$FE80
	LDA	#$E0
	STA	$FE16
	JSR	WAITRDY
	LDA	#$01
	STA	$FE11
	LDA	#$EF
	JSR	SENDCMD
	JSR	WAITRDY
	LDA	#$FF
	STA	$FE80
	RTS
WRSER1:
	LDX	#$FEC0
	BRA	WRSER
WRSER2:	LDX	#$FEC8
WRSER:
	LDB	5,X
	BITB	#$20
	BEQ	WRSER
	STA	,X
WRNULL:
WRSER3:
WRSER4:	RTS

INIT16X50:
	LDA	#$80		; DLAB ON
	STA	3,X
	LDA	#$03		; 38400
	STA	,X
	CLR	1,X
	STA	3,X		; 8N1 DLAB OFF
	LDA	#$02	
	STA	4,X		; RTS on
	LDA	#$87
	STA	2,X		; FIFO on and reset
	RTS

RDSER1:
	LDX	#$FEC0
	BRA	RDSER
RDSER2:
	LDX	#$FEC8
RDSER:
	LDB	5,X
	BITB	#$01
	BEQ	RDNULL
	LDA	,X
	ORCC	#$04		; Set Z
	RTS
RDSER3:
RDSER4:
RDNULL:
	LDA	#$FF
	RTS
DFORMAT:
DHOME:
	CLRA
	RTS
DRDSEC:
	BSR	SETLBA
	BNE	DSKERR
	LDA	#$20
	BSR	SENDCMD
	BNE	DSKERR
	BSR	WAITDRQ
	BNE	DSKERR
	LDY	#512
RDLP:
	LDA	$FE10
	STA	,X+
	LEAY	-1,Y
	BNE	RDLP
	CLRA
DSKERR:
	RTS

DWRSEC:
	BSR	SETLBA
	BNE	DSKERR
	LDA	#$30
	BSR	SENDCMD
	BNE	DSKERR
	BSR	WAITDRQ
	BNE	DSKERR
	LDY	#512
WRLP:
	LDA	,X+
	STA	$FE10
	LEAY	-1,Y
	BNE	WRLP
	BSR	WAITRDY
	BNE	DSKERR
	CLRA
	RTS

;
;	This could do with error handling and timeouts but will do for now
;
;	Our drives are 32 cyl, 1 head, 255 sec/track which gives us just
;	under 4MB per drive, and we align on 4MB boundaries for sanity
;
SETLBA:
	BSR 	WAITRDY
	BNE	CMDERR
	; Cyl * 255
	CLRB
	LDA	CYL,U
	SUBB	CYL,U
	SBCA	#$00
	; + Sector
	ADDB	SEC,U
	ADCA	#$00
	; Now add 4MB per drive code (32 x 256 sectors)
	ADDA	DRIVE,U
	CLR	$FE15
	STA	$FE14
	STB	$FE13
	LDA	#$01
	STA	$FE12
	CLRA
	RTS
SENDCMD:
	BSR	WAITRDY
	BNE	CMDERR
	STA	$FE17
	CLRA
CMDERR:
	RTS
;
;	Strictly speaking our timeouts are wrong - we should allow 7 seconds
;	but this will do for debugging
;
WAITRDY:
	LDY	#0
WAITRDYL:
	LEAY	-1,Y
	BEQ	TIMEOUT
	LDB	$FE17
	BITB	#$80
	BNE	WAITRDYL
	BITB	#$01
	BNE	IDEERR
	BITB	#$40
	BEQ	WAITRDYL
	CLRB
	RTS
TIMEOUT:
	LDA	#$01
	RTS

WAITDRQ:
	LDY	#0
WAITDRQL:
	LDB	$FE17
	BITB	#$01
	BNE	IDEERR
	BITB	#$08
	BEQ	WAITDRQ
	; Z set
	CLRB
	RTS
IDEERR:
	; Ensures Z clear
	LDA #$01
	RTS

IGNORE:
	RTI

RITAB:
; Disks. Two 4MB disks with 1Mb free at the start for the PC boot area so we
; can also hide it in a partition table entry.
	FCB	8,32,1,255,0,0,0
	FCB	40,32,1,255,0,0,0
	FCB	0,0,0,0,0,0,0
	FCB	0,0,0,0,0,0,0
; Console
	FCB	1
	FCB	1
; Serial drivers
	FDB	RDNULL,RDSER1,RDSER2,RDSER3,RDSER4,0,0,0
	FDB	WRNULL,WRSER1,WRSER2,WRSER3,WRSER4,0,0,0
; Disk drivers
	FDB	DHOME,DRDSEC,DWRSEC,DFORMAT
; Vectors
	FDB	SSR
	FDB	IGNORE
	FDB	IGNORE
	FDB	IGNORE
	FDB	IGNORE
	FDB	IGNORE
; Flags and variables
	FCB	$FF		; display errors
	FCB	$00		; trace off
	FCB	$00		; debug off
	FCB	$00		; default drive A
	FCC	'MAIN'		; default path
	FCB	0,0,0,0
	FCB	0		; system drive A
	FCC	'SYSTEM'
	FCB	0,0

RISIZ	EQU	*-RITAB

PREBOOT:
	LDA	#$80
	STA	$FE80		; Debug lights
	STA	$FEC3
	LDA	#$03
	STA	$FEC0
	CLR	$FEC1
	STA	$FEC3
	DECA
	STA	$FEC4
	LDA	#$87
	STA	$FEC2
	LDA	#'*'
	STA	$FEC0
	LDA	#$20
	STA	$FE78		; Map low 32K of RAM normally
	INCA
	STA	$FE79
	LDA	#$23		; Map final top 16K as 32-48K for the moment
	STA	$FE7A
	CLR	$FE7B		; Keep ROM mapped in top 16K
	LDA	#$1
	STA	$FE7C		; MMU on

	LDA	#$81
	STA	$FE80		; Debug lights
	LDX	#$C000
	LDY	#$8000
COPYRAM:
	LDD	,X++
	STD	,Y++
	CMPX	#$0
	BNE	COPYRAM
	LDA	#$83
	STA	$FE80		; Debug lights

	LDA	#$22
	STA	$FE7A		; Map correct 32-48K segment
	LDA	#$23
	STA	$FE7B		; Map RAM copy directly under our feet
	LDA	#$87
	STA	$FE80		; Debug lights

	JMP	BOOTSTRAP	; Into the 'real' boot vector
