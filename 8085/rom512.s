#define ACIA_RESET	0x03
#define ACIA_RTS_LOW	0x96

#define	stack_base	0xFDE0
#define scratch		0xFDE0
#define uart_type	0xFDF0
#define ide_type	0xFDF1
#define ram_bad		0xFDFF

#define in_helper	0xFDE0
#define out_helper	0xFDE3
#define nbank		0xFDE6

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
	jmp go
	nop
	nop
	nop
	nop
!
!	Vectors for loaders etc
!
r8:	jmp pchar
	jmp print
	jmp ide_readb
	jmp ide_read_data
	jmp ide_writeb
	jmp ide_waitdrq
	jmp ide_waitready

!
!	Our first goal is to figure out the UART and print something,
!	anything so the user knows the board is at least running. We do
!	this without touching the MMU or requiring RAM
!
go:
	!
	!	Probe for a 68B50
	!
	in 0xA0
	ani 2
	jz not_acia		! TX ready ought to be high...
	mvi a,ACIA_RESET
	out 0xA0		! Force reset on
	in 0xA0
	ani 2			! Reset forces TX ready off
	jnz not_acia
	mvi a,2			! Put the ACIA back in normal state
	out 0xA0
	mvi a,ACIA_RTS_LOW	! Set up the lines
	sta 0xA0
	mvi a,'R'		! Print the initial 'R'
	out 0xA1
	mvi b,1
	jmp init_ram

not_acia:
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
	mvi b,2

init_ram:
	!
	!	Put some RAM in the common space
	!
	mvi a,0x01		! ROM 0 low RAM 0 high
	out 0xFF
	lxi sp, stack_base	! Point SP into RAM (just under the space
				! we keep for info)

	!
	!	Now we have RAM remember the detected UART
	!
	mov a,b
	sta uart_type

	xra a
	sta ram_bad

	!
	!	Display the sign on message and begin the RAM test
	!	If you get just RC then you know there is a RAM problem
	!
	lxi h,signon
	call print

	!
	!	RAM test
	!
	lxi h,0xFE00
	lxi d,banktab
	lxi b,0x55AA
	mvi a,'0'
	sta nbank

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
	lda nbank
pnext:
	call pchar
	inx d
	lda nbank
	inr a
	sta nbank
	jmp ramnext
notpresent:
	mvi a,0x01
	out 0xFF
	sta ram_bad
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

	lda ram_bad
	ora a
	jz ram_good
	lxi h,ramwarning
	call print


ram_good:

	!
	!	Hardware reporting
	!

	lda uart_type
	dcr a
	lxi h,is_acia
	jz report_uart
	lxi h,is_16x50
report_uart:
	call print

	call ide_init

	lda ide_type
	dcr a
	lxi h,is_ppide
	jz report_ide
	lxi h,is_cf

report_ide:
	call print

	lxi h,0xE0		! Master, LBA
	mvi a,0xE		! Set head/device
	call ide_writeb

	!
	!	Select the disk
	!
	call ide_waitready

	!
	!	Let the user know
	!
	lxi h,loading
	call print

	mvi a,'1'
	call pchar
	lxi h,0x55
	mvi a,0x0B		! Reg 3 should be writable/readable
	call ide_writeb
	mvi a,0x0B
	call ide_readb
	cpi 0x55
	jnz no_media
	mvi a,'2'
	call pchar
	lxi h,0xAA
	mvi a,0x0B
	call ide_writeb
	mvi a,0x0B
	call ide_readb
	cpi 0xAA
	jnz no_media
	mvi a,'3'
	call pchar
	lxi h,0
	mvi a,0x0B		! LBA 0-2 to 0
	call ide_writeb
	mvi a,0x0C
	call ide_writeb
	mvi a,0x0D
	call ide_writeb
	! We set LBA3 to E0 already
	mvi l,1
	mvi a,0x0A		! Count
	call ide_writeb
	mvi a,'4'
	call pchar
	mvi l,0x20
	mvi a,0x0F		! Command
	call ide_writeb
	lxi h,0xFE00		! buffer target
	mvi a,'W'
	call pchar
	call ide_waitdrq
	mvi a,'w'
	call pchar

	call ide_read_data	! Transfer a sector into FE00-FFFF

	call ide_waitready
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

ide_waitdrq:
	mvi a,0x0F		! Status
	call ide_readb
	mov b,a
	ani 0x09		! DRQ or ERR
	rnz
	mvi a,'D'
	call pchar
	mov a,b
	call phex
	jmp ide_waitdrq

ide_waitready:
	mvi a,0x0F
	call ide_readb
	mov b,a
	ani 0x41
	rnz
	mvi a,'R'
	call pchar
	mov a,b
	call phex
	jmp ide_waitready

!
!	Print the string in HL. Uses A
!
print:
	mov a,m
	ora a
	rz
	call pchar
	inx h
	jmp print

pspace:
	mvi a,32
!
!	Print the character in A
!
pchar:
	push psw
	lda uart_type
	dcr a
	jnz pcharw_16x50
pcharw_acia:
	in 0xA0
	ani 2
	jz pcharw_acia
	pop psw
	out 0xA1
	ret

pcharw_16x50:
	in 0xC5
	ani 0x20
	jz pcharw_16x50
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

!
!	Library for PPIDE on 8085
!
#define PPIDE_PPI_BUS_READ	0x92
#define PPIDE_PPI_BUS_WRITE	0x80

#define PPIDE_PPI_WR_LINE	0x20
#define PPIDE_PPI_RD_LINE	0x40
#define PPIDE_PPI_RESET_LINE	0x80

#define IDE_REG_STATUS		0x0F
#define IDE_REG_DATA		0x08

!
!	Initialize IDE
!
ide_init:
	!
	!	Set up helpers
	!
	!	We write
	!		IN xx		DB 00
	!		RET		C9
	!		OUT xx		D3 00
	!		RET		C9
	!
	!	into some scratch RAM
	!
	lxi h,0x00DB
	shld in_helper
	lxi h,0xD3C9
	shld in_helper+2
	lxi h,0xC900
	shld in_helper+4
	!
	!	Probe for a PPIDE
	!
	mvi a,0x9B		! All inputs
	out 0x23
	in 0x23
	cpi 0x9B		! Check if we can read it back
	jnz ide_cf_init
	mvi a,PPIDE_PPI_BUS_READ
	out 0x23
	in 0x23
	cpi PPIDE_PPI_BUS_READ
	jnz ide_cf_init
	mvi a,PPIDE_PPI_RESET_LINE
	out 0x22

	lxi b,0xFFFF
wait1:
	dcx b
	jnk wait1

	mvi a,IDE_REG_STATUS
	out 0x22

	mvi a,1
	sta ide_type
	ret

ide_cf_init:
	mvi a,0xE0
	out 0x16		! Head and device
	call ide_waitready
	mvi a,1
	out 0x11
	mvi a,0xEF		! 8bit mode
	out 0x17
	call ide_waitready

	! Could do a 55/AA detect test here if we need to allow for a
	! further type
	mvi a,2
	sta ide_type
	ret
!
!	Read register A and return it A
!	Uses BC
!
ide_readb:
	mov b,a
	lda ide_type
	dcr a
	jnz ide_readb_cf
	mov a,b
	out 0x22
	ori PPIDE_PPI_RD_LINE
	out 0x22
	in 0x20
	mov c,a
	mov a,b
	out 0x22
	mov a,c
	ret
!
!	This is really ugly because we don't have out (c) and in (c)
!	on 8080/8085
!
ide_readb_cf:
	mov a,b
	adi 8			! Turn the PPIDE bits into a port
	sta in_helper+1
	jmp in_helper

!
!	Write register A with HL
!	uses BC
!
ide_writeb:
	mov b,a
	lda ide_type
	dcr a
	jnz ide_writeb_cf
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
ide_writeb_cf:
	mov a,b
	adi 8			! Turn the PPIDE bits into a port
	sta out_helper+1
	mov a,l			! 8bits to write
	jmp out_helper

!
!	Read the sector data into HL
!
ide_read_data:
	lda ide_type
	dcr a
	jnz ide_read_data_cf
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
ide_read_data_cf:
	mvi b,0
cfread:
	in 0x10			! Read data
	mov m,a
	inx h
	in 0x10
	mov m,a
	inx h
	dcr b
	jnz cfread
	ret

.sect .rom
signon:
	.ascii "C2014/85 ROM BIOS 0.1.2 for 8085/MMU"
	.data1 13,10
	.asciz "Memory banks present: "
loading:
	.asciz "Loading ..."
loaderr:
	.ascii "CF error"
newline:
	.data1 13,10,0
badboot:
	.ascii "Not a valid boot block"
	.data1 13,10,0
nomedia:
	.ascii "CF card not present"
	.data1 13,10,0
is_acia:
	.ascii "Console: ACIA at 0xA0"
	.data1 13,10,0
is_16x50:
	.ascii "Console: 16x50 UART at 0xC0"
	.data1 13,10,0
is_cf:
	.ascii "IDE: CF adapter at 0x10"
	.data1 13,10,0
is_ppide:
	.ascii "IDE: PPIDE adapter at 0x20"
	.data1 13,10,0
ramwarning:
	.ascii "WARNING: RAM test failed"
	.data1 13,10,0
