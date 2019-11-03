;
;	Coprocessor Boot ROM
;

	org 0

start:
	di
	im 1
	ld hl,0fe00h
	ld sp,hl
	ld bc,0
	ld a,0aah
	out (c),a		; Indicator for primary

sync0:
	in a,(c)
	bit 7,a
	jr z, sync0
;
;	Send the host a banner
;
	ld hl,banner
	call sendstring

;
;	Now boot something - the 0 is both end of string and initial
;	counter
;
	xor a
	out (c),a		; booter sees initial count (0)
;
;	We don't know if it was odd or even sized so force a full
;	hi then lo sync before bootloading.
;
waithi:
	in a,(c)
	bit 7,a
	jr z,waithi

bootone:
	in a,(c)
	bit 7,a
	jr nz,bootone
	rla
	rla
	rla
	rla
	and 0f0h
	ld e,a			; data bits high
	ld a,55h
	out (c),a		; please send other half
bootzero:
	in a,(c)
	bit 7,a
	jr z, bootzero
	and 0fh
	or e			; a is now a byte of real data
	ld (hl),a
	out (c),l		; booter sees count
	inc l
	jr z, load_done
	jr bootone

load_done:
	ld a,0cch		; for the booter to know
	out (c),a
	jp 0fe00h		; run uploaded code


;
;	We mut be synched when this is called. The far end bit 7 should
;	be high on entry
;

sendstring:
	ld a,(hl)
	inc hl
	or a
	ret z
	out (c),a		; Send a byte
sendstrwl:
	in a,(c)		; Wait for the receiver to signal low
	bit 7,a
	jr nz, sendstrwl
	; Same again the other bit direction
	ld a,(hl)
	inc hl
	or a
	ret z
	out (c),a		; Send byte
sendstrwh:
	in a,(c)
	bit 7,a			; Wait for receiver to go high
	jr z, sendstrwh
	jr sendstring

banner:
	db "Z80 Coprocessor Boot ROM 0.01 Alpha"
	db 0
