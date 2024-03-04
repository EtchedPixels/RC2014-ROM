	.globl conin,conout,const,conost,print
	.globl setjmp,longjmp

	.text

__go = go + 0x01000000;

.mri 1

	long $7FE00			; Top except for work/boot buffer
	long start

	ds 508

start:	
	move.w #$2700,sr		; Supervisor, no interrupts
	lea.l $80000000,a0
	lea.l __go,a1	; write into RAM (currently high)
	move.w #$4E49,-6(a1)		; jmp.l
	move.l a1,-4(a1)		; target
	move.b #$80,$2081(a0)		; aux port GPIO is high (not yet visible)
	move.b #$80,$2083(a0)		; A23 from aux port not gpio (ROM vanishes)
	jmp __go			; prefetch


go:	
	;
	;	Wipe memory and copy
	;
	clr d0
	move d0,a1			; to RAM
	lea.l $01000000,a0		; from ROM
init_data:
	move.l (a0)+,(a1)+
	cmp.l #_edata,a1
	bne init_data
	move.l #__bss_start,a0
init_bss:
	clr.l (a0)+
	cmp.l #_end,a0
	bne init_bss
	jmp rommain
;
;	Basic services. A6 must point to I/O
;
conout:
	btst.b #1,$2023(a6)
	beq conout
	move.b d0,$2021(a6)
	bclr.b #1,$2023(a6)
	rts
conin:
	btst.b #0,$2023(a6)
	beq conin
	move.b $2021(a6),d0
	bclr.b #0,$2023(a6)
	rts
conost:
	btst.b #1,$2023(a6)
	beq retff
ret0:
	moveq #0,d0
	rts
const:
	btst.b #0,$2023(a6)
	beq ret0
retff:
	moveq #-1,d0
	rts

;
;	C helpers
;
/* setjmp for 68000 and gcc.

   The called function is expected to save registers it damages so we need
   to do a full save here expect for a0/a1 d0/d1 which are scratch */

setjmp: move.l 4(sp),a0
	/* This is subtle but the compiler frame does not include the old
	   return address which will be recycled so we need to keep it as
	   well. The frame is only stable below this (ish) - the arguments
	   may also be trash but that's ok as we'll just discard them on
	   the return */
	move.l (a7),(a0)
	movem.l d2-d7/a2-a7,4(a0)	; 12 * 4 = 48 bytes
	moveq #0,d0			; return 0 from setjmp
	rts

longjmp:
	move.l 4(sp),a0
	move.l 8(sp),d0
	bne    d0_ok
	moveq  #1,d0
d0_ok:
	movem.l 4(a0),d2-d7/a2-a7
	move.l (a0),(a7)
	rts
