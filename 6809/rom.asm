
	org $FFF0
	FDB 0
	FDB SWI3
	FDB SWI2
	FDB FIRQ
	FDB IRQ
	FDB SWI
	FDB NMI
	FDB RESET

	org $8000
;
;	This bit of code is run from $0 in RAM with a copy of the boot
;	ROM in the low 32K. It copies the boot ROM back up to the right
;	addresses in a RAM bank. It needs to be relocatable
;
BOOTSTRAP:
	LDA #$03
	STA $FE80
	LDA #$01		; Select high bank 1
	STA $FE38
	LDX #$0
	LDY #$8000
COPYUP:
	LDD ,X++
	STD ,Y++
	CMPY #$0000
	BNE COPYUP
	; Now jump to the real copy
	LDA #$04
	STA $FE80
	JMP GO
	;
	;	From this point on we are running the RAM copy
	;
GO:
	LDA #$05
	STA $FE80
STOP:
	BRA STOP
;
;	First steps before the ROM is moved into RAM space
;
RESET:
	CLR $FE38
	LDA #$AA
	STA $FE80
	LDA #$80
	STA $FEC3
	LDA #$01
	STA $FEC0
	CLR $FEC1
	LDA #$03
	STA $FEC3
	LDA #$02
	STA $FEC4
	LDA #$87
	STA $FEC2

	LDA #'R'
	STA $FEC0

	LDA #$55
	STA $00
	CMPA $00
	BNE RAMFAIL

	LDA #$AA
	STA $00
	CMPA $00
	BNE RAMFAIL

	LDA #$01
	STA $FE80

COPIER:
	LDX #$8000
	LDY #$0000
	LDD ,X++
	STD ,Y++
	CMPY #$8000
	BNE COPIER

	LDA #$02
	STA $FE80

	JMP $0000	


LOOP:
	INCA
	STA $FE80
	CLRB
INCL:
	INCB
	BNE INCL
	BRA LOOP

SWI3:
SWI2:
FIRQ:
IRQ:
SWI:
NMI:
	LDA #$C3
DOFAIL:	STA $FE80
FAIL:	BRA FAIL
RAMFAIL:
	LDA #$81
	BRA DOFAIL
