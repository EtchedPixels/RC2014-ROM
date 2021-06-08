	.globl conin,conout,const,conost,print
	.globl setjmp,longjmp

	.text

.mri 1

	long $7FE00			; Top except for work/boot buffer
	long start
	long trapbus
	long trapaddr
	long trapill
	long trapdiv
	long trapchk
	long trapv
	long trappriv
	long traptrace
	long traplineA
	long traplineF
	long unused
	long unused
	long unused
	long uninit
	long unused
	long unused
	long unused
	long unused
	long unused
	long unused
	long unused
	long unused
	long spurious
	long auto1
	long auto2
	long auto3
	long auto4
	long auto5
	long auto6
	long auto7
	long trap0
	long trap1
	long trap2
	long trap3
	long trap4
	long trap5
	long trap6
	long trap7
	long trap8
	long trap9
	long trap10
	long trap11
	long trap12
	long trap13
	long trap14
	long trap15

	;Reserved and user vectors beyond here so we don't need them

vec_bus 	equ	$80008
vec_addr 	equ	$8000C
vec_ill		equ	$80010
vec_div		equ	$80014
vec_chk		equ	$80018
vec_v		equ	$8001C
vec_priv	equ	$80020
vec_trace	equ	$80024
vec_A		equ	$80028
vec_F		equ	$8002C
vec_irq		equ	$80068
vec_trap0	equ	$80080
vec_trap1	equ	$80084
vec_trap2	equ	$80088
vec_trap3	equ	$8008C
vec_trap4	equ	$80090
vec_trap5	equ	$80094
vec_trap6	equ	$80098
vec_trap7	equ	$8009C
vec_trap8	equ	$800A0
vec_trap9	equ	$800A4
vec_trap10	equ	$800A8
vec_trap11	equ	$800AC
vec_trap12	equ	$800B0
vec_trap13	equ	$800B4
vec_trap14	equ	$800B8
vec_trap15	equ	$800BC


trapbus:
	move.l (vec_bus),-(sp)
	rts
trapaddr:
	move.l (vec_addr),-(sp)
	rts
trapill:
	move.l (vec_ill),-(sp)
	rts
trapdiv:
	move.l (vec_div),-(sp)
	rts
trapchk:
	move.l (vec_chk),-(sp)
	rts
trapv:
	move.l (vec_v),-(sp)
	rts
trappriv:
	move.l (vec_priv),-(sp)
	rts
traptrace:
	move.l (vec_trace),-(sp)
	rts
traplineA:
	move.l (vec_A),-(sp)
	rts
traplineF:
	move.l (vec_F),-(sp)
	rts
auto2:
	move.l (vec_irq),-(sp)
	rts
trap0:
	move.l (vec_trap0),-(sp)
	rts
trap1:
	move.l (vec_trap1),-(sp)
	rts
trap2:
	move.l (vec_trap2),-(sp)
	rts
trap3:
	move.l (vec_trap3),-(sp)
	rts
trap4:
	move.l (vec_trap4),-(sp)
	rts
trap5:
	move.l (vec_trap5),-(sp)
	rts
trap6:
	move.l (vec_trap6),-(sp)
	rts
trap7:
	move.l (vec_trap7),-(sp)
	rts
trap8:
	move.l (vec_trap8),-(sp)
	rts
trap9:
	move.l (vec_trap9),-(sp)
	rts
trap10:
	move.l (vec_trap10),-(sp)
	rts
trap11:
	move.l (vec_trap11),-(sp)
	rts
trap12:
	move.l (vec_trap12),-(sp)
	rts
trap13:
	move.l (vec_trap13),-(sp)
	rts
trap14:
	move.l (vec_trap14),-(sp)
	rts
trap15:
	move.l (vec_trap15),-(sp)
	rts



spurious:
auto1:
auto3:
auto4:
auto5:
auto6:
auto7:
unused:
uninit:
	rte

start:	
	move.w #$2700,sr		; Supervisor, no interrupts
	lea.l $010000,a6		; I/O base
	move.b #$AA,$80(a6)		; Lights
	; Now program the 16x50
	move.b #$80,$C3(a6)		; DLAB
	move.b #$01,$C0(a6)		; $0001 = 115200 (little endian)
	move.b #$00,$C1(a6)
	move.b #$03,$C3(a6)		; DLAB off, 8N1, RTS on
	move.b #$02,$C4(a6)
	move.b #$87,$C2(a6)
	move.b #'*',$C0(a6)
	;
	;	Now we gave the user something to see check the RAM
	;
	move.w #$5A5A,d0
	move.w d0,$20000
	cmp.w $20000,d0
	;
	;	If it looks like it works then go into C
	;
	beq go_c
	;
	;	RAM appears to be bad
	;
	move.b #'!',d0
	bsr conout
loop:	bra loop

	;
	;	Wipe memory. Eventually we'll need to copy the data
	;	segment in as well. We wipe the lot which is OK as we know
	;	our stack is empty and interrupts are off
	;
go_c:
	move.l #_etext,a0
	move.l #_data,a1
init_data:
	move.l (a0)+,(a1)+
	cmp.l #_edata,a1
	bne init_data
	move.l #__bss_start,a0
init_bss:
	clr.l (a0)+
	cmp.l #_end,a0
	bne init_bss
	bra rommain
;
;	Basic services. A6 must point to I/O
;
conout:
	btst.b #5,$C5(a6)
	beq conout
	move.b d0,$C0(a6)
	rts
conin:
	btst.b #0,$C2(a6)
	beq conin
	move.b $C0(a6),d0
	rts
conost:
	btst.b #5,$C5(a6)
	beq retff
ret0:
	moveq #0,d0
	rts
const:
	btst.b #0,$C2(a6)
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
