;
;	Replacement boot ROM for the RC2014 smaller configurations.
;
		org 0

rst0:
		di
		ld sp,3000h
		jp start
rst8:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
rst10:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
rst18:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
rst20:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
rst28:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
rst30:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
rst38:
		reti

start:
		; Testing hack
		; Set up pages on 512K/512K so we have RAM high
		xor a
		out (078h),a
		ld a,021h
		out (079h),a
		inc a
		out (07ah),a
		inc a
		out (07bh),a
		; Turn on 512K/512K paging keeping the low space mapped
		; On a simple paged system this is all a convenient no-op
		ld a,1
		out (07ch),a
		; Need to detect a TMS9918A first

		; ACIA detection: TX ready will be 1. Reset will force TX
		; ready to 0. If that fails it's not an ACIA
		in a,(0a0h)
		and 2
		jr z, not_acia
		ld a,03h
		out (0a0h),a
		in a,(0a0h)
		and 2
		jr nz, not_acia
		ld a,02h
		out (0a0h),a
		ld a,096h		; RTS low, 8N1, no ints
		ld a,'R'
		out (0a1h),a		; Start printing early
		ld hl, aciafunc
		ld de, noauxfunc
		jp init_ram
aciafunc:
		defw aciaout
		defw aciain
		defw aciapoll
		defw aciaopoll

ret255:		ld a,255
		ret

noauxfunc:
		defw ret255
		defw ret255
		defw ret255
		defw ret255

aciaout:
		out (0a1h),a
		ret
aciain:
		in a,(0a1h)
		ret
aciapoll:
		in a,(0a0h)
		and 080h
		ret
aciaopoll:
		in a,(0a0h)
		and 02h
		ret

not_acia:
		; 16x50 detection: There are register banks. Set the bank
		; for the baud rate divider and set it to AA. If it can't be
		; set to AA it's not a 16x50. If it can but switching bank
		; back still shows AA it cant be a 16x50
		;
		in a,(0a3h)
		ld e,a
		or 080h
		ld l,a
		out (0a3h),a
		in a,(0a1h)
		ld d,a
		ld a,0aah
		out (0a1h),a
		in a,(0a1h)
		cp 0aah
		jr nz, not_16x50
		ld a,e
		out (0a3h),a
		in a,(0a1h)
		cp 0aah
		jr nz, not_16x50
		; Switch to the baud rable, set it to 3 (38400), then switch
		; back set up 8N1, RTS low and reset the FIFO if present
		ld a,l
		out (0a3h),a
		xor a
		out (0a1h),a
		ld a,3
		out (0a0h),a
		out (0a3h),a
		dec a
		out (0a4h),a
		ld a,087h
		out (0a2h),a
		ld a,'R'
		out (0a0h),a
		ld hl,ns16x50func
		; FIXME: check for a 16C2552
		ld de,noauxfunc
		jp init_ram

ns16x50func:
		defw ns16x50out
		defw ns16x50in
		defw ns16x50poll
		defw ns16x50opoll

ns16x50out:
		out (0a0h),a
		ret
ns16x50in:
		in a,(0a0h)
		ret
ns16x50poll:
		in a,(0a5h)
		and 2
		ret
ns16x50opoll:
		in a,(0a5h)
		and 80
		ret

not_16x50:
		; Guess we have an SIO ?
		ld bc,0A80h		; 10 bytes port 80
		ld hl,sio_setup		; load, aim
		otir			; fire
		ld bc,0A82h		; 10 bytes port 82
		ld hl,sio_setup		; load, aim
		otir			; fire

		ld a,'R'
		out (0a1h),a
		ld a,2
		ld hl,siofunc
		ld de,siobfunc
		jp init_ram
siofunc:
		defw sioout
		defw sioin
		defw siopoll
		defw sioopoll
siobfunc:
		defw siobout
		defw siobin
		defw siobpoll
		defw siobopoll

sioout:
		out (081h),a
		ret
sioin:
		in a,(081h)
		ret
siopoll:
		in a,(080h)
		and 1
		ret
sioopoll:
		in a,(080h)
		and 4
		ret

siobout:
		out (083h),a
		ret
siobin:
		in a,(083h)
		ret
siobpoll:
		in a,(082h)
		and 1
		ret
siobopoll:
		in a,(082h)
		and 4
		ret

sio_setup:
		defb 000h
		defb 018h
		defb 004h
		defb 0C4h
		defb 001h
		defb 018h
		defb 003h
		defb 0E1h
		defb 005h
		defb 0EAh

;
;	Console helpers. These should avoid destroying DE to keep our BIOS
;	users happy
; 
;	These implement the corresponding CP/M BIOS functions.
;
conout:
		push ix
		ld ix,(confunc)
		ld l,(ix + 6)
		ld h,(ix + 7)
conoutw:	call jphl
		or a
		jr z,conoutw
		ld a,c
		ld l,(ix)
		ld h,(ix + 1)
		pop ix
		jp (hl)

conin:
		push ix
		ld ix,(confunc)
conin2:
		ld l,(ix + 4)
		ld h,(ix + 5)
coninw:		call jphl
		or a
		jr z,coninw
		ld l,(ix)
		ld h,(ix + 1)
		pop ix
		jp (hl)

constat:	
		push ix
		ld ix,(confunc)
conout2:
		ld l,(ix + 4)
		ld h,(ix + 5)
constat2:
		call jphl
		pop ix
		ld a,0
		ret z
		dec a
		ret

conostat:	
		push ix
		ld ix,(confunc)
conostat2:
		ld l,(ix + 6)
		ld h,(ix + 7)
		jr constat2

auxin:
		push ix
		ld ix,(auxfunc)
		jr conin2
auxout:
		push ix
		ld ix,(auxfunc)
		jr conout2
auxstat:
		push ix
		ld ix,(auxfunc)
		jr constat2
auxostat:
		push ix
		ld ix,(auxfunc)
		jr conostat2

strout:		ld hl,(confunc)
		ld e,(hl)
		inc hl
		ld d,(hl)
		pop hl
stroutl:
		ld a,(hl)
		or a
		jr z, strout_done
		call jpde
		jr stroutl
jphl:
strout_done:	jp (hl)
jpde:
		push de
		ret
		
		

init_ram:

		; TODO - keyboards
		ld (confunc),hl
		ld (auxfunc),de
		call strout
		ascii "C2014 8K Boot ROM v0.01"
		defb 13,10,13,10,0


		; Now go figure out what disk interfaces are present

		ld a,09Bh
		out (023h),a
		in a,(023h)
		cp 09Bh
		jr nz, not_ppide

		ld a,092h
		out (023h),a
		in a,(023h)
		cp 092h
		jr nz, not_ppide

		; Ok PPIDE present it seems

		ld ix,ppdiskfunc
		ld (diskfunc),ix

		; Do the reset and clear

		ld a,080h
		out (022h),a
		ld bc,01000h
wait1:
		dec bc
		ld a,b
		or c
		jr nz, wait1
		xor a
		out (022h),a

wait2:
		dec bc
		ld a,b
		or c
		jr nz, wait2

		ld de,0a16h		; Control to nIEN
		call ide_writeb

		; wait for sanity
		ld bc,-1
wait3:
		ex (sp),hl
		ex (sp),hl
		ex (sp),hl
		ex (sp),hl
		ex (sp),hl
		ex (sp),hl
		dec bc
		ld a,b
		or c
		jr nz, wait3

		jp now_boot

ppdiskfunc:
		dw ppide_writeb
		dw ppide_readb
		dw ppide_readsec
		dw ppide_writesec

not_ppide:
		; We assume IDE CF - it's trickier to test - we'll fail to
		; boot nicely if neither are there or no CF card
		ld ix,cfdiskfunc
		ld (diskfunc),ix

		ld de,0ee0h
		call ide_writeb_wr
		ld de,0901h
		call ide_writeb
		ld de,0fefh
		call ide_writeb_wr

		jp now_boot

cfdiskfunc:
		dw cf_writeb
		dw cf_readb
		dw cf_readsec
		dw cf_writesec
;
;	IDE disk subsystem
;

ide_writeb_wr:
		call ide_writeb

		; TODO: timeouts and review BUSY handling
ide_wait_ready:
		ld a,0fh
		call ide_readb
		ld c,a
		and 0c0h
		cp 040h
		ld a,c		; so can check ERR bit
		ret z
		jr ide_wait_ready
ide_wait_drq:
		ld a,0fh
		call ide_readb
		and 09h
		ret nz
		jr ide_wait_drq

ide_writeb:
		ld l,(ix)
		ld h,(ix + 1)
		jp (hl)
ide_readb:
		ld l,(ix + 2)
		ld h,(ix + 3)
		jp (hl)
ide_readsec:
		ld l,(ix + 4)
		ld h,(ix + 5)
		jp (hl)

ide_writesec:
		ld l,(ix + 6)
		ld h,(ix + 7)
		jp (hl)

cf_writeb:
		ld a,d
		cp 8
		ret nc		; Control port not present
		add 8
		ld c,a
		out (c),e
		ret

ppide_writeb:
		ld a,080h
		out (023h),a	; Turn the 82C55 data ports around
		ld a,d
		out (022h),a	; Register
		ld a,e
		out (020h),a	; Data
		ld a,d
		or 020h		; Register | WR
		out (022h),a	;
		ld a,d
		out (022h),a	; WR goes back high
		ld a,092h
		out(023h),a	; Turn the 82C55 back to reading
		ret


cf_readsec:
		ex de,hl
		ld bc,010h	; 256 bytes from 10h - twice
		inir
		inir
		ret		
		
ppide_readsec:
		ex de,hl
		ld a,08h	; Data Register
		out (022h),a	; Register

		ld b,0		; 256 words
ppide_readloop:
		ld a,028h	; Data Register | RD
		out (022h),a	;
		in a,(020h)	; Data
		ld (hl),a
		inc hl
		in  a,(021h)	; Data
		ld (hl),a
		inc hl
		ld a,08h	; RD goes back high
		out (022h),a
		djnz ppide_readloop

		ret

cf_writesec:
		ex de,hl
		ld bc,010h	; 256 bytes to 10h - twice
		otir
		otir
		ret		

ppide_writesec:
		ex de,hl
		ld a,080h
		out (023h),a	; Turn the 82C55 data ports around
		ld a,08h	; Data Register
		out (022h),a	; Register

		ld b,0		; 256 words
ppide_writeloop:
		ld a,(hl)
		out (020h),a	; Data
		inc hl
		ld a,(hl)
		out (021h),a	; Data
		inc hl
		ld a,028h	; Data Register | WR
		out (022h),a	;
		ld a,h
		out (022h),a	; WR goes back high
		djnz ppide_writeloop

		ld a,092h
		out(023h),a	; Turn the 82C55 back to reading
		ret
		
cf_readb:
		add 8
		ld c,a
		in a,(c)
		ret

ppide_readb:
		ld a,d
		out (022h),a
		or 040h		; READ
		out (022h),a
		in a,(020h)	; Data back
		ld c,a
		ld a,d
		out (022h),a	; READ back high
		ld a,c
		ret

;
;   Four volumes per disk laid out so that we hve 2^16 sectors per volume
;   in a way that requires no maths
;
;
;   Block addressed
;   00000000 000000DD TTTTTTTT SSSSSSSS
;
;
ide_setlba:
		ld a,(diskdev)
		cp 6
		ld e,0e0h
		jr c, disk0
		ld e,0f0h
disk0:
		ld d,0eh		; LBA 3/drive
		call ide_writeb_wr
		ld a,(diskdev)
		sub 2			; floppies
		and 3			; 4 per disk
		ld d,0dh		; LBA 2 is volume
		ld e,a
		call ide_writeb
		ld a,(disktrk)
		ld d,0ch		; LBA 1 is track
		ld e,a
		call ide_writeb
		ld d,0bh		; LBA 0 is sector
		ld a,(disksec)
		ld e,a
		call ide_writeb
		ld de,0a01h		; Count 1
		jp ide_writeb


		; Now map it

setsec:
		ld (disksec),bc
		ret
home:
		ld bc,0
settrk:
		ld (disktrk),bc
		ret
setdma:
		ld (diskdma),bc
		ret
seldsk:
		ld a,c
		cp 10		; AB - floppies, CDEF - disk 0 GHIJ - disk 1
		ld hl,0
		ret nc
		ld (diskdev),a
		ld hl,dphhd
		cp 2
		ret z
		ld hl,dphhd2
		ret

read:
		push ix
		ld ix,(diskfunc)
		ld a,(diskdev)
;		cp 2
;		jr c, floprd
		cp 10
		jr nc, failed
		call ide_setlba		; sets LBA, drive and count 1
		ld de,0f20h		; READ
		call ide_writeb
		call ide_wait_drq
		ld de,(diskdma)
		call ide_readsec
		call ide_wait_ready
		; TODO error handling
		xor a
		ret
failed:
		ld a,1
		ret

write:
		push ix
		ld ix,(diskfunc)
		ld a,(diskdev)
;		cp 2
;		jr c, flopwr
		cp 10
		jr nc, failed
		call ide_setlba		; sets LBA, drive and count 1
		ld de,0f30h		; WRITE
		call ide_writeb
		call ide_wait_drq
		ld de,(diskdma)
		call ide_writesec
		call ide_wait_ready
		; TODO error handling
		xor a
		ret

sectran:
		ld h,b
		ld l,c
		ret

flush:
		ret

multio:
		ret

move:
		ex de,hl
		ldir
		ex de,hl
		ret

devtbl:
		ld hl, 0		; no device table for now
		ret

now_boot:
		ld hl,functions
		ld de,0ff80h
		ld bc,0080h
		ldir

		ld hl,08000h
		ld (addr),hl

		ld c,2
		call seldsk

		ld bc,0
		call settrk

		ld b,010h		; plenty for CPMLDR

load_loop:
		push bc

		ld bc,(disksec)		; start of boot block
		inc bc
		call setsec

		ld bc,(addr)
		call setdma

		call read

		pop bc
		djnz load_loop

		ld hl,(08000h)
		ld de,0c0deh
		or a
		sbc hl,de
		jp z, 08002h		; into CPMLDR

		call strout
		ascii "Not bootable."
		defb 13,10,0


		; We will add more CP/M alike helpers as we go

; Stuff to do or irrelevant

time:
selmem:
setbnk:
xmove:
userf:
unused:
		ret

;
;	Moved to ff00 with BIOS work stack above it. May be able to tighten
;	this a bit
;
functions:
		jp unused
		jp unused
		jp constat
		jp conin
		jp conout
		jp auxout
		jp auxout
		jp auxin
		jp home
		jp seldsk
		jp settrk
		jp setsec
		jp setdma
		jp read
		jp write
		jp auxostat
		jp sectran
		jp conostat
		jp auxstat
		jp auxostat
		jp devtbl
		jp multio
		jp flush
		jp move
		jp time
		jp selmem
		jp setbnk
		jp xmove
		jp userf



;
;	ROM variables
;

		org 0fe00h
tmpsp:		dw 0
tmpa:		db 0
disksec:	dw 0
disktrk:	dw 0
diskdma:	dw 0
diskdev:	db 0
confunc:	dw 0
auxfunc:	dw 0
diskfunc:	dw 0
addr:		dw 0
dphhd:		; TODO- copy here
dphhd2:


;
;	BIOS code is invoked with
;
;		ld (tmpsp),sp
;		ld sp,0
;		out (38),a
;		call foo
;		out (38),a
;		ld sp,(tmpsp)
;	
;
;	We don't use interrupts. If we do then we'll need to do some more
;	work on wrapping and IRQ wrappers
;
		end rst0
