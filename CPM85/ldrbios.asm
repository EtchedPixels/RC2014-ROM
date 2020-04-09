;
;	CP/M 3 Loader BIOS for RC2014 on 8085
;
;	This uses Z80 instructio format but only 8080 instructions. That
;	makes it much eaiser to maintain the shared code.
;
; on CP/M
; zmac ldrbios.asm
; link cpmldr[L100]=cpmldr,ldrbios
;
; Test by running the resulting binary on CP/M *unbanked*
;
; For production use link at the final desired address (remembering it will
; use 128 bytes below that as data), set the boot code to load it and off
; you go
;
; For the moment this loader BIOS assumes that it's being run from something
; that has initialized the UARTs and put the CF interface into 8bit mode.
;

.z80 ; prefer z80 mnemonics



DATA		equ 10h    	;CF data register
ERROR    	equ 11h    	;CF error reg
COUNT		equ 12h    	;CF sector count reg
LBA_0     	equ 13h   	;CF LA0-7
LBA_1    	equ 14h       	;CF LA8-15
LBA_2   	equ 15h       	;CF LA16-23
LBA_3   	equ 16h       	;CF LA24-27
CMD   		equ 17h       	;CF status/command reg
CFSTATUS	equ 17h       	;CF status/command reg

ERR		equ 0
DRQ		equ 3
READY		equ 6
BUSY		equ 7

; Cookies from the ROM

uart_type	equ 0FDF0h
ide_type	equ 0FDF1h

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
            jp seldsk       ; select disk
            jp seltrk       ; set track number
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
	    ld hl, bootstr
            call strout
;
;	Now sort the banks out. We load the OS into what to us is the alt
;	space but to CP/M is bank 0. We are loaded low so can arrange our
;	own space to be common
;
	    ld a,2
	    out (0eeh),a
	    ld a,0d4h			; Common E000+ and also low 16K
					; for the loader so we don't vanish
	    out (0efh),a
	    ld a,3
	    out (0eeh),a
	    in a,(0efh)
	    and 0fch
	    or 2			; Above us is now the CP/M OS bank
					; and CP/M will clean up once loaded
	    out (0efh),a
	    ret
bad:
            ld hl, ouchithurts
            call strout
wefailed:   jp wefailed

conout:     ; write character from C to console
	    ld a,(uart_type)
            dec a
	    jp nz, out_16x50
            in a, (0A0h)
	    and 2
            jp z, conout ; loop again if transmitter is busy
            ld a, c
	    out (0A1h),a
            ret
out_16x50:
	    in a,(0C5h)
	    and 020h
	    jp z, out_16x50
	    ld a,c
	    out (0C0h),a
            ret

move:       ; copy BC bytes from DE->HL.
	    ld a,(de)
            ld (hl),a
            inc de
            inc hl
            dec bc
            ld a,b
            or c
            jp nz, move
            ; return de,hl as next bytes to copy 
            ret

seldsk:     ; select disk indicated by register C
            ld hl, 0    ; return code 0 indicates error
            ld a, c
            cp ndisks
            ret nc      ; return (with error code) if C >= ndisks ie illegal drive
            ld (curdisk), a ; store current disk
            ld hl, dpbase0
            ret

home:       
	    ld c, 0
            ; fall through into seltrk
seltrk:     ; set track given by register BC
            ld a, c
            ld (curtrack), a
            ret

setsec:     ; set sector given by register BC
            ld a, c
            ld (cursector), a
            ret

sectran:    ; logical to physical sector translation
            ; HL=BC ie 1:1 mapping (no translation)
            ld h, b
            ld l, c
            ret

devini:	    ; re-initialize device C, called on baud/mode change
            ; nothing to do for now
            ret

setdma:     ; set DMA address given by BC
            ld (curdmaaddr), bc ; may need to xfer to HL first?
            ret

read:
            call ide_setup_read
	    jp z, rw_fail
read_loop:
	    in a,(DATA)
	    ld (hl),a
	    inc hl
	    in a,(DATA)
	    ld (hl),a
	    inc hl
	    dec b
	    jp nz, read_loop
rw_done:    xor a ; return to bank 0
	    ret
rw_fail:
	    ld a,1
	    ret

ide_map:
;
;   Block addressed
;   00000000 00000000TTTTTTTT SSSSSSSS
;
;
;	    ld hl, mkblk
;	    call strout
            ld a, (curtrack)
	    ld hl,(cursector)	  ; sector 0-255 (512 bytes for 1024 x 128)
	    ld h,a
	    ld de,0		  ; always drive A
;	    call outcharhex
            ret			  ; done

;mkblk:	    db 13,10,'MB',0


;
;	Read LBA EHL from current drive (we don't support multiple disks)
;
ide_setup_read:
	call ide_map	; Get an LBA
	ld a,l		;
	out (LBA_0),a	; write LSB CF LA address
	ld a,h
	out (LBA_1),a
	ld a,e
	out (LBA_2),a
	ld a,1		; read one sector
	out (COUNT),a	; write to sector count with 1
	ld a,20h	; read CF sector command
	out (CMD),a	; issue the CF read sector comand
	ld de,4000h	; Timeout
	; check drq bit set before read CF data
readdrq:
	dec de
	ld a,d
	or e
	ret z
	in a,(CFSTATUS)	; check data request bit set before read CF data
	and 8		; bit 3 is DRQ, wait for it to set
	jp z,readdrq
	ld bc,DATA	; expected by caller
	ld hl,(curdmaaddr)
	ret

;---------------------------------------------------------------------------------------------------------------
; debug functions (ideally to be removed in final version, if we ever get that far!)
strout:     ; print string pointed to by HL
            ld a, (hl)
	    or a
            ret z
            ld c, a
            call conout
            inc hl
            jp strout

ouchithurts: db "oops", 0
bootstr: db "Boot", 0
;---------------------------------------------------------------------------------------------------------------

; scratch RAM used by BIOS
curdisk:    db 11h
curtrack:   db 22h
cursector:  db 33h
curdmaaddr: dw 4444h
dirb0:      ds 128           ; directory scratch area
dirb1:      ds 128           ; directory scratch area
data0:	    ds 128	     ; data scratch area
alv00:      ds 64            ; allocation vector for disk 0, must be (DSM/8)+1 bytes
alv01:      ds 64            ; allocation vector for disk 1, must be (DSM/8)+1 bytes
