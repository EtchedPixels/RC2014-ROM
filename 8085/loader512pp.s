#
!
!	A loader bootblock to run at 0xFE00
!
!	This version for the 8085/MMU card and PPIDE
!	(We need to grow the firmware into having a callable interface
!	to a generic disk and serial interface)
!
.sect .text
.sect .rom
.sect .data
.sect .bss
.sect .text

	.data2 0x8085

start:
	lxi h,Ok
	call print

	mvi a,3
	out 0xFF

	lxi h,0x0100
	lxi sp,0xfe00

	!	HL	= load address
	!	B	= counts bytes for sector loads
	!	C	= current sector
	!
	xra a
dread:
	inr a
	cpi 126
	jz load_done
	push psw
	push h
	mvi h,0
	mov l,a
	mvi a,0x0B		! LBA low (3)
	call ppide_writeb
	mvi l,1
	mvi a,0x0A
	call ppide_writeb	! We can't assume this will stay as 1
	mvi l,0x20
	mvi a,0x0F		! READ command
	call ppide_writeb

	mvi a,'.'
	out 0xC0

	call waitdrq

	pop h

	call ppide_read_data
	call waitready
	pop psw
	jmp dread

load_done:
	lda 0x0100
	cpi 0x85
	jnz bad_load
	lda 0x0101
	cpi 0x80
	jnz bad_load
	lxi h,running
	call print
	jmp 0x0102

bad_load:
	lxi h,badimg
	call print
	hlt
	
waitdrq:
	mvi a,0x0F		! Status
	call ppide_readb
	ani 0x09		! DRQ or ERR
	rnz
	jmp waitdrq

waitready:
	mvi a,0x0F
	call ppide_readb
	ani 0x41
	rnz
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

!
!	Library for PPIDE on 8085
!
#define PPIDE_PPI_BUS_READ	0x92
#define PPIDE_PPI_BUS_WRITE	0x80

#define PPIDE_PPI_WR_LINE	0x20
#define PPIDE_PPI_RD_LINE	0x40

#define IDE_REG_STATUS		0x0F
#define IDE_REG_DATA		0x08

!
!	Initialize PPIDE
!
ppide_init:
	mvi a,PPIDE_PPI_BUS_READ
	out 0x23
	mvi a,IDE_REG_STATUS
	out 0x22
	ret

!
!	Read register A and return it A
!	Uses BC
!
ppide_readb:
	out 0x22
	mov b,a
	ori PPIDE_PPI_RD_LINE
	out 0x22
	in 0x20
	mov c,a
	mov a,b
	out 0x22
	mov a,c
	ret

!
!	Write register A with HL
!	uses BC
!
ppide_writeb:
	mov b,a
	mvi a,PPIDE_PPI_BUS_WRITE
	out 0x23
	mov a,b
	out 0x22
	mov a,l
	out 0x20
	mov a,h
	out 0x21
	mov a,b
	ori PPIDE_PPI_WR_LINE
	out 0x22
	mov a,b
	out 0x22
	mvi a,PPIDE_PPI_BUS_READ
	out 0x23
	ret
!
!	Read the sector data into HL
!
ppide_read_data:
	mvi a,IDE_REG_DATA
	out 0x22
	mov d,a
	ori PPIDE_PPI_RD_LINE
	mov e,a
	mvi b,0
goread:
	mov a,e
	out 0x22
	in 0x20
	mov m,a
	inx h
	in 0x21
	mov m,a
	inx h
	mov a,d
	out 0x22
	dcr b
	jnz goread
	ret



.sect .data

Ok:
	.ascii 'Ok'
	.data1 13,10,0

badimg:
	.ascii 'Image not bootable.'
	.data1 13,10,0

running:
	.ascii 'Boot complete.'
	.data1 13,10,0
