.sect .text
.sect .rom
.sect .data
.sect .bss

.sect .text

!
!	Mini boot ROM for 8085/MMU card and flat 512K/512K ROM and RAM
!
!	Load a boot block from IDE and run it
!

start:
	!
	!	We are entered with all the MMU registers as zero so we
	!	have 64K of ROM mapped
	!
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

	!
	!	Put some RAM in the common space
	!
	mvi a,0x01		! ROM 0 low RAM 0 high
	out 0xFF
	lxi sp, 0xFE00		! Point SP into RAM (just under boot block)
	!
	!	As early as possible display something
	!
	lxi h,signon
	call print

	!
	!	RAM test
	!
	lxi h,0xFE00
	lxi d,banktab
	lxi b,0x55AA
ramnext:
	ldax d
	ora a
	jz  scandone
	out 0xFF		! Switch memory in top 8K

	mov m,c
	mov a,m
	cmp c
	jnz notpresent
	mov m,b
	mov a,m
	cmp b
	jnz notpresent
	mvi a,0x01
	out 0xFF		! Put our stack back
	mvi a,'X'
pnext:
	call pchar
	inx d
	jmp ramnext
notpresent:
	mvi a,0x01
	out 0xFF
	mvi a,'-'
	jmp pnext

banktab:
	.data1 0x01		! Bank 0 high
	.data1 0x41		! Bank 1 high
	.data1 0x11		! Bank 2 high
	.data1 0x51		! Bank 3 high
	.data1 0x05		! Bank 4 high
	.data1 0x45		! Bank 5 high
	.data1 0x15		! Bank 6 high
	.data1 0x55		! Bank 7 high
	.data1 0

scandone:
	lxi h,newline
	call print

	!
	!	Select the disk
	!
	mvi a,0xe0
	out 0x16 	! head & dev,a
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
	mvi a,'1'
	call pchar
	mvi a,0x55
	out 0x13
	in 0x13
	cpi 0x55
	jnz no_media
	mvi a,'2'
	call pchar
	mvi a,0xAA
	out 0x13
	in 0x13
	cpi 0xAA
	jnz no_media
	mvi a,'3'
	call pchar
	xra a
	out 0x13	! LBA 0-2
	out 0x14
	out 0x15
	! We set LBA3 to E0 already
	inr a
	out 0x12	! Count
	mvi a,'4'
	call pchar
	mvi a,0x20	! Read Sector
	out 0x17 	! command
	nop
	lxi h,0xFE00	! buffer target
	mvi a,'W'
	call pchar
	call waitdrq
	mvi a,'w'
	call pchar
	mvi b,0
sector:
	in 0x10 	! Data
	mov m,a
	inx h
	in 0x10
	mov m,a
	inx h
	mvi a,'.'
	call pchar
	dcr b
	jnz sector
	call waitready
	lda 0xFE00
	cpi 0x85
	jnz badcode
	lda 0xFE01
	cpi 0x80
	jnz badcode
	call pspace
	jmp 0xFE02
badcode:
	lxi h,badboot
	call print
	hlt
badload:
	lxi h,loaderr
	call print
	hlt
no_media:
	call phex
	lxi h,nomedia
	call print
	hlt

waitdrq:
	in 0x17		! Status
	mov b,a
	ani 0x08	! DRQ
	rnz
	mvi a,'D'
	call pchar
	mov a,b
	call phex
	jmp waitdrq

waitready:
	in 0x17
	mov b,a
	ani 0x40
	rnz
	mvi a,'R'
	call pchar
	mov a,b
	call phex
	jmp waitready

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
	.ascii "C2014/85 ROM BIOS 0.1.1 for 8085 MMU"
	.data1 13,10
	.ascii "Memory banks present "
newline:
	.data1 13,10,0
loading:
	.asciz "Loading ..."
loaderr:
	.ascii "CF error"
	.data1 13,10,0
badboot:
	.ascii "Not a valid boot block"
	.data1 13,10,0
nomedia:
	.ascii "CF card not present"
	.data1 13,10,0
