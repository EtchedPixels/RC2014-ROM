;
;	CP/M 3 unbanked BIOS for RC2014 with new style ROM
;
;	ZMAC BIOS3.ASM
;	ZMAC SCB.ASM
;	LINK BIOS3[B]=BIOS3,SCB
;	GENCPM
;
	extrn SCBBASE
	extrn CIVEC
	extrn COVEC
	extrn AIVEC
	extrn AOVEC
	extrn LOVEC
	extrn BNKBF
	extrn CRDMA
	extrn CRDSK
	extrn VINFO
	extrn RESEL
	extrn FX
	extrn USRCD
	extrn MLTIO
	extrn ERMDE
	extrn ERDSK
	extrn MEDIA
	extrn BFLGS
	extrn DATE
	extrn HOUR
	extrn MIN
	extrn SEC
	extrn ERJMP
	extrn MXTPA

		cseg

bdos_smulti    equ 44
bdos_open      equ 15
bdos_setdma    equ 26
bdos_read      equ 20
bdos	       equ 0005h  ; BDOS jump vector
cdisk          equ 0004h   ; current disk number, 0=a, 1=b ... 15=p 
; apparently also current user number is in here (in the top 4 bits?)
iobyte         equ 0003h   ; intel "standard" i/o byte (legacy)

romin		equ	0FE00h
romout		equ	0FE03h
romcall		equ	0FE06h
rom_wboot	equ	0FF00h
rom_const	equ	0FF00h+3
rom_conin	equ	0FF00h+6
rom_conout	equ	0FF00h+9
rom_list	equ	0FF00h+12
rom_auxout	equ	0FF00h+15
rom_auxin	equ	0FF00h+18
rom_home	equ	0FF00h+21
rom_seldsk	equ	0FF00h+24
rom_settrk	equ	0FF00h+27
rom_setsec	equ	0FF00h+30
rom_setdma	equ	0FF00h+33
rom_read	equ	0FF00h+36
rom_write	equ	0FF00h+39
rom_listst	equ	0FF00h+42
rom_sectran	equ	0FF00h+45
rom_conost	equ	0FF00h+48
rom_auxist	equ	0FF00h+51
rom_auxost	equ	0FF00h+54
rom_devtbl	equ	0FF00h+57
rom_devini	equ	0FF00h+60
rom_drvtbl	equ	0FF00h+63
rom_multio	equ	0FF00h+66
rom_flush	equ	0FF00h+69
rom_move	equ	0FF00h+72
rom_time	equ	0FF00h+75
rom_selmem	equ	0FF00h+78
rom_setbnk	equ	0FF00h+81
rom_xmove	equ	0FF00h+84
rom_userf	equ	0FF00h+87

tmpsp		equ	0FE00h

; jump vector table used by CP/M
        jp boot         ; cold start
wboote: jp wboot        ; warm start
        jp const        ; console status
        jp conin        ; console character in
        jp conout       ; console character out
        jp list         ; list character out
        jp auxout       ; auxiliary character out
        jp auxin        ; auxiliary character in
        jp home         ; move disk head to home position
        jp seldsk       ; select disk
        jp settrk       ; set track number
        jp setsec       ; set setor number
        jp setdma       ; set DMA address
        jp read         ; read disk
        jp write        ; write disk
        jp listst       ; return list status
        jp sectran      ; sector translate
        jp conost	; console output ready
        jp auxist	; aux input is ready
        jp auxost	; aux output is ready
        jp devtbl	; device table
        jp devini	; device init
        jp drvtbl	; drive table
        jp multio	; multi block I/O
        jp flush	; flush data to disc
        jp move		; block move (including banking)
        jp time		; get current data and time into SCB
        jp selmem	; select memory bank. Special: preserve regs
        jp setbnk	; set the bank for the next read/write sector
        jp xmove	; set up for cross bank move
        jp userf	; extended BIOS
        jp 0		; reserved
        jp 0		; reserved

; disk parameter header (16 bytes for each drive), see page 6-28 in CP/M 2.2
; operating system manual
; CP/M 3 style disk parameter header
;
; These have to be in the BIOS not the ROM or GENCPM will lose its marbles
;
dpbase0:
        ; disk 0 (C)
        dw 0            ; sector translation table (0 = no translation)
	db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	db 0            ; Media flag
        dw dpblkb       ; DPB (disk parameter block)
        dw 0	    	; CSV (unique scratch pad used to check for changed disks)
        dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	dw 0FFFEh	; Directory buffer control block (auto assign)
	dw 0FFFEh       ; Data BCB
        dw 0FFFFh       ; HASH
        db 00h          ; HASH bank
        ; end of disk 0

dpbase1:
        ; disk 1 (D)
        dw 0            ; sector translation table (0 = no translation)
	db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	db 0            ; Media flag
        dw dpblk        ; DPB (disk parameter block)
        dw 0            ; CSV (unique scratch pad used to check for changed disks)
        dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	dw 0FFFEh	; Directory buffer control block (auto assign)
	dw 0FFFEh       ; Data BCB
        dw 0FFFFh       ; HASH
        db 00h          ; HASH bank
        ; end of disk 1

dpbase2:
        ; disk 2 (E)
        dw 0            ; sector translation table (0 = no translation)
	db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	db 0            ; Media flag
        dw dpblk        ; DPB (disk parameter block)
        dw 0	    	; CSV (unique scratch pad used to check for changed disks)
        dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	dw 0FFFEh	; Directory buffer control block (auto assign)
	dw 0FFFEh       ; Data BCB
        dw 0FFFFh       ; HASH
        db 00h          ; HASH bank
        ; end of disk 2

dpbase3:
        ; disk 3 (F)
        dw 0            ; sector translation table (0 = no translation)
	db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	db 0            ; Media flag
        dw dpblk        ; DPB (disk parameter block)
        dw 0            ; CSV (unique scratch pad used to check for changed disks)
        dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	dw 0FFFEh	    ; Directory buffer control block (auto assign)
	dw 0FFFEh       ; Data BCB
        dw 0FFFFh       ; HASH
        db 00h          ; HASH bank
        ; end of disk 1

dpbasem:
        dw 0            ; sector translation table (0 = no translation)
	db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	db 0            ; Media flag
        dw dpbram       ; DPB (disk parameter block)
        dw 0            ; CSV (unique scratch pad used to check for changed disks)
        dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	dw 0FFFEh	    ; Directory buffer control block (auto assign)
	dw 0FFFFh       ; Data BCB (not required)
        dw 0FFFFh       ; HASH (none)
        db 00h          ; HASH bank

dphtab	dw 0		; A: floppy
	dw 0		; B: floppy
	dw dpbase0	; C:
	dw dpbase1	; D:
	dw dpbase2      ; E:
	dw dpbase3	; F:
	dw 0		; G; GenCPM requires unused present and 0
	dw 0		; H:
	dw 0		; I:
	dw 0		; J:
	dw 0		; K:
	dw 0		; L:
	dw dpbasem	; M: ram drive
	dw 0		; N:
	dw 0		; O:
	dw 0		; P:

ndisks  equ 6               ; number of disks we defined

; disk parameter block (can be shared by all disks with same configuration)
;
; boot volume with a track reserved
;
dpblkb:
        dw 1024         ; SPT: number of 128 byte sectors per track
        db 5            ; BSH: block shift factor (see manual for table)
        db 31           ; BLM: block mask (see manual for table)
        db 1            ; EXM: extent mask (see manual for table, using entries
			; marked N/A turns out to be a bad idea!)
        dw 1983         ; DSM: (disk bytes / block bytes) - 1,
			; change alv00/01 etc if you change this
			; this is the number of the last sector on the disk,
			; excluding system tracks (ie more system tracks ->
			; this gets smaller)
        dw 511          ; DRM: directory max entries - 1
        db 0f0h         ; AL0: directory sector allocation bitmask byte 0
        db 00h          ; AL1: directory sector allocation bitmask byte 1
        dw 8000h        ; CKS: check size (0x8000 = fixed media, no check)
        dw 1            ; OFF: track offset (number of system tracks)
	db 2	        ; PSH - 512 byte sectors
	db 3	        ; PHM - 512 byte sectors
;
; non boot volumes
;
dpblk:
        dw 1024         ; SPT: number of 128 byte sectors per track
        db 5            ; BSH: block shift factor (see manual for table)
        db 31           ; BLM: block mask (see manual for table)
        db 1            ; EXM: extent mask (see manual for table, using entries
			; marked N/A turns out to be a bad idea!)
        dw 2015      	; DSM: (disk bytes / block bytes) - 1,
			; change alv00/01 etc if you change this
			; this is the number of the last sector on the disk,
			; excluding system tracks (ie more system tracks ->
			; this gets smaller)
        dw 511          ; DRM: directory max entries - 1
        db 0f0h         ; AL0: directory sector allocation bitmask byte 0
        db 00h          ; AL1: directory sector allocation bitmask byte 1
        dw 8000h        ; CKS: check size (0x8000 = fixed media, no check)
        dw 0            ; OFF: track offset (number of system tracks)
	db 2	    ; PSH - 512 byte sectors
	db 3	    ; PHM - 512 byte sectors

dpbram:
        dw 2            ; SPT: number of 128 byte sectors per track
        db 3            ; BSH: block shift factor (see manual for table)
        db 7            ; BLM: block mask (see manual for table)
        db 0            ; EXM: extent mask (see manual for table, using entries
			; marked N/A turns out to be a bad idea!)
        dw 62      	; DSM: (disk bytes / block bytes) - 1,
			; change alv00/01 etc if you change this
			; this is the number of the last sector on the disk,
			; excluding system tracks (ie more system tracks ->
			; this gets smaller)
        dw 31           ; DRM: directory max entries - 1
        db 080h         ; AL0: directory sector allocation bitmask byte 0
        db 00h          ; AL1: directory sector allocation bitmask byte 1
        dw 8000h        ; CKS: check size (0x8000 = fixed media, no check)
        dw 0            ; OFF: track offset (number of system tracks)
	db 0	        ; PSH - 128 byte sectors
	db 1	        ; PHM - 128 byte sectors



; The device utility table.

MB_INPUT    equ		1	; We do input
MB_OUTPUT   equ		2	; We do output
MB_INOUT    equ		3	; We do both
MB_SOFTBAUD equ		4       ; Soft baud rates
MB_SERIAL   equ         8       ; Serial protocol
MB_XONXOFF  equ         16	; XON/XOF protocol

BAUD_NONE    equ	0
BAUD_50	     equ	1
BAUD_75	     equ	2
BAUD_110     equ	3
BAUD_134     equ	4	; Actuall 134.5
BAUD_150     equ	5
BAUD_300     equ	6
BAUD_600     equ	7
BAUD_1200    equ	8
BAUD_1800    equ	9
BAUD_2400    equ	10
BAUD_3600    equ	11
BAUD_4800    equ	12
BAUD_7200    equ	13
BAUD_9600    equ	14
BAUD_19200   equ	15

; To do - device tables

; bios functions follow
boot:
	ld sp, 08000h		; Well clear of anything during set up
	xor a			
        ld (iobyte), a
	ld a,2			; Default to C:
        ld (cdisk), a

        ; say hello
        ld hl, bootmsg
        call strout
        ei

	; Kick out the ROM if we didn't do so already
        jp gocpm

wboot:    
	ld sp, 08000h		; scratch space below CCP and clear of
				; CP/M during the load (naughty but saves
				; space)

gocpm:
	; Remember in banked mode we need to write these into bank 1 for
	; CCP to use
        ld a, 0c3h      ; 0xc3 is a jmp instruction
        ld (0), a       ; write JMP instruction at 0x0000
        ld (5), a       ; write JMP instruction at 0x0005
        ld hl, wboote
        ld (1), hl      ; write vector for warm boot at 0x0001, 0x0002.
        ld hl, (MXTPA)  ; BDOS entry point
        ld (6), hl      ; write vector for BDOS at 0x0006, 0x0007.
ccpload:
	xor a	    ; set up our FCB
	ld (ccpext), a
	ld (ccprc), a
	ld hl, 0
	ld (fcbnr), hl
	ld de, ccpfcb
	ld c, bdos_open
	call bdos
	inc a
	jp nz, openok   ; opened CCP.COM ok
	ld hl, noccp
	call strout	    ; 
	call conin
	jp ccpload
readfail:
	ld hl, badccp
	call strout	    ; 'try again'
	call conin
	jp ccpload

openok:
	ld de, 0100h
	ld c, bdos_setdma
	call bdos
	ld de, 128
	ld c, bdos_smulti
	call bdos
	ld de, ccpfcb
	ld c, bdos_read
	call bdos

	cp 1
	jp nz,readfail	    ; EOF is good
ccpok:
        ld bc, 0080h    ; default DMA address
        call setdma     ; configure DMA
	ld a, 1	    ; single sector I/O
	ld (MLTIO), a   ; set default blocking
	call selmem	    ; CCP is in bank 1
        ld a, (cdisk)   ; get current disk
        ld c, a         ; send to ccp
        jp 0100h        ; and we're off!

ccpfcb:	db 3
	db 'CCP     COM'
ccpext:	db 0,0,0
ccprc:	db 0
	db 0,0,0,0,0,0,0,0
	db 0,0,0,0,0,0,0,0
fcbnr:	db 0,0,0
	db 0,0,0

noccp:	db 'CCP.COM not found',10,13,0
badccp:	db 'CCP.COM read failed',10,13,0

const:
	push ix
	ld ix,rom_const
	jr dorom
conin:
	push ix
	ld ix,rom_conin
	jr dorom
conout:
	push ix
	ld ix,rom_conout
	jr dorom
list:
	push ix
	ld ix,rom_list
	jr dorom
auxout:
	push ix
	ld ix,rom_auxout
	jr dorom
auxin:
	push ix
	ld ix,rom_auxin
	jr dorom
home:
	push ix
	ld ix,rom_home
	jr dorom
seldsk:
	ld a,c
	cp 12
	jr z, selm_ok		; M drive we know about
	cp 7			; reject any drive we don't know about
	ld hl,0			; so we don't blow up if the ROM adds stuff
	ret nc			; and the user hits that drive letter
selm_ok:
	push ix
	ld ix,rom_seldsk
	call romcall
	pop ix
	ld hl,0
	xor a
	cp b
	ret z		; failed
	; We own the table lookup. ROM preserves C
	ld hl,dphtab
	ld b,0
	add hl,bc
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret
settrk:
	push ix
	ld ix,rom_settrk
	jr dorom
setsec:
	push ix
	ld ix,rom_setsec
	jr dorom
setdma:
	push ix
	ld ix,rom_setdma
	jr dorom
read:
	push ix
	ld ix,rom_read
	jr dorom
write:
	push ix
	ld ix,rom_write
dorom:
	call romcall
	pop ix
	ret
listst:
	push ix
	ld ix,rom_listst
	jr dorom
sectran:
	push ix
	ld ix,rom_sectran
	jr dorom
conost:
	push ix
	ld ix,rom_conost
	jr dorom
auxist:
	push ix
	ld ix,rom_auxist
	jr dorom
auxost:
	push ix
	ld ix,rom_auxost
	jr dorom
devtbl:
	push ix
	ld ix,rom_devtbl
	jr dorom
devini:
	push ix
	ld ix,rom_devini
	jr dorom
;
;	Has to be in the BIOS or GENCPM loses its marbles
;
drvtbl:
	ld hl,dphtab
	ret
multio:
	push ix
	ld ix,rom_multio
	jr dorom
flush:
	push ix
	ld ix,rom_flush
	jr dorom
move:
	ex de,hl
	ldir
	ex de,hl
	ret
time:
	push ix
	ld ix,rom_time
	jr dorom
selmem:
setbnk:
xmove:
userf:
reserv1:
reserv2:
	ret

; debug functions (ideally to be removed in final version)
strout:     ; print string pointed to by HL
	push af
        push bc
        push de
stroutl:
	ld a, (hl)
	or a
        jp z, stroute
        ld c, a
	push hl
        call conout
        pop hl
        inc hl
        jp stroutl
stroute:
	pop de
        pop bc
        pop af
        ret

outnibble:
	and 0fh
        cp 10
        jp c, numeral
        add 07h
numeral:add 30h
        ld c, a
        jp conout

outcharhex: ; print byte in A as two-char hex value
        push hl
        push de
        push bc
        push af
        ld d, a ; copy
        rra
        rra
        rra
        rra
        push de
        call outnibble
        pop de
        ld a, d
        call outnibble
        pop af
        pop bc
        pop de
        pop hl
        ret

bootmsg:
	db 10, 13
	db 'RC2014 CP/M 3.x BIOS 0.01'
	db 10,13
	db '(C) Alan Cox 2019-2020'
	db 10,13,10,13,0

clockinit:
	; TODO
	ret

