	use16

	org 0

; So it doesn'tmply DS (ick)

bootstrap equ sysinit

;
;	A very very primitive BIOS for the 80C188 card
;
sysinit:
	cli
	cld

	; Debug LEDs
	mov al,0xff
	out 0x80,al

	; Init the serial port
	mov al,0xC3
	out 0xC0,al

	mov al,0x01
	out 0xC0,al

	xor al,al
	out 0xC1,al

	mov al,0x03
	out 0xC3,al

	dec al
	out 0xC4,al

	mov al,0x87
	out 0xC2,al

	; Print the initial R
	mov al,'R'
	out 0xC0,al

	; Now figure out some RAM and stacks in the low 64K
	; It's initially convenient to have DS pointing into ROM and
	; use ES for actual BIOS RAM.
	mov ax,cs
	mov ds,ax	
	xor ax,ax
	mov es,ax
	mov ss,ax
	mov sp,0x3ff

	; Time to say hello

	mov si,hello
	call pstring

	; Ok so the user has some reason to believe that we live and that
	; RAM actually works. Move on an LED state

	mov dx,0x80
	mov al,0xfe
	out dx,al

	;
	; Start setting up an x86 bios environment
	;
	
	; All vectors to spurious
	mov di, 0
	mov cx, 256
write_vec_1:
	mov ax, spurious
	stosw
	mov ax, cs
	stosw
	loop write_vec_1

	; Now fill in those with meaning (the segment is already correct)

	mov si, vectors
	mov di, 40		; Int 10
	mov cx, 15
write_vec_2:
	lodsw
	stosw
	inc di
	inc di
	loop write_vec_2

	; FIXME: int5 .. weird one ?

	; At this point we should probably scan for option ROM images
	; in the upper 512K, but that can wait

	mov al,0xfc
	out 0x80,al

	;
	; TODO: set up the bios memory space - device flag, lomem etc
	;

	; We have a configured serial port, we've set up the vectors
	; now start on the CF adapter

	; FIXME: delay if needed before probing

	; Fixme: do AA / 55 probing

	; LBA mode on
	mov al,0xe8
	out 0x16,al
	call waitready
	; FIXME: timeouts and errors

	; CF 8bit mode
	mov al,1
	out 0x11,al
	mov al,0xef
	out 0x17,al
	call waitready
	; FIXME timeouts and errors

	; We are now good to go (I think)

	int 0x19		; boot interrupt (done this way so ROMs can
				; hook it)

	; Oh dear...
	int 0x18

;
;	Our "PC" interrupt handlers for the BIOS. Mostly pretty braindead
;	as our environment is very controlled at this point
;	

spurious:
	iret

;
;	Video (except we are serial)
;
int10:
	cmp ah,16
	jae badint10
	pushf
	sti
	cld
	push si
	xor si,si
	mov ds,si
	mov es,si
	mov si,ax
	shr si,8
	shl si,1	; Can't just do by 7 as we might have a 1 left
	jmp [cs:vidvec]
vidvec:
	dw v_set_mode	; set mode
	dw v_cursor
	dw v_set_cursor
	dw v_get_cursor
	dw v_get_pen
	dw v_set_page
	dw v_scroll_up
	dw v_scroll_down
	dw v_read_attr
	dw v_write_attr
	dw v_write_char
	dw v_set_palette
	dw v_write_pixel
	dw v_read_pixel
	dw v_write_string
	dw v_status

;
;	Whatever - we don't really care too much to be honest
;
v_set_mode:
v_cursor:
v_set_cursor:
v_get_cursor:
v_get_pen:
v_set_page:
v_scroll_up:
v_scroll_down:
v_read_attr:
v_write_attr:
v_set_palette:
v_write_pixel:
v_read_pixel:
v_status:
v_done:
	pop si
	popf
just_iret:
	iret
badint10:
	stc
	retf 2
;
;	Teletype style write, the only thing we really give a damn about
;
v_write_char:
	call pchar
	loop v_write_char
	jmp v_done
v_write_string:
	call pchar
	jmp v_done

;
;	Platform features
;
int11:
	push ds
	mov ax,0x40
	mov ds,ax
	mov ax,[0x10]	; equipment word (value 0x0030)
	pop ds
	iret

; We always have 512K
; However we return 40:13h in case someone stole any
int12:
	push ds
	mov ax,0x40
	mov ds,ax
	mov ax,[0x13]
	pop ds
	iret

; int13 Disk I/O - nasty complicated pile of historic hackjobs
;
; We implement as follows
;
;	00	report CF clear 'whatever'
;	01 	if DL = 0x80 report status/cf else FF error
;	02	Implemented for CF
;	03	Implemented for CF
;	04	CF always reports OK
;	05	Always error
;	06	Always error
;	07	Always error
;	08	Reports CF only - need to decide on a fake LBA geometry
;	09	Review
;	0A	Not supported
;	0B	Not supported
;	0C	Mapped to fake LBA geometry
;	0D	No op except for resetting geometry
;	0E	Always error
;	0F	Always error
;	10	Reports yes for CF
;	11	Seeks to 0
;	12	Always error
;	13	Always error
;	14	Always error
;	15	Reports drives and fake size
;	16	Always error
;	17	Always error
;	18	Not supported
;	19	No op
;	
;	And we really need to support EDD 3.0 eventually
;
int13:
	stc
	retf 2

; int14 Serial - ie the console 8)

int14:	
	; For now
	stc
	retf 2

; int15 is PC-AT crap so pretend we don't know what it's talking about
int15:
	stc
	retf 2

; int16 - keyboard
int16:
	cmp ah,0
	jne int16_1
	; We don't implement polling hooks etc
waitch:
	in al,0xc5
	and al,1
	jz waitch
	in al,0xc0
	iret
int16_1:
	cmp ah,1
	jne int16_2
	in al,0xC5
	and al,1
	jz int16_retc		; iret with Z
	xor ah,ah
	in al,0xC0
	or al,al		; force Z off for any valid char
				; FIXME sort out ch 0 just in case
int16_retc:
	stc
	retf 2 
int16_2:
	cmp ah,2
	jne int16_3
	xor al,al
	iret
int16_3:
	stc
	retf 2

; int17 - the printer	
int17:
	stc
	retf 2

int18:
	mov si, nobasic		; Why not be traditional 8)
	call pstring
	cli			; for now act dead
	hlt

int19:
	; Boot. We only know a very simple boot model - the CF adapter
	; TODO
	iret

; int1a - time
int1a:
	stc
	retf 2

; BIOS hooks

; Keyboard ctrl-break - could xlate to break key call I guess ?
int1b:
	iret

; We need to call this on ticks
int1c:
	iret

	
;
;	Useful subroutines
;
pchar:
	mov ah,al
pchar_wait:
	in al,0xC5
	and al,0x20
	jz pchar_wait
	mov al,ah
	out 0xC0,al
return:
	ret

pstring:
	lodsb
	or al,al
	jz return
	call pchar
	jmp pstring

rchar:
	in al,0xC5
	and al,0x01
	jz rchar
	in al,0xC0
	ret

;
;	Strings in cs
;
hello:
	db 'C2014/80C188 v0.1'
	db 13,10,0
nobasic:
	db 'NO ROM BASIC'
	db 13,10,0

;
;	Copied into the interrupt vector table
;
vectors:
	dw	int10
	dw	int11
	dw	int12
	dw	int13
	dw	int14
	dw	int15
	dw	int16
	dw	int17
	dw	int18
	dw	int19
	dw	int1a
	dw	int1b
	dw	int1c
	dw	videoparam
	dw	fdtab


;
;	Top 16 bytes of image
;
	jmp	0xf000:bootstrap	; sysinit
	dw	0
	db	"00/00/00"
	db	0xff
	db	0xff		; Don't identify a platform type
	db	0x00		; checksum
