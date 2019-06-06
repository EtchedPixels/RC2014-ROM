.sect .text
.sect .rom
.sect .data
.sect .bss

.sect .text

!
!	Mini boot ROM for 512K ROM/RAM card and 8085 CPU
!
!	Load a boot block from IDE and run it
!

start:
	di
	! Set up the 16550A
	mvi a,0x80		! DLAB on
	out 0xC3
	mvi a,0x01		! 115200 baud
	out 0xC0
	xra a
	out 0xC1
	mvi a,0x03		! DLAB off, 8N1
	out 0xC3
	dcr a			! 2 - RTS on
	out 0xC4
	mvi a,0x87		! FIFO on, reset FIFO
	out 0xC2

	mvi a,'R'		! Display something
	out 0xC0

	! Turn off the fake M1 generation
	mvi a,0xC0
	sim
	! Identity map ROM in low 32K 
	xra a
	out 0x78
	inr a
	out 0x79
	! RAM on (leaving 32/33 free so we can linear map nicely)
	mvi a,34
	out 0x7A
	inr a
	out 0x7B
	mvi a,1
	out 0x7C		! Enable memory mapper
	lxi sp, 0xC000		! Point SP into RAM
	!
	!	As early as possible display something
	!
	lxi h,signon
	lxi sp,0
	call print

	lxi b,0x2020	! 32 pages from 32 are RAM

scan_next:
	mov a,b
	out 0x7B	! Switch C000-FFFF

	! Don't use stack in this, we might be scanning our own stack page
	lxi h,0xC000
scan_page:
	mvi a,0xAA
	mov m,a
	cmp m
	jnz badpage
	mvi a,0x55
	mov m,a
	cmp m
	jnz badpage

	inx h
	xra a
	cmp h
	jnz scan_page

	mvi a,35	! Correct top page
	out 0x7B

	mvi a,'.'

scanon:
	call pchar
	
	inr b
	dcr c
	jnz scan_next	

	lxi h,newline
	call print

	!
	!	Select the disk
	!
	mvi a,0xe0
	out 0x16 ! head & dev,a
	call waitready

	!
	!	Let the user know
	!
	lxi h,loading
	call print

	mvi a,1
	out 0x11 	! feature
	mvi a,0xEF	! Set features - 8bit mode
	out 0x17 	! command
	call waitready
	mvi a,'8'
	call pchar
	mvi a,0x55
	out 0x13
	in 0x13
	cpi 0x55
	jnz no_media
	mvi a,0xAA
	out 0x13
	in 0x13
	cpi 0xAA
	jnz no_media
	xra a
	out 0x13	! LBA 0-2
	out 0x14
	out 0x15
	! We set LBA3 to E0 already
	inr a
	out 0x12	! Count
	mvi a,0x20	! Read Sector
	out 0x17 	! command
	nop
	lxi h,0xFE00	! buffer target
	call waitdrq
	mvi a,'<'
	call pchar
	mvi b,0
sector:
	in 0x10 	! Data
	mov m,a
	inx h
	in 0x10
	mov m,a
	inx h
	dcr b
	jnz sector
	mvi a,'>'
	call pchar
	call waitready
	lda 0xFE00
	cpi 0x85
	jnz badload
	lda 0xFE01
	cpi 0x80
	jnz badload
	call pspace
	jmp 0xFE02
badload:
	lxi h,badboot
	call print
	hlt
no_media:
	call phex
	lxi h,nomedia
	call print
	hlt

badpage:
	mvi a,35	! Correct top page
	out 0x7B

	mvi a,'X'
	jmp scanon

waitdrq:
	in 0x17		! Status
	push psw
	call phex
	pop psw
	ani 0x08	! DRQ
	jz waitdrq
	ret

waitready:
	in 0x17
	ani 0x40
	jz waitready
	ret

print:
	in 0xC5
	ani 0x20
	jz print
	mov a,m
	ora a
	rz
	out 0xC0
	inx h
	jmp print
pspace:
	mvi a,32
pchar:
	push psw
pcharw:
	in 0xC5
	ani 0x20
	jz pcharw
	pop psw
	out 0xC0
	ret
phex:
	push psw
	rar
	rar
	rar
	rar
	call phexdigit
	pop psw
phexdigit:
	ani 0x0f
	cpi 10
	jc noadd
	adi 7
noadd:	adi 48
	jmp pchar

.sect .rom
signon:
	.ascii "C2014/85 ROM BIOS 0.1"
newline:
	.data1 13,10,0
loading:
	.asciz "Loading ..."
badboot:
	.ascii "Not a valid boot block"
	.data1 13,10,0
nomedia:
	.ascii "CF card not present"
	.data1 13,10,0
