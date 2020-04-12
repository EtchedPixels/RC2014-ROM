;
;	Replacement boot ROM for the RC2014 smaller configurations.
;
;	(C) 2019-2020 Alan Cox
;
;	Font
;	Copyright (C) 1999, 2000, 2004 Michael Reinelt <michael@reinelt.co.at>
;	Copyright (C) 2004 The LCD4Linux Team <lcd4linux-devel@users.sourceforge.net
;	Slightly tweaked for Fuzix to put back a proper '~' symbol
;
; This ROM is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2, or (at your option)
; any later version.
;
; This ROM is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
;

VERSION		equ	0003h


XMTIMER		equ	0000h		; cycles of constat before we give up
					; reset each valid block
ACK		equ	6
EOT		equ	4
NAK		equ	21
SOH		equ	1

		org 0

rst0:
		di
		ld sp,0
		jp start
		nop
rst8:				; print char in A, preserve BC-HL
		push bc
		push de
		push hl
		ld c,a
		jr rst8con
		nop
		nop
rst10:				; get a char in A, preserve BC-HL
		push bc
		push de
		push hl
		call conin
		jr poppers
rst18:				; test for input ready, preserve BC-HL
		push bc		; on return A = 255 for yes, 0 for no
		push de
		push hl
		call const
		jr poppers
rst20:
		jp strout
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
rst8con:
		call conout
poppers:
		pop hl
		pop de
		pop bc
		ret

start:
		; Start by tring to do UART detection without writing to
		; RAM. Get a first letter out any way we can so the user
		; has diagnostics
		;
		;
		; We may have to slip in some very early platform detection
		; to also support Tom's SBC and the Linc80
		;

		;
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
		ld a,1
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
		and 01h
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
		ld c,a
		out (0a3h),a
		in a,(0a1h)
		ld d,a
		ld a,0aah
		out (0a1h),a
		in a,(0a1h)
		cp 0aah
		jp nz, not_16x50
		ld a,e
		out (0a3h),a
		in a,(0a1h)
		cp 0aah
		jp z, not_16x50
		; Switch to the baud rable, set it to 3 (38400), then switch
		; back set up 8N1, RTS low and reset the FIFO if present
		ld a,c
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
		ld de, noauxfunc

		; Same again for 0a8h (seems to be cheaper to duplicate than
		; mess with modifying c a lot)
		in a,(0abh)
		ld e,a
		or 080h
		ld c,a
		out (0abh),a
		in a,(0a9h)
		ld d,a
		ld a,0aah
		out (0a9h),a
		in a,(0a9h)
		cp 0aah
		ld a,2
		jp nz, init_ram
		ld a,e
		out (0abh),a
		in a,(0a9h)
		cp 0aah
		ld a,2
		jp z, init_ram
		; Switch to the baud rable, set it to 3 (38400), then switch
		; back set up 8N1, RTS low and reset the FIFO if present
		ld a,c
		out (0abh),a
		xor a
		out (0a9h),a
		ld a,3
		out (0a8h),a
		out (0abh),a
		dec a
		out (0ach),a
		ld a,087h
		out (0aah),a

		ld de,ns16x50altfunc
		ld a,2
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
		and 1
		ret
ns16x50opoll:
		in a,(0a5h)
		and 20h
		ret

ns16x50altfunc:
		defw ns16x50altout
		defw ns16x50altin
		defw ns16x50altpoll
		defw ns16x50altopoll

ns16x50altout:
		out (0a8h),a
		ret
ns16x50altin:
		in a,(0a8h)
		ret
ns16x50altpoll:
		in a,(0adh)
		and 1
		ret
ns16x50altopoll:
		in a,(0adh)
		and 20h
		ret

not_16x50:
		; TODO: Add SC26C92 and QUART detection ?
		; Guess we have an SIO ?

		; If we wanted to support Tom's SBC as well we would need
		; to check for an SIO and check how it is mapped as Tom's
		; SBC has DA DB CA CB whilst RC2014 is CA DA CB DB

		ld bc,0A80h		; 10 bytes port 80
		ld hl,sio_setup		; load, aim
		otir			; fire
		ld bc,0A82h		; 10 bytes port 82
		ld hl,sio_setup		; load, aim
		otir			; fire

		ld a,'R'
		out (081h),a
		ld a,2
		ld hl,siofunc
		ld de,siobfunc
		ld a,4
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
		ld l,(ix + 2)
		ld h,(ix + 3)
		pop ix
		jp (hl)

const:
		push ix
		ld ix,(confunc)
conout2:
		ld l,(ix + 4)
		ld h,(ix + 5)
const2:
		call jphl
		pop ix
		ld a,0
		ret z
		dec a
		ret

conost:
		push ix
		ld ix,(confunc)
conost2:
		ld l,(ix + 6)
		ld h,(ix + 7)
		jr const2

auxin:
		push ix
		ld ix,(auxfunc)
		jr conin2
auxout:
		push ix
		ld ix,(auxfunc)
		jr conout2
auxist:
		push ix
		ld ix,(auxfunc)
		jr const2
auxost:
		push ix
		ld ix,(auxfunc)
		jr conost2

strout:		
		push hl
		ld hl,(confunc)
		ld e,(hl)
		inc hl
		ld d,(hl)
		pop hl
		ex (sp),hl
		push bc
stroutl:
		ld a,(hl)
		or a
		jr z, strout_done
		call jpde
		inc hl
		jr stroutl
strout_done:	pop bc
		ex (sp),hl
		ret
jpde:
		push de
		ret
		

;
;		PS/2 Keyboard Interface
;

LALT		equ	11h
LSHIFT		equ	12h
LCTRL		equ	14h
CAPSLOCK	equ	58h
RSHIFT		equ	59h
RALT		equ	91h
RCTRL		equ	94h
LWIN		equ	9Fh
RWIN		equ	0A7h



ps2probe:
		ld bc,01000h		; B 16 C 0
probewait1:
		push bc
		call ps2kbd_get		; Ask for a byte. We should get an FF
		pop bc			; if the keyboard is attached and
		inc hl			; running
		ld a,h
		or l
		jr z, probe_noreply
		bit 7,h
		jr nz, probe_err
		ld c,1			; We have seen life
probe_err:
probe_noreply:
		pop bc
		djnz probewait1
		;
		;	Try a reset
		;
		ld l,255		; Send a reset expect an ACK
		call ps2kbd_put
		ld a,0fah
		cp l
		jr z, ps2good
		call ps2kbd_get
		bit 7,h
		jr z, ps2good
		; Failed
		xor a
		cp c
		ret z		; Definitely a fail (return Z)
ps2good:
		; Now program the keyboard to scan code 2. This is the mode
		; DOS/Windows use and many keyboards today don't even
		; implement the other modes, let alone get them right.
		ld l,0f6h
		call ps2kbd_put	; Defaults
		ld l,0edh
		call ps2kbd_put	; LEDs off
		ld l,000h
		call ps2kbd_put
		ld l,0f0h	; Scan code 2
		call ps2kbd_put
		ld l,002h
		call ps2kbd_put
		ld l,0f4h
		call ps2kbd_put
		; Flush any noise
		call ps2kbd_get
		call ps2kbd_get
		call ps2kbd_get
		call ps2kbd_get
		xor a
		inc a
		ret		; NZ - found

;
;	Try to process a byte from the keyboard. Many codes are multibyte
;	sequences so we just keep calling this until it decides itself that
;	a character is pending and sets ps2pend.
;
ps2byte:
		call ps2kbd_get
		; negative returns are error or timeout. If so return to
		; the caller
		bit 7,h
		ret nz
		; E0 is a prefix indicating shifted codes
		ld a,l
		cp 0e0h
		jr z, setshifted
		; F0 is the keyup code
		cp 0f0h
		jr z, setkeyup
		; If it was not a prefix try and decode it
		call keycode
		; As we got a non shift all the shifting flags are now
		; reset
		xor a
		ld (keyup),a
		ld (keyshifted),a
		ret
setshifted:
		ld a,080h
		ld (keyshifted),a
		ret
setkeyup:
		ld a,1
		ld (keyup),a
		ret

;
;	Attempt to turn a sequence of PS/2 codes into a character. At this
;	point shifts have been accounted for
;
keycode:	; C = code
		; Hack for the ugly break key stuff and multimedia keys
		; that produce long streams of bytes we ignore
		ld a,(keybreak)
		or a
		jr z,notbrk
		dec a
		ld (keybreak),a
		ret
notbrk:
		; 0E1h is the media keys, more long streams to avoid
		ld a,c
		cp 0e1h
		jr nz, not_media
		ld a,7
		ld (keybreak),a
		ret
not_media:
		; An ACK - shouldn't have gotten here but ignore it
		cp 0aah		; random ack
		ret z
		; An FF - the keyboard reset or got cross with us. Maybe
		; we should take action but for now just cross fingers
		cp 0ffh		; error
		ret z
		; Get the shift state and or it into the code so we fold
		; the E0 codes in.
		ld de,(keyshifted)
		or e		; set top bit if shifted
		ld c,a

		ld a,(keyup)
		or a
		jr z,keydown

		;
		;	Shifts into E. Adjust shift key states
		;

		ld de,(shift_down)
		cp LSHIFT
		jr nz, noulshift
		res 0,e
		jr doneups
noulshift:
		cp RSHIFT
		jr nz, nourshift
		res 1,e
		jr doneups
nourshift:
		cp LCTRL
		jr nz, noulctrl
		res 2,e
		jr doneups
noulctrl:
		cp RCTRL
		jr nz, nourctrl
		res 3,e
		jr doneups
nourctrl:
		cp LALT
		jr nz, noulalt
		res 4,e
		jr doneups
noulalt:
		cp RALT
		jr nz, nouralt
		res 5,e
doneups:
		ld a,e
		ld (shift_down),a
nouralt:	ret

;
;		Key down events. Start by adjusting any shift states
;
keydown:
		ld de,(shift_down)
		cp LSHIFT
		jr nz, nolshift
		res 0,e
		jr doneups
nolshift:
		cp RSHIFT
		jr nz, norshift
		res 1,e
		jr doneups
norshift:
		cp LCTRL
		jr nz, nolctrl
		res 2,e
		jr doneups
nolctrl:
		cp RCTRL
		jr nz, norctrl
		res 3,e
		jr doneups
norctrl:
		cp LALT
		jr nz, nolalt
		res 4,e
		jr doneups
nolalt:
		cp RALT
		jr nz, noralt
		res 5,e
		jr doneups
;
;	Not a shift key/ Try and convert it using the key map. Allow for
;	shift and control effects
;
;	Capslock should invert the case if A-Z
;	Numlock should invert the shift state if code 68-7D inclusive
;
noralt:
		; TODO: capslock
		ld b,0
		ld hl,keymap
		add hl,bc
		ld a,(hl)

		; TODO: numlock
		ld de,(shift_down)
		bit 0,e
		jr nz, shiftmod
		bit 1,e
		jr nz, shiftmod
nextmod1:
		bit 2,e
		jr nz, ctrlmod
		bit 3,e
		jr nz, ctrlmod
nextmod2:
		bit 4,e
		jr nz, altmod
		bit 5,e
		jr nz, altmod

ps2queue:
		; If the translation is 0 it's a key that had no meaning
		; if not then queue the key
		or a
		ret z			; no valid key mapping
		ld (ps2char),a
		ld a,1
		ld (ps2pend),a
		ret
;
;	Shifted. If not special look up in the second table half
;	and use that if present
;
;	A = key, C = scancode
;
shiftmod:
		bit 7,c
		jr nz, ps2queue
		; Look to see if there is a shifted translation. If not
		; keep the original
		ld b,0
		ld hl,keymap+0x80
		add hl,bc
		ld d,a
		ld a,(hl)
		or a
		jr nz,nextmod1
		ld a,d
		jr nextmod1
ctrlmod:
		; Control just clears the top bits
		and 31
		jr nextmod2
altmod:
		; Not clear what to do with alt. We do the classic meta key
		; and set the top bit
		or 128
		jr ps2queue
		

;
;	Translate the main PS/2 keys into something that kind of goes
;	with the ADM 3A emulation. We could map more keys like function keys
;	as non ascii codes if we wanted.
;
;	UK keymap
;
keymap:
		; 00h
		defb 0, 0, 0, 0, 0, 0, 0, 0
		defb 0, 0, 0, 0, 0, 9, '`', 0
		; 10h
		defb 0, 0, 0, 0, 0, 'q', '1', 0
		defb 0, 0, 'z', 's', 'a', 'w', '2', 0
		; 20h
		defb 0, 'c', 'x', 'd', 'e', '4', '3', 0
		defb 0, ' ', 'v', 'f', 't', 'r', '5', 0
		; 30h
		defb 0, 'n', 'b', 'h', 'g', 'y', '6', 0
		defb 0, 0, 'm', 'j', 'u', '7', '8', 0
		; 40h
		defb 0, ',', 'k', 'i', 'o', '0', '9', 0
		defb 0, '.', '/', 'l', ';', 'p', '-', 0
		; 50h
		defb 0, 0, 39, 0, '[', '=', 0, 0	; 39 is quote
		defb 0, 0, 10, ']', 0, '#', 0, 0
		; 60h
		defb 0, '\', 0, 0, 0, 0, 8, 0
		defb 0, '1', 0, '4', '7', 0, 0, 0
		; 70h
		defb 0, '.', '2', '5', '6', '8', 27, 0
		defb 0, '+', '3', '-', '*', '9', 0, 0
		; E0 00h shift codes
		defb 0, 0, 0, 0, 0, 0, 0, 0
		defb 0, 0, 0, 0, 0, 0, 0, 0
		; E0 10h
		defb 0, 0, 0, 0, 0, 'Q', '!', 0
		defb 0, 0, 'Z', 'S', 'A', 'W', '"', 0
		; E0 20h
		defb 0, 'C', 'X';, 'D', 'E', '$', 0, 0
		defb 0, 0, 'V', 'F', 'T', 'R', '%', 0
		; E0 30h
		defb 0, 'N', 'B', 'H', 'G', 'Y', '^', 0
		defb 0, 0, 'M', 'J', 'U', '&', '*', 0
		; E0 40h
		defb 0, '<', 'K', 'T', 'O', ')', '(', 0
		defb 0, '>', '/', 'L', ':', 'P', '_', 0
		; E0 50h
		defb 0, 0, '@', 0, '{', '+', 0, 0
		defb 0, 0, 13, '}', 0, '~', 0
		; E0 60h
		defb 0, '|', 0, 0, 0, 0, 0, 0
		defb 0, 0, 0, 8, 31, 0, 0, 0
		; E0 70h
		defb 0, 127, 10, 0, 12, 11, 0, 0
		defb 0, 0, 0, 0, 0, 0, 0, 0


;
;	Read a character from the PS/2 port. This isn't the same as a byte
;	from the PS/2 port PS/2 codes can be several bytes long and may not
;	be meaningful. We may also already have a character we read when
;	the caller used ps2constat and we needed to check for one
;
ps2conin:
		ld a,(ps2pend)
		or a
		call z, ps2char
		jr z, ps2conin
		ld a,(ps2char)
		ret
ps2constat:
		ld a,(ps2pend)
		or a
		jr nz, retff
		call ps2char
		jr nz, retff
constfail:	xor a
		ret
retff:		ld a,255
		ret


;
;	Timeout long jump
;
;	The caller set up abort_sp earlier. We restore the stack pointer
;	return set HL to a timeout error, tell the keyboard to be quiet
;	and unwind.
;
timeout:
		exx
		ld hl,0fffdh
		ld sp, (abort_sp)
		ld a,(kbsave)
		ld bc, (kbport)
		out (c),a
		ret

;
;	Read a byte from the PS/2 keyboard
;
;	A = scratch throughout
;	C = port, B = loops to do for timeout
;	D = internal kbdbit helper E = code being assembled
;	HL = return
;
;	kbsave holds the audio bits and 05h for the low nibble
;	(that is clocks down, data floating)
;
ps2kbd_get:
		ld bc,(kbport)
kbget:
		ld (abort_sp),sp
		; Stop pulling down CLK so that the keyboard can talk
		ld a,(kbsave)
		or 3		; let clock rise, don't pull data
		out (c),a
		; Most keyboards respond within 150uS
kbwclock:
		in a,(c)
		and 4			; sample clock input
		jr z, kbdata
		djnz kbwclock
		; It didn't reply so there was no interest
		; Jam the clock again so that it can't send until we check
kbdone:
		ld hl,0ffffh
kbout:
		ld a,(kbsave)
		; B is now zero - make it non zero so we can use high ports with
		; Z180
		inc b
		or 2
		out (c),a		; put the clock back down, don't pull data
		ret

;
; We got a rising edge. That means the keyboard wishes to talk to
; us.
;
kbdata:
		ld d,0ffh	; trick so we can turn bit 2 into carry fast
		;
		; We got a clock edge, that means there is incoming data:
		; There should be a start, eight data and an odd parity
		;
		exx
		ld hl,0		; timeout timer - FIXME value ?
		exx
		ld b,8
		call kbdbit	; Start bit
nextbit:
		call kbdbit
		djnz nextbit
		; E now holds the data, carry should be the start bit
		;	jr nc, kbdbad
		ld a,e
		or a		; Generate parity flag
		ld h,080h	; For even parity of the 8bits send a 1 to get odd
		jp pe, kbdevenpar
		ld h,0		; If we are odd parity send a 0 so we stay odd
kbdevenpar:
		ld l,a		; Save the keycode
		inc b		; make sure b is non zero for Z180 ports
		call kbdbit
		ld a,e		; get parity bit into A
		and 080h	; mask other bits
		cp h
		ld h,0
		jr z, kbout	; parity was good
		ld hl,0fffeh	; Parity was bad
		jr kbout
kbdbad:
		inc b
		call kbdbit	; throw away parity
		; Check stop bits ??
		ld hl,0fffch		; report -err for wrong start
		jr kbout

;
;	Receive a bit. Wait for the clock to go low, sample the data and
;	then wait for it to return high. The sampled bit is added to E
;
kbdbit:
		exx
		dec hl
		ld a,h
		or l
		jr z,timeout
		exx
		in a,(c)
		bit 2,a
		jr nz, kbdbit
		; Falling clock edge, sample data is in bit 3
		and 8
		add d		; will set carry if 1
		rr e		; rotate into E
		; Wait for the rising edge
		; Preserve carry for this loop, our caller needs the carry
		; from the RL E
		push af
kbdbit2:
		exx
		dec hl
		ld a,h
		or l
		jp z,timeout
		exx
		in a,(c)
		bit 2,a
		jr z,kbdbit2
		; E now updated
		pop af
		ret

;
;	Send side. For an AT keyboard we also get to send it messages.
;
;	This code needs some longer timeout logic to abort if the keyboard
;	is unplugged or otherwise throws a fit
;
;	Send character L to the keyboard and return the result code back
;	where 0feh means 'failed'. Must not mix interrupt polling of
;	keyboard with calls here.
;
;
ps2kbd_put:
		ld bc,(kbport)
kbdput:
		ld (abort_sp),sp
		exx
		ld hl,0		; timeout timer - FIXME value ?
		exx
		ld a,(kbsave)
		and 0feh		; Pull clock low
		or 2			; Keep data floating
		out (c),a		; Clock low, data floating
		; 100uS delay		- actually right now the 125uS poll delay
clkwait:
		djnz clkwait
		ld a,(kbsave)
		ld b,8			; Ensure B is always non zero
		out (c),a		; Clock and data low
		and 0fch
		or 1		; Release clock
		out (c),a
		; No specific start bit needed ?
		ld d,l		; save character
kbdputl:
		call kbdoutbit
		djnz kbdputl
		; Check the parity bit to send
		ld a,d
		or a
		ld l,1
		jp pe,kbdoutp1
		dec l
kbdoutp1:
		inc b
		call kbdoutbit
		ld l,0ffh	; stop bits are 1s
		call kbdoutbit
		call kbdoutbit
		;
		; Wait 20uS
		;
		ld de,(kbdelay)
		ld b,d
del1:		djnz del1
		ld a,(kbsave)
		; force clock low, data floating
		out (c),a
		;
		; Wait 44uS
		;
		ld b,e
del2:		djnz del2
		;
		; Now we should get a reply
		;
		;
		; Raise clock and data
		;
		or 3
		inc b
		out (c),a
		; FIXME - need a general long timeout here
		; Wait for the keyboard to pull the clock low
waitk:
		in a,(c)
		and 4
		jr nz, waitk
		; Return the status code (FE = failed try again)
		jp kbdata

		;
		; Send a bit to the keyboard. The PS/2 keyboard provides the clock
		; so we wait for the clock, then send a bit, then wait for the other
		; clock edge.
		;
kbdoutbit:
		exx
		dec hl
		ld a,h
		or l
		jp z,timeout
		exx
		in a,(c)
		and 4
		jr nz, kbdoutbit	; wait for clock low
		ld a,(kbsave)		;
		or 1			; clock floating
		rr l
		jr nc, kbdouta
		or 2			; set data
kbdouta:
		out (c),a
kbdoutw1:
		exx
		dec hl
		ld a,h
		or l
		jp z,timeout
		exx
		in a,(c)
		and 4
		jr z,kbdoutw1		; wait for clock to go back high
		ret

;
;		TMS9918A Interface
;

tmsprobe:
		; Check for a TMS9918A next

		ld hl,tmsreset
		call tmsconfig
		ld hl,tmstext
		call tmsconfig
		ld bc,0
tmschk1:
		in a,(99h)
		rla
		jr c,tmshi
		dec bc
		ld a,b
		or c
		jr nz, tmschk1
		ret

tmshi:
		in a,(99h)	; We cleared the flag in the read before
		rla
		ret c

		xor a	; Set up the data pointers

		out (99h),a
		ld a,040h
		out (99h),a

		ld bc,4096
cleartms:
		ld a,' '
		out (98h),a
		ld a,b
		or c
		jr nz, cleartms

		ld hl,tmsfontdata
		xor a
		out (99h),a
		ld a,51h	; base for char 32
		out (99h),a
		ld bc,768
tmsfont:
		ld a,(hl)
		out (98h),a
		dec bc
		ld a,b
		or c
		jr nz, tmsfont

		ld hl,tmsfontdata
		xor a
		out (99h),a
		ld a,55h	; base for char 160
		out (99h),a
		ld bc,768
tmsifont:
		ld a,(hl)
		neg		; inverse video font
		out (98h),a
		dec bc
		ld a,b
		or c
		jr nz, tmsifont

		; Set up variables, show cursor
		ld hl,0
		ld (vdpxy),hl
		xor a
		ld (vdpsetxy),a
		call vdpshowc

		; Check for keyboard first

		call ps2probe
		ret z

		; We have a TMS9918A. It becomes console, and move con
		; port to aux
		ld hl,(confunc)
		ld (auxfunc),hl
		ld hl,tmsfunc
		ld (confunc),hl
		ld a,8
		ld (twidth),a	; default to 8 bytes hex dumps (40 cols)
		ret

tmsfunc:
		defw vdpconout
		defw ps2conin
		defw ps2constat
		defw ret255	; Always ready
tmstext:
		defb 000h	; M2:0 Ext: 0
		defb 0f0h	; 16K, not blanked, int on, M1:1 M3:0
		defb 000h	; Text at 0
		defb 000h	;
		defb 002h	; Paterns at 1000h
		defb 000h
		defb 000h
		defb 0f1h	; White on black
tmsreset:
		defb 000h
		defb 080h
		defb 000h
		defb 000h
		defb 000h
		defb 000h
		defb 000h
		defb 000h

tmsconfig:
		ld bc,099h
tmsconfl:
		ld a,(hl)
		out (c),a
		inc hl
		out (c),b
		inc b
		bit 3,b
		jr z,tmsconfl
		ret

vdppos:		; D = X E = Y B = 0 read 040h write, output HL = logical addr
		; preserves C
		ld a,e
		add a		; 0-24 Y x 8
		add a
		add a
		ld l,a		; then overflows to 16bits
		ld h,0
		push hl
		add hl,hl	; x16
		add hl,hl	; x32
		ld a,d		; save input
		pop de
		add hl,de	; x40
		ld e,a		; + x
		ld d,b		; merge R/W bit
		add hl,de
		ret

; Print C at DE
vdpout:		ld b,040h
		call vdppos
		ld a,c
		ld c,99h
		out (c),l
		out (c),h
		dec c
		out (c),a
		ret
; Scroll - horrid on a TMS9918A
vdpscroll:
		ld bc,1799h		; 23 line count, port 99h
		ld de,0040h		; second line
downline:	push bc
		ld b,40
		ld hl,scrollbuf
		out (c), e
		out (c), d
		dec c
		bit 0, (ix)		; kill 20 clocks
up_0:
		ini
		jp nz, up_0		; 26 clock loop
		ld hl, 03fd8h		; up 40 bytes in the low 12 bits
					; add 04000h for write mode
					; (we will carry one bit from bit
					; 11->12)
		add hl,de
		out (c), l
		out (c), h
		dec c
		ld hl, scrollbuf
		ld b,40
up_1
		outi
		jp nz, up_1		; 26 clock loop
		pop bc
		ld hl,40
		add hl,de		; down a line
		ex de,hl
		djnz downline
		; Now clear the bottom line
		ld de,0017h		; line 23 (bottom line)
		ld bc,04099h
		call vdppos		; FIXME hard code this result
		out (c),l
		out (c),h
		ld a,' '
		dec c
		ld b,40
wiper:		out (c), a
		nop
		djnz wiper
		ret

vdpwipe:
		ld hl,4000h		; Start of display, write
		ld c,99h
		ld de,960		; Chars
		out (c),l
		out (c),h
		ld a,' '
vdpwipe1:	out (c),a		; Can be optimized a bit
		dec de			; and stay within timing rules
		ld a,d
		or e
		jr nz, vdpwipe1
		ret

vdpost:
		ld a,255
		ret

;
;	ADM3A emulation
;
vdpconout:
		call vdphidec
		ld a,(vdpsetxy)
		or a
		jr z, normalchar
		cp 1
		jr nz, notbyte1
		ld a,'='
		cp c
		jr nz, badesc
vdpescnext:
		inc a
		ld (vdpsetxy),a
		jp vdpdone

notbyte1:	cp 2
		jr nz, notbyte2
		ld a,c
		sub 32
		jr c, badesc
		cp 24
		jr nc, badesc
		ld (vdpxy),a
		jr vdpescnext

notbyte2:	ld a,c
		sub 32
		jr c, badesc
		cp 40
		jr nc, badesc
		ld (vdpxy + 1),a
badesc:
		xor a
		ld (vdpsetxy),a
		jp vdpdone

normalchar:
		ld de,(vdpxy)		; get X,Y ready
		ld a,c
		jr nc, txtout
		cp 8
		jr nz, notbs
		xor a
		cp d
		jr z, vdpdone
		dec d
		jr notover
notbs:
		cp 10			; Line feed(cursor down)
		jr nz, notlf
lfandfs:
		ld a,24
		inc e
		cp e
		jr nz, notover
scrolldon
		call vdpscroll
		ld de,23		; Line 23, 0
		jr notover
notlf:
		cp 11
		jr nz, notup
		xor a
		cp e
		jr z, vdpdone
		dec e
		jr notover
notup:
		cp 12			; Forward space
		jr nz, notfs
		inc d
		ld a,40
		cp d
		jr nz, notover		; Fits
		; Move to next line, if need be also scroll
		ld d,0
		jr lfandfs		; Merge with line feed flow
notfs:
		cp 13
		jr nz, notret
		ld d,0
		jr notover
notret:
		; 14/15 lock and unlock keyboard- ignore
		cp 26
		jr nz, notclear

		call vdpwipe
		ld de,0
		jr notover

notclear:
		cp 27
		jr nz, notesc
		ld a,1
		ld (vdpsetxy),a
		jr vdpdone
notesc:
		cp 31
		jr nz, vdpdone		; Ignore
		ld de,0			; home
		jr notover
txtout:
		cp 127
		jr z, vdpdone		; del is ignored
		push de
		call vdpout
		pop de
		inc d
		ld a,40
		cp d
		jr nz, notover
		ld d,0
		inc e
		ld a,24
		cp e
		jr nz, notover
		call vdpscroll
		ld de,23		; Line 23, col 0
notover:	ld (vdpxy),de
vdpdone:
vdpshowc:	ld de,(vdpxy)
		ld (vdpcursor),de
		ld b,0
		call vdppos
		ld c,99h
		out (c),l
		out (c),h
		dec c
		bit 0,(ix)
		in a,(c)
		ld (vdpcursch),a
		xor 80h
		set 6,h			; Write
		out (c),l
		out (c),h
		dec c
		out (c),a
		ret
vdphidec:
		ld de,(vdpcursor)
		ld b,040h
		call vdppos
		ld c,99h
		out (c),l
		out (c),h
		dec c
		ld a,(vdpcursch)
		out (c),a
		ret


init_ram:
		; We may not have any writable RAM just yet
		; The cases are
		; RC2014 classic - RAM is high and writeable
		; SC108 - RAM high and writeable
		; SC114 - RAM high and writeable
		; 512K/512K - low 16K ROM mapped everywhere

		; On entry HL DE and A hold things we need


		ex af,af'		; save uart info in AF'
		ld ix,08000h
		ld a,(ix)
		inc (ix)
		cp (ix)
		jr nz, not_512512
		; Running with 512K/512K. This isn't really a useful config
		; as we have ROMWBW but it's handy for testing stuff
		xor a
		ld (078h),a
		ld a,021h
		out (079h),a
		inc a
		out (07ah),a
		inc a
		out (07bh),a
		ld a,01h
		out (07ch),a
		ld a,02h
		jr setsysbyte

		; This code is moved to RAM and run there, must stay
		; position independent.
		;
		; NZ - classic
		; Z -  if reg C != 0 then SC series else no paging
is_classic:
		xor a
		out (38h),a	; Only on the classic will this make
		ld hl,0		; low memory RAM
		ld a,1
	        ld (3),a	; Hack to fix iobyte bug on legacy CP/M 2.2
		ld a,(hl)
		inc (hl)
		cp (hl)		; Z set if RAM not writable
		ld a,0		; preserve flags
		out (38h),a	; Back to ROM (all cases)
		ret nz		; 0 = classic
		; Now double check it's not just broken
		inc a
		out (38h),a	; On the SC series RAM is now low
		ld a,(hl)
		inc (hl)
		sub (hl)
		ld c,a		; will be 0 for paging fail
		xor a
		out (38h),a	; ROM back in (all cases)
		ret		; Z - not a classic, check C

		; Back to code run from ROM
not_512512:
		; Three possibilities (unless we add Tom's SBC to the mix!)
		; (we don't support Grants original)
		;
		; RC2014 - ROM on/off toggles on 038h, only 64K RAM
		; SC108 - ROM on/off is 038h bit 0 RAM A16 is 038h bit 7
		; SC114 - ROM on/off is 038h bit 0 RAM A16 is 038h bit 0
		;
		; We should also check for non working, non-fitted paged
		; RAM as it seems a common problem.
		;
		; We do however know that RAM is present high in all these
		; cases already
		;
		exx
		ld hl,is_classic
		ld de,scrollbuf		; good a place as any
		ld bc,040h
		ldir
		call scrollbuf
		ld a,01h
		jr nz, exsetsysbyte	; Was a classic

		ld a,c			; Check if just a busted page setup
		or a

		ld a,255
		jr z, exsetsysbyte	; Fail (we can't just print here)

		; ROM didn't toggle out or page out on 38h bit 0, and it's
		; not a 512K system. This means it's either a broken paging
		; set up (usually user forgot the extra link) or it's a
		; non paging set up for BASIC. Either way not suppported


sc_series:
		; Ok 108 or 114 ?
		; We last wrote 00h so we are A16 low, ROM in
		ld a,80h
		out (38h),a
		; On the SC108 we just toggled A16, on the SC114 nothing
		ld hl, scrollbuf
		ld (hl),a
		xor a
		out (38h),a		; A16 again on the SC108
		ld (hl),a		; the two banks are now labelled
					; 00h and 80h
		ld a,80h
		out (38h),a		; A16 back high
		cp (hl)			; Was A16 toggling ?
		ld a,114
		jr nz, exsetsysbyte	; If no we are an SC114
		; SC108 - put the RAM back right
		xor a
		out (38h),a
		ld a,108
exsetsysbyte
		exx
setsysbyte:
		ld (sysbyte),a
		ld (confunc),hl
		ld (auxfunc),de

		inc a
		jr nz, has_paging

		rst 20h
		ascii "C2014 with no paging. Not supported"
		defb 13,10,0
		di
		halt

has_paging:
		; default to 16 byte wide monitor displaysa
		ld a,16
		ld (twidth),a

		call tmsprobe
		rst 20h
		ascii "C2014 8K Boot ROM v0.03"
		defb 13,10,13,10,0

		ld a,(sysbyte)
		cp 1
		jr nz,notclassic
		rst 20h
		ascii "RC2014 Classic"
		defb 0
		jr showuart
notclassic:
		cp 2
		jr nz,not512bank
		rst 20h
		ascii "RC2014 512K/512K Banked"
		defb 0
		jr showuart
not512bank:
		push af
		rst 20h
		ascii "Small Computer Central "
		defb 0
		pop af
		cp 108
		jr nz, is_sc114
		rst 20h
		ascii "SC108"
		defb 0
		jr showuart
is_sc114
		rst 20h
		ascii "SC114"
		defb 0
showuart:
		rst 20h
		ascii " detected."
		defb 13,10
		ascii "Console UART: "
		defb 0

		ex af,af'	; recover the uart info bits
		; Do it this way so if we probe all and do fancier stuff
		; we can switch to a chain of bit tests
		dec a
		jr nz, notacia
		rst 20h
		ascii "ACIA at 0xA0"
		defb 0
		jr diskprobe
notacia:	dec a
		jr nz, not16x50
		rst 20h
		ascii "16x50 at 0xA0"
		defb 0
		jr diskprobe
not16x50:
		rst 20h
		ascii "SIO at 0x80"
		defb 0


		; Now go figure out what disk interfaces are present
diskprobe:
		rst 20h
		defb 13,10,0
		;
		; Move the disk I/O helpers into place
		;
		ld hl,xfer_buf
		ld de,xfer_block
		ld bc,xfer_block_end - xfer_block
		ldir

		;
		; Patch the disk helpers
		;
		ld a,(sysbyte)
		cp 2
		jr nz, not512
		; Change the port to use
		ld a,078h
		ld (romout + 3),a
		ld (romin + 3),a
		; And the register value for ROM out (020h) - ROM in is
		; still 0
		ld a,020h
		ld (romout + 3),a
not512:
		;
		; Look for PPIDE
		;
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

		rst 20h
		ascii "PPIDE interface found at 0x20"
		defb 13,10,0

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

		rst 20h
		ascii "Trying CF interface at 0x10"
		defb 13,10,0

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

ide_wait_ready:
		ld de,2000h
ide_waitr:
		ld a,0fh
		call ide_readb
		bit 7,a
		jr nz, ide_waitr
		ld c,a
		and 041h
		cp 040h
		ld a,c		; so can check ERR bit
		ret z		; Z set C clear = ok
		rra
		ret c		; NZ, C set = error
		dec de
		ld a,d
		or e
		jr nz, ide_waitr
		inc a		; NZ, C clear = timeout
		ret

ide_wait_drq:
		ld de,2000h
ide_waitd:
		ld a,0fh
		call ide_readb
		bit 0,a
		jr nz,retz
		and 08h
		ret nz
		dec de
		ld a,d
		or e
		jr nz, ide_waitd
retz:		xor a
		ret

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
		cp 10h
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
		jp cf_xfer_r
		
ppide_readsec:
		ex de,hl
		ld a,08h	; Data Register
		out (022h),a	; Register

		ld b,0		; 256 words
		jp ppide_xfer_r

cf_writesec:
		ex de,hl
		ld bc,010h	; 256 bytes to 10h - twice
		jp cf_xfer_w

ppide_writesec:
		ex de,hl
		ld a,080h
		out (023h),a	; Turn the 82C55 data ports around
		ld a,08h	; Data Register
		out (022h),a	; Register

		ld b,0		; 256 words

		call ppide_xfer_w

		ld a,092h
		out(023h),a	; Turn the 82C55 back to reading
		ret
		
cf_readb:
		add 8
		ld c,a
		in a,(c)
		ret

ppide_readb:
		ld b,a
		out (022h),a
		or 040h		; READ
		out (022h),a
		in a,(020h)	; Data back
		ld c,a
		ld a,b
		out (022h),a	; READ back high
		ld a,c
		ret

;
;   Four volumes per disk laid out so that we hve 2^16 sectors per volume
;   in a way that requires no maths
;
;
;   Block addressed
;   00000000 0000000D TTTTTTTT SSSSSSSS
;
;
ide_setlba:
		ld a,(diskdev)
		cp 4			; C D are drive 0 E F drive 1
		ld e,0e0h
		jr c, disk0
		ld e,0f0h
disk0:
		ld d,0eh		; LBA 3/drive
		call ide_writeb_wr
		ret nz
		ld a,(diskdev)
		; sub 2			; floppies (doesn't affect and..)
		and 1			; 2 per disk
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
		call ide_writeb
		xor a			; Z = OK
		ret


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
		ld b,0		; So the caller knows if it worked
		ld a,c
		cp 6		; AB - floppies, CD - disk 0 EF - disk 1
		ret nc
		inc b		; worked
		ld (diskdev),a
		ret		; NC = error, C = ok
				; caller BIOS owns DPH to keep GENCPM happy

read:
		push ix
		ld ix,(diskfunc)
		ld a,(diskdev)
;		cp 2
;		jr c, floprd
		cp 6
		jr nc, failed
		call ide_setlba		; sets LBA, drive and count 1
		jr nz, failed
		ld de,0f20h		; READ
		call ide_writeb
		call ide_wait_drq
		jr z, failed		; No DRQ in time
		ld de,(diskdma)
		call ide_readsec
		call ide_wait_ready
		pop ix
		ld a,0
		ret z			; OK
		inc a
		ret			; Error
failed:
		pop ix
		ld a,1
		ret

write:
		push ix
		ld ix,(diskfunc)
		ld a,(diskdev)
;		cp 2
;		jr c, flopwr
		cp 6
		jr nc, failed
		call ide_setlba		; sets LBA, drive and count 1
		jr nz, failed
		ld de,0f30h		; WRITE
		call ide_writeb
		call ide_wait_drq
		jp z, failed
		ld de,(diskdma)
		call ide_writesec
		call ide_wait_ready
		pop ix
		ld a,0
		ret z
		inc a
		ret

sectran:
		ld h,b
		ld l,c
		ret

flush:
		cp 2
		jr c, noflush
		call ide_setlba		; LBA will be ignored but drive
					; will be right
		jr nz, failed
		ld de,0fe7h		; flush cache
		call ide_writeb_wr
		jr nz, failed
noflush:
		xor a			; it worked fine
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

;
;	Monitor helpers
;

;
;	Turn an input byte into a hex value 0-15. C set means invalid
;
hexchhl:
		ld a,(hl)
hexch:
		sub '0'
		ret c			; not valid
		cp 10
		ccf
		ret nc			; valid
		sub 7			; gap between 0-9 and A-F
		ret c			; in gap so bad
		cp 16			; check range
		ccf
		ret

;
;	Accumulate a hex number
;	Returns a number in DE and C counting the digits input
;
;	Uses A C DE HL, but callers save state for us
;
hexnum:
		ld c,0
		ld d,c
		ld e,c
skipspc:
		ld a,(hl)
		cp 32
		jr nz, nexnl
		inc hl
		jr skipspc
nexnl:
		call hexchhl
		ret c
		sla e
		rl d
		sla e
		rl d
		sla e
		rl d
		sla e
		rl d
		or e
		ld e,a
		inc c
		inc hl
		jr nexnl

;
;	Load up to 4 hex digits into BC, preserve A,DE, HL is input pointer
;	Set C on error. Allowed to trash HL, DE, BC on error
;
hexin:
		push af
		push de
		call hexnum
		ld a,c
		or a
		jr z,badhex
		cp 5
		jr nc, badhex
		ld c,e
		ld b,d
		pop de
		pop af
		or a
		ret
badhex:
		; Error path can eat HL
		rst 20h
		ascii "Bad hex"
		defb 0
		pop de
		pop af
		scf
		ret
;
;	Load a single hex pair into E, preserve A, BC, HL is input pointer
;
;	On an error we can trash BC DE HL and we use this fact to call
;	badhex and pop bc into de
;
hexin1:
		push af
		push bc
		call hexnum
		ld a,c
		or a
		jr z, badhex
		cp 3
		jr nc, badhex
		pop bc
		pop af
		or a
		ret

phexa:
		push af
		rra
		rra
		rra
		rra
		call phexc
		pop af
phexc:		and 15
		add 48
		cp '9'+1
		jr c,hdigit
		add 7
hdigit:		ld c,a
		jp conout

phexas:
		call phexa
		ld c,' '
		jp conout
;
;	Print an address and spacer. BC is the address
;	Preserve BC DE HL
;
hexout2addr:
		push hl
		push de
		push bc
		ld a,b
		call phexa
		pop bc
		ld a,c
		push bc
		call phexa
		rst 20h
		ascii " : "
		defb 0
		pop bc
		pop de
		pop hl
		ret
;
;	Read a line of input.

input:
		ld c,0
		ld hl,inbuf
inputloop:
		rst 10h			; conin
		cp 10
		jr z, inputnl
		cp 13
		jr z, inputnl
		cp 8
		jr z, inputdel
		cp 127
		jr z, inputdel
		jr nc, inputloop
		cp 32
		jr c, inputloop
		bit 5,c			; end of buffer ?
		jr nz, inputloop
		cp 'a'
		jr c, notlc
		cp 'z'+1
		jr nc, notlc
		and 223			; turn upper case
notlc:		ld (hl),a
		rst 8			; echo the typing
		inc hl
		inc c
		jr inputloop
inputdel:
		ld a,c
		or a
		jr z,inputloop
		rst 20h
		defb 8, 32, 8, 0
		dec c
		dec hl
		jr inputloop
inputnl:
		ld (hl),0
		rst 20h
		defb 13,10,0
		ret
;
;
;	Monitor
;
now_boot:
		ld hl,functions
		ld de,0ff00h
		ld bc,0080h
		ldir

monitornr:
		ld hl, monitor
		ld (repeat),hl
monitor:
		push bc			; for repeats
		push de
		rst 20h
		defb 13,10
		ascii "---*"
		defb 0
		call input
		pop de
		pop bc
		ld hl, inbuf
		ld a,(hl)
		inc hl
		or a
		jr z, repeatcmd
		cp 'B'
		jp z, boot
		cp 'G'
		jr z, goto
		cp 'I'
		jr z, inport
		cp 'O'
		jr z, outport
		cp 'R'
		jr z, dumpmem
		cp 'W'
		jr z, setmem
		cp 'X'
		jp z, xmodem
badcmd:
		ld a,'?'
		rst 08h
		jr monitor
repeatcmd:
		ld hl,(repeat)
		jp (hl)
goto:
		call hexin		; preserves A, sets BC
		jr c, badcmd
		ld h,b
		ld l,c
		call jphl
		jr monitornr

jpix:		byte 0ddh
jphl:		jp (hl)

inport:
		call hexin		; preserves A, sets BC
		jr c, badcmd
		ld hl,inport_r
		ld (repeat),hl
inport_r:
		call hexout2addr
		in a,(c)
		call phexa
		jr monitornr

outport:
		call hexin		; preserves A, sets BC
		jr c, badcmd
		call hexin1		; into E
		jr c, badcmd
		out (c),e
		jr monitornr

dumpmem:
		call hexin		; preserves A, sets BC
		jr c, badcmd
dumpmem_r:
		ld a,(twidth)
		ld e,a
		ld hl, dumpmem_r
		ld (repeat),hl
		call hexout2addr	; print "BC : "
dumpl:
		ld a,(bc)
		push bc
		push de
		call phexas		; print "A "
		pop de
		pop bc
		inc bc
		dec e
		jr nz, dumpl
		jp monitor
setmem:
		call hexin
		jr c, badcmd
		call hexin1
		jr c, badcmd
		ld a,e
		ld (bc),a
		jp monitornr

baddisk:
		rst 20h
		ascii "Bad disk"
		defb 0
		jr badcmd

boot:
		ld a,(hl)
		or a
		jr nz, notbootdef
		ld a,'C'
notbootdef:
		inc hl
		cp ' '
		jr z, boot
		sub 'A'
		jr c, baddisk
		ld (bootdev),a

		ld hl,07e00h		; so we start at 8000h
		ld (addr),hl

		ld c,a
		call seldsk
		ld a,h
		or l
		jr z, baddisk

		ld bc,0
		call settrk

		ld bc,-1		; will wrap this before we use it
		call setsec

		ld b,018h		; 24 sectors so that if we booted
					; a legacy Searle CP/M we can
					; save the universe.

load_loop:
		push bc

		ld bc,(disksec)		; start of boot block
		inc bc
		call setsec

		ld bc,(addr)
		inc b
		inc b
		ld (addr),bc
		call setdma

		call read

		or a
		jr nz, read_fail

		pop bc
		djnz load_loop

		; CPMLDR always start with a JP and we can make any other
		; loader do the same
		; The Searle legacy CP/M will follow that by another JP
		; and then 127,0, "Copyright" so we can spot a raw CP/M 2.2
		; for RC2014

		ld a,(08000h)
		cp 0c3h
		jr nz, notsearle
		ld a,(08006h)
		cp 127
		jr nz, notsearle
		ld a,(08007h)
		or a

		; Did we in fact load a legacy Grant Searle style CP/M 2.2
		; in which case we definitely don't want to jump to 8100h!

		; The Searle loader loads 24 sectors at 0d000h and expects
		; to jump through fffe

		jr nz, notsearle

		; Always using port A for now
		ld hl, 08000h
		ld de, 0d000h
		ld bc, 03000h
		ldir
		ld sp, 08100h		; so we don't trash anything
		jp 0e600h		; skip the broken iobyte setup

notsearle:
		; We loaded sector 0 which we didn't need at 08000-81ff
		; Pass interesting data to the loader
		ld a,(08200h)
		cp 031h
		jr nz, notbootable
		ld hl,8200h
		ld de,(sysbyte)
		ld bc,VERSION
		jp 08200h		; into CPMLDR or whatever

notbootable:
		rst 20h
		ascii "Not bootable"
		defb 0
		jp monitornr

read_fail:
		rst 20h
		ascii "Disk error"
		defb 0
		jp monitornr

;
;	XMODEM helper
;



xmodem:
		call hexin
		jp c,badcmd
		ld h,b
		ld l,c
		rst 20h
		ascii "Transfer begins..."
		defb 13,10,0

		ld de,XMTIMER	; nak/timeout counter
		ld c,1		; expected packet

		;
		; Xmodem load into (HL)
		;
		; HL = pointer
		; DE = timeout counter
		; C = block
		; B is scratch
		;
xmnext:
		call xmhead
		;  Timed out waiting for valid header
		jr c, xmtimeout
		; Got an EOT
		jr z, xmdone

		; We got a header in time but is it valid. Caller did SOH
		; and inverse check. Returned block id is in A

		cp c
		jr z, validframe
		dec a
		cp c
		jr nz, xmnext

		; We got an old frame
		push hl
		ld hl, 0		; ROM (discard)
		call xmdata
sendack:
		ld a,ACK
		rst 8			; Send an ACK to force it to move on
		pop hl			; Get data pointer back
		jr xmnext
validframe:
		push hl
		call xmdata
		jr c, xmnext		; data timeout, go back to look for
					; headers
		jr z,newack		; hey its the right one!
		; Wrong checksum
		pop hl			; recover data pointer
		dec c			; Undo advance of a block
		ld a,NAK
		rst 8
		jr xmnext
newack:
		inc c
		inc sp
		inc sp			; discard old saved data pointer
		ld a,ACK
		rst 8
		ld de, XMTIMER
		jr xmnext

xmtimeout:
		rst 20h
		byte 13,10,13,10
		ascii "*** Timeout"
		byte 0
xmdone:
		jp monitornr

xmdata:
		ld b,128
		ld c,0
xmdl:
		call chint
		ret c
		ld (hl),a
		inc hl
		add c
		ld c,a
		djnz xmdl
		rst 10h
		sub c
		ret
xmhead:
		call chint
		ret c
		; Special case - an EOT as first thing after a block
		cp EOT
		ret z
		cp SOH
		jr z, xmhead2
xmheadl:	call chint
		ret c
		cp SOH
		jr nz, xmheadl
xmhead2:	call chint
		ret c
		ld b,a			; block
		call chint		; inverse block
		ret c
		add b			; 255 if valid
		inc a
		jr nz, xmheadl		; Not a valid header
		; Header is good - return block id in A
		ld a,b
		ret

chint:		; Read a character with timeouts
		dec de
		ld a,d
		or e
		scf
		ret z
		push bc
		ld b,8		; Inner delay counting loop so we penalize
chintl:				; noise characters more than waiting
		rst 18h
		or a
		jr nz, chintgot
		djnz chintl
		jr chint
chintgot:
		pop bc
		; Read the byte
		rst 10h
		or a		; Clear C
		ret

		; We will add more CP/M alike helpers as we go

; Stuff to do or irrelevant

devini:		; not yet implemented
drvtbl:		; has to be in the BIOS for GENCPM to work
time:		; not yet implemented
selmem:		; not used for unbanked
setbnk:
xmove:
userf:		; for extensions
unused:
		ret

;
;	Moved to ff00 with BIOS work stack above it. May be able to tighten
;	this a bit
;
functions:
		jp unused		; may want to add a BIOS wboot hook ?
		jp const
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
		jp auxost
		jp sectran
		jp conost
		jp auxist
		jp auxost
		jp devtbl
		jp devini
		jp drvtbl
		jp multio
		jp flush
		jp move
		jp time
		jp selmem
		jp setbnk
		jp xmove
		jp userf


tmsfontdata:
		defb 000h,000h,000h,000h,000h,000h,000h,000h
		defb 010h,010h,010h,010h,000h,000h,010h,000h
		defb 028h,028h,028h,000h,000h,000h,000h,000h
		defb 028h,028h,07Ch,028h,07Ch,028h,028h,000h
		defb 010h,03Ch,050h,038h,014h,078h,010h,000h
		defb 060h,064h,008h,010h,020h,04Ch,00Ch,000h
		defb 030h,048h,050h,020h,054h,048h,034h,000h
		defb 030h,010h,020h,000h,000h,000h,000h,000h
		defb 008h,010h,020h,020h,020h,010h,008h,000h
		defb 020h,010h,008h,008h,008h,010h,020h,000h
		defb 000h,010h,054h,038h,054h,010h,000h,000h
		defb 000h,010h,010h,07Ch,010h,010h,000h,000h
		defb 000h,000h,000h,000h,030h,010h,020h,000h
		defb 000h,000h,000h,07Ch,000h,000h,000h,000h
		defb 000h,000h,000h,000h,000h,030h,030h,000h
		defb 000h,004h,008h,010h,020h,040h,000h,000h
		defb 038h,044h,04Ch,054h,064h,044h,038h,000h
		defb 010h,030h,010h,010h,010h,010h,038h,000h
		defb 038h,044h,004h,008h,010h,020h,07Ch,000h
		defb 07Ch,008h,010h,008h,004h,044h,038h,000h
		defb 008h,018h,028h,048h,07Ch,008h,008h,000h
		defb 07Ch,040h,040h,078h,004h,044h,038h,000h
		defb 018h,020h,040h,078h,044h,044h,038h,000h
		defb 07Ch,004h,008h,010h,020h,020h,020h,000h
		defb 038h,044h,044h,038h,044h,044h,038h,000h
		defb 038h,044h,044h,03Ch,004h,008h,030h,000h
		defb 000h,030h,030h,000h,030h,030h,000h,000h
		defb 000h,030h,030h,000h,030h,010h,020h,000h
		defb 008h,010h,020h,040h,020h,010h,008h,000h
		defb 000h,000h,07Ch,000h,07Ch,000h,000h,000h
		defb 040h,020h,010h,008h,010h,020h,040h,000h
		defb 038h,044h,004h,008h,010h,000h,010h,000h
		defb 038h,044h,004h,034h,054h,054h,038h,000h
		defb 038h,044h,044h,044h,07Ch,044h,044h,000h
		defb 078h,044h,044h,078h,044h,044h,078h,000h
		defb 038h,044h,040h,040h,040h,044h,038h,000h
		defb 070h,048h,044h,044h,044h,048h,070h,000h
		defb 07Ch,040h,040h,078h,040h,040h,07Ch,000h
		defb 07Ch,040h,040h,078h,040h,040h,040h,000h
		defb 038h,044h,040h,05Ch,044h,044h,03Ch,000h
		defb 044h,044h,044h,07Ch,044h,044h,044h,000h
		defb 038h,010h,010h,010h,010h,010h,038h,000h
		defb 01Ch,008h,008h,008h,008h,048h,030h,000h
		defb 044h,048h,050h,060h,050h,048h,044h,000h
		defb 040h,040h,040h,040h,040h,040h,07Ch,000h
		defb 044h,06Ch,054h,054h,044h,044h,044h,000h
		defb 044h,044h,064h,054h,04Ch,044h,044h,000h
		defb 038h,044h,044h,044h,044h,044h,038h,000h
		defb 078h,044h,044h,078h,040h,040h,040h,000h
		defb 038h,044h,044h,044h,054h,048h,034h,000h
		defb 078h,044h,044h,078h,050h,048h,044h,000h
		defb 03Ch,040h,040h,038h,004h,004h,078h,000h
		defb 07Ch,010h,010h,010h,010h,010h,010h,000h
		defb 044h,044h,044h,044h,044h,044h,038h,000h
		defb 044h,044h,044h,044h,044h,028h,010h,000h
		defb 044h,044h,044h,054h,054h,054h,028h,000h
		defb 044h,044h,028h,010h,028h,044h,044h,000h
		defb 044h,044h,044h,028h,010h,010h,010h,000h
		defb 07Ch,004h,008h,010h,020h,040h,07Ch,000h
		defb 038h,020h,020h,020h,020h,020h,038h,000h
		defb 000h,040h,020h,010h,008h,004h,000h,000h
		defb 038h,008h,008h,008h,008h,008h,038h,000h
		defb 010h,028h,044h,000h,000h,000h,000h,000h
		defb 000h,000h,000h,000h,000h,000h,07Ch,000h
		defb 020h,010h,008h,000h,000h,000h,000h,000h
		defb 000h,000h,038h,004h,03Ch,044h,03Ch,000h
		defb 040h,040h,058h,064h,044h,044h,078h,000h
		defb 000h,000h,038h,040h,040h,044h,038h,000h
		defb 004h,004h,034h,04Ch,044h,044h,03Ch,000h
		defb 000h,000h,038h,044h,07Ch,040h,038h,000h
		defb 018h,024h,020h,070h,020h,020h,020h,000h
		defb 000h,000h,03Ch,044h,044h,03Ch,004h,038h
		defb 040h,040h,058h,064h,044h,044h,044h,000h
		defb 010h,000h,030h,010h,010h,010h,038h,000h
		defb 008h,000h,018h,008h,008h,048h,030h,000h
		defb 020h,020h,024h,028h,030h,028h,024h,000h
		defb 030h,010h,010h,010h,010h,010h,038h,000h
		defb 000h,000h,068h,054h,054h,044h,044h,000h
		defb 000h,000h,078h,044h,044h,044h,044h,000h
		defb 000h,000h,038h,044h,044h,044h,038h,000h
		defb 000h,000h,078h,044h,044h,078h,040h,040h
		defb 000h,000h,034h,04Ch,044h,03Ch,004h,004h
		defb 000h,000h,058h,064h,040h,040h,040h,000h
		defb 000h,000h,038h,040h,038h,004h,078h,000h
		defb 020h,020h,070h,020h,020h,024h,018h,000h
		defb 000h,000h,044h,044h,044h,04Ch,034h,000h
		defb 000h,000h,044h,044h,044h,028h,010h,000h
		defb 000h,000h,044h,044h,044h,054h,028h,000h
		defb 000h,000h,044h,028h,010h,028h,044h,000h
		defb 000h,000h,044h,044h,03Ch,004h,038h,000h
		defb 000h,000h,07Ch,008h,010h,020h,07Ch,000h
		defb 008h,010h,010h,020h,010h,010h,008h,000h
		defb 010h,010h,010h,010h,010h,010h,010h,000h
		defb 020h,010h,010h,008h,010h,010h,020h,000h
		defb 000h,000h,020h,054h,008h,000h,000h,000h
		defb 000h,000h,000h,000h,000h,000h,000h,000h

		; We fix these up in the build script.
xfer_buf:
		ds xfer_block_end - xfer_block


rom_end:
;
;	ROM variables
;

		org 0fe00h

;
;	Block transfer routines. Having a tiny number of routines in
;	high memory is smaller and faster than bounce buffers. These are
;	stashed in ROM by the build script.

xfer_block:
		; Function pointers
		jmp romin
		jmp romout
		jmp romcall


;	These must be high as they bank flip. We also want them high
;	as we patch them (see the 512/512K set up code)
romout:
		ld a,1
		out (038h),a
		ret
romin:
		ld a,0
		out (038h),a
		ret

;
;	Call function in IX in ROM. Does stack switches and all the needed
;	work. Preserves all registers into and out of the call. Not
;	re-entrant
;
romcall:
		ld (tmpsp),sp
		ld (tmpa),a
		ld sp,0
		call romin
		ld a,(tmpa)
		call jpix
		ld (tmpa),a
		call romout
		ld sp,(tmpsp)
		ld a,(tmpa)
		ret

ppide_xfer_r:
		call romout
ppide_readloop:
		ld a,048h	; Data Register | RD
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
		jr romin

ppide_xfer_w:
		call romout
ppide_writeloop:
		ld a,(hl)
		out (020h),a	; Data
		inc hl
		ld a,(hl)
		out (021h),a	; Data
		inc hl
		ld a,028h	; Data Register | WR
		out (022h),a	;
		ld a,08h
		out (022h),a	; WR goes back high
		djnz ppide_writeloop
		jr romin

cf_xfer_r:
		call romout
		inir
		inir
		jr romin

cf_xfer_w:
		call romout
		otir
		otir
		jr romin
xfer_block_end:

sysbyte:	db 0
bootdev:	db 0
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
vdpxy:		dw 0
vdpcursor:	dw 0
vdpsetxy:	db 0
vdpcursch	db 0
scrollbuf:	ds 40
kbport:		dw 0
kbsave:		db 0
kbdelay:	dw 0
keyshifted:	db 0
keyup:		db 0
keybreak:	db 0
shift_down:	dw 0
ps2char:	db 0
ps2pend:	db 0
abort_sp:	dw 0
repeat:		dw 0
inbuf:		ds 33		; including \0
twidth:		db 0		; number of bytes for dump (not true width)

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
