;
;	807xx CPU bootstrap
;
;	0xFE10	CF adapter
;	0xFEC0	16x50 UART
;	0xFE7x	MMU for banked memory card
;
	.dp

tmp:
	.byte	0

	.code

	.byte 0		; we run from 1 - don't ask 8)
start:
	jmp	go
	jmp	inta
	jmp	intb

go:
	ld	p1,=0xFDFF	; stack
	ld	p2,=0xFEC0

	ld	a,=0x80		; DLAB
	st	a,3,p2
	ld	a,=0x01		; 115200
	st	a,0,p2
	ld	a,=0x00
	st	a,1,p2
	ld	a,=0x03		; DLAB off 8N1
	st	a,3,p2
	ld	a,=0x02
	st	a,4,p2		; RTS on
	ld	a,=0x87
	st	a,2,p2		; FIFO on and reset
	ld	a,='R'		; start of banner for debug aid
	st	a,0,p2		; and print it

	ld	p3,=0xFE00

	ld	a,=0		; ROM bank 0 (as mapped)
	st	a,0x78,p3	; Map 0 is ROM
	ld	a,=0x21
	st	a,0x79,p3	; RAM page 1 at 16K
	ld	a,=0x22
	st	a,0x7A,p3	; RAM page 2 at 32K
	ld	a,=0x23
	st	a,0x7B,p3	; RAM page 3 at 48K

	ld	a,=1
	st	a,0x7C,p3	; MMU on, RAM appears, stack valid

	jsr	outs
	.ascii	"Cbus Loader For INS807x"
	.byte	13,10
	.ascii	"Loading"
	.byte	0

boot:	jsr	waitready

	ld	a,=0xE0
	st	a,0x16,p3	; Drive 0 LBA

	jsr	waitready

	ld	a,=0x01		; Set 8bit mode
	st	a,0x11,p3
	ld	a,=0xEF
	st	a,0x17,p3	

	jsr	waitready

	ld	a,=1
	st	a,0x12,p3	; One sector
	ld	ea,=0
	st	ea,0x13,p3	; LBA 0
	st	a,0x15,p3
	ld	a,=0x20
	st	a,0x17,p3	; READ

	jsr	waitdrq

	ld	p2,=0xFC00
	ld	a,=0
	st	a,:tmp
loop:
	ld	a,0x10,p3
	st	a,@1,p3
	ld	a,0x10,p3
	st	a,@1,p3
	dld	a,:tmp
	bnz	loop

	jsr	waitready

	;	Block is now at 0xFC00-FDFF

	jsr	outs
	.ascii	", booting"
	.byte	13,10,0

	jmp	0xFC00

outs:
	push	p2
	push	p3
	ld	ea,4,p1		; return addr
	ld	p3,ea
	ld	p2,=0xFEC0
nextch:
	ld	a,5,p2
	and	a,=0x20
	bz	nextch
	ld	a,@1,p3
	bz	end
	st	a,0,p2
	bra	nextch
end:
	ld	ea,p3
	st	ea,4,p1
	pop	p3
	pop	p2
	ret

inta:
intb:
	ret

waitready:
	ld	a,0x17,p3
	and	a,=0x40
	bz	waitready
	ret

waitdrq:
	ld	a,0x17,p3
	and	a,=0x09
	bz	waitdrq
	and	a,=0x01
	bnz	fail
	ret
fail:
	jsr	outs
	.ascii	"Disk Error"
	.byte	13,10,0
dead:	bra	dead

