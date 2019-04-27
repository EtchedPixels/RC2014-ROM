!
!	A loader bootblock to run at 0xFE00
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

	mvi a,1
	out 0x40	! Page in RAM not ROM

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
	out 0x13
	mov c,a
	mvi a,1
	out 0x12	! We can't assume this will stay as 1
	mvi a,0x20
	out 0x17

	call waitdrq
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
	call waitready
	mov a,c
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
	in 0x17		! Status
	ani 0x08	! DRQ
	jz waitdrq
	ret

waitready:
	in 0x17
	ani 0x40
	jz waitready
	ret

print:
	in 0
	ani 2
	jz print
	mov a,m
	ora a
	rz
	out 1
	inx h
	jmp print

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
