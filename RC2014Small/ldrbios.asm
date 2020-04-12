;
;	CP/M 3 Loader BIOS for RC2014
;
;	This uses Z80 instruction format but only 8080 instructions. That
;	makes it much easier to maintain the shared code.
;
; on CP/M
; zmac ldrbios.asm
; link cpmldr[L8200]=cpmldr,ldrbios
; Remembering it will use the 256 bytes below its load address for data
;

.z80 ; prefer z80 mnemonics

;
;	We run with the ROM mapped. As we don't use low space nothing
;	will mind and the CP/M BIOS init will fix up the low mapping
;
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




; jump vector table used by CP/M
            jp boot         ; cold start
wboote:     jp bad          ; warm start
            jp bad	    ; console status
            jp bad          ; console character in
            jp conout       ; console character out
            jp bad          ; list character out
            jp bad          ; punch character out
            jp bad          ; reader character out
            jp home         ; move disk head to home position
            jp seldsk	    ; select disk
            jp settrk       ; set track number
            jp setsec       ; set sector number
            jp setdma       ; set DMA address
            jp read         ; read disk
            jp bad          ; write disk
            jp bad          ; return list status
            jp sectran      ; sector translate
            jp bad	    ; console output ready
            jp bad	    ; aux input is ready
            jp bad	    ; aux output is ready
            jp bad	    ; device table
            jp bad	    ; device init
            jp bad 	    ; drive table
            jp bad 	    ; multi block I/O
            jp bad	    ; flush data to disc
            jp move	    ; block move (including banking)
            jp bad	    ; get current data and time into SCB
            jp bad	    ; select memory bank. Special: preserve regs
            jp bad	    ; set the bank for the next read/write sector
            jp bad	    ; set up for cross bank move
            jp bad	    ; extended BIOS
            jp 0	    ; reserved
            jp 0	    ; reserved


; CP/M 3 style disk parameter header
dpbase0:
            ; disk 0 (A)
            dw 0            ; sector translation table (0 = no translation)
	    db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	    db 0            ; Media flag
            dw dpblk        ; DPB (disk parameter block)
            dw 0            ; CSV (unique scratch pad used to check for changed
			    ; disks)
            dw alv00        ; ALV (unique scratch pad for allocation information)
	    dw dirbcb0	    ; Directory buffer control block
	    dw dtabcb       ; DTAB CB
            dw 0FFFFh       ; HASH
            db 0            ; HASH bank
            ; end of disk 0

ndisks      equ 1           ; number of disks we defined

dirbcb0:    db 0FFh	    ; Disk Drive
            ds 3	    ; Record
            ds 1            ; Write Buffer Flag
            db 0            ; BDOS scratch byte
            ds 2            ; Track
            ds 2            ; Sector
            dw dirb0        ; Directory buffer
            db 0	    ; Bank
            dw 0	    ; Link

dtabcb:     db 0FFh	    ; Disk Drive
            ds 3	    ; Record
            ds 1            ; Write Buffer Flag
            db 0            ; BDOS scratch byte
            ds 2            ; Track
            ds 2            ; Sector
            dw data0        ; Data buffer
            db 0	    ; Bank
            dw 0	    ; Link

; disk parameter block (can be shared by all disks with same configuration)
;
;
;
dpblk:
            dw 1024         ; SPT: number of 128 byte sectors per track
            db 5            ; BSH: block shift factor (see manual for table)
            db 31           ; BLM: block mask (see manual for table)
            db 1            ; EXM: extent mask (see manual for table)
            dw 1983         ; DSM: (disk bytes / block bytes) - 1
			    ; change alv00/01 etc if you change this
                            ; this is the number of the last sector on the disk,
                            ; excluding system tracks (ie more system tracks ->
                            ; this gets smaller)
            dw 511          ; DRM: directory max entries - 1
            db 0f0h         ; AL0: directory sector allocation bitmask byte 0
            db 0            ; AL1: directory sector allocation bitmask byte 1
            dw 8000h         ; CKS: check size (0x8000 = fixed media, no check)
            dw 1            ; OFF: track offset (number of system tracks)
	    db 2	    ; PSH - 512 byte sectors
	    db 3	    ; PHM - 512 byte sectors


; bios functions follow

boot:
	    call romout
	    ld hl, bootstr
            jp strout
bad:
            ld hl, ouchithurts
            call strout
	    di
	    halt

seldsk:
	    ld c,2	    ; As the ROM sees it we boot off C:
	    ld ix,rom_seldsk
	    call romcall
	    ld hl,0
            ld a,c
	    or a
	    ret z
	    ld hl,dpbase0
	    ret
conout:
	    ld ix,rom_conout
	    jp romcall
home:
	    ld ix,rom_home
	    jp romcall
settrk:
	    ld ix,rom_settrk
	    jp romcall
setsec:
	    ld ix,rom_setsec
	    jp romcall
setdma:
	    ld ix,rom_setdma
	    jp romcall
sectran:
	    ld ix,rom_sectran
	    jp romcall
read:
	    ld ix,rom_read
	    jp romcall
move:
	    ex de,hl
	    ldir
	    ex de,hl
	    ret

wefailed:   jp wefailed

; debug functions (ideally to be removed in final version, if we ever get that far!)
strout:     ; print string pointed to by HL
            ld a, (hl)
	    or a
            ret z
            ld c, a
	    push hl
	    ld ix,rom_conout
            call romcall
	    pop hl
            inc hl
            jp strout

ouchithurts: db "oops", 0
bootstr: db "Boot", 0


dirb0:      ds 128           ; directory scratch area
dirb1:      ds 128           ; directory scratch area
data0:	    ds 128	     ; data scratch area
alv00:      ds 64            ; allocation vector for disk 0, must be (DSM/8)+1 bytes
alv01:      ds 64            ; allocation vector for disk 1, must be (DSM/8)+1 bytes
