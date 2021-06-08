;
;	We are loaded at $0200. We unmap the ROM, then load Flex and
;	hack it a bit

	.zp

ptr:	.word 0

	.abs

	.org $0200

	.byte $63
	.byte $03
	bra start
	.byte $00
	; For FLEX LINK command
secptr:
	.byte $00
	.byte $01
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00

;
;	Begin by copying the ROM support routines into the top of memory
;	before we page out the ROM
;
start:
	clrb
	ldx #$E000
copyrom:
	ldaa ,x
	incb		; RAM 1
	stab $FE38
	staa ,x		; Copy into RAM 1
	clrb		; ROM
	stab $FE38
	inx
	cpx #$0
	bne copyrom
;
;	Now turn the ROM off for good
;
	incb
	stab $FE38	; ROM off, RAM 1 present, 64K RAM now mapped

	lds #$01FF	; Stack out of the way
	ldx #$0500	; work buffer + 256
	ldaa secptr
	staa $0400	; set up initial block pointer
	ldaa secptr+1
	staa $0401

loadloop:
	bsr getbyte
	cmpa #02
	beq datablock
	cmpa #0x16	; execute
	beq execute
	inx		; ignore
	bra loadloop
datablock:
	bsr getbyte	; Load address
	staa @ptr
	bsr getbyte
	staa @ptr+1
	ldx @ptr
	bsr getbyte	; count for copying
	tab
blockin:
	bsr getbyte
	staa ,x
	decb
	bne blockin
	bra loadloop
execute:
	; TODO: patch Flex for the ACIA address and the ROM based
	; IDE disk I/O helpers

	; Get the run address and jump to it

	ldx $FFEC	; our (copy of) ROM vector for Flex mashing
	jsr ,x
	bsr getbyte
	staa @ptr
	bsr getbyte
	staa @ptr+1
	ldx @ptr
	jmp ,x

getbyte:
	cpx #$04FE
	beq newblock
	ldaa ,x
	inx
	rts

newblock:
	pshb		; Save B for the caller

	; ,x holds a 2 byte block number
	;
	;	We always boot from logical drive 0 which means we
	; 	can just use the block number we were given
	;
	bsr waitready
	bsr translate
	staa $FE14
	stab $FE13	; set the disk block in the IDE command
	ldaa #$01
	staa $FE12	; read 1 sector
	ldaa #$20
	staa $FE20	

	ldaa #$20
	staa $FE17	; read command
	bsr waitdrq

	ldx #$0400

	; Flex thinks in 256 byte chunks so just the first half of each
	; sector.
	clrb
bytes:
	ldaa $FE10
	staa ,x
	inx
	decb
	bne bytes
skips:
	ldaa $FE10
	inx
	decb
	bne skips

	pulb

	ldx #$0404	; next 252 bytes to process
	rts

waitready:
	ldaa $FE17
	anda #$40
	beq waitready
	rts

waitdrq:
	ldaa $FE17
	anda #$09
	beq waitdrq
	rora
	bcc wait_drq_done
	ldaa #$C3
	staa $FE80
fail:	bra fail

wait_drq_done:
	rts

;
;	Flex volumes self describe but our boot format is fixed so
;	we can do a single simple translate here for 18 spt
;
translate:
	clra
	ldab $0400
	lslb
	stab @ptr
	lslb		; x 4
	lslb		; x 8
	lslb
	rola		; x 16 (can overflow 8bits at this point)
	addb @ptr
	adca #0
	addb $0401	; add sector count
	adca #0
	rts
