;
;	CP/M 3 Banked BIOS for Micro80
;
;	Based on the CP/M 3 Banked BIOS for SOCZ80 and the CP/M 2.2 ROMs for
;	Micro80 and Simple80.
;
;	TODO
;	- xmove (not clear if worth it)
;	- wire the clock up to the CTC and use IM2
;	- interrupt driven serial buffering
;	- baud rate handling (if the final board lets you wire the baud
;	  rates to the CTC outputs)
;	- bitbang SD card (just needs the code importing for CP/M 3)
;	- possibly support CP/M partitions with on disk DPB
;	- test on non emulated hardware
;	
;	ZMAC BIOS3.ASM
;	ZMAC SCB.ASM
;	LINK BNKBIOS3[B]=BIOS3,SCB
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

SIOAData	equ 18h		;location of SIO chan A data
SIOACmd		equ 19h		;location of SIO command/status reg
SIOBData	equ 1Ah		;location of SIO chan A data
SIOBCmd		equ 1Bh		;location of SIO command/status reg
DATA		equ 90h    	;CF data register
ERROR    	equ 91h    	;CF error reg
COUNT		equ 92h    	;CF sector count reg
LBA_0     	equ 93h   	;CF LA0-7
LBA_1    	equ 94h       	;CF LA8-15
LBA_2   	equ 95h       	;CF LA16-23
LBA_3   	equ 96h       	;CF LA24-27
CMD   		equ 97h       	;CF status/command reg
CFSTATUS	equ 97h       	;CF status/command reg

ERR		equ 0
DRQ		equ 3
READY		equ 6
BUSY		equ 7

bdos_smulti    equ 44
bdos_open      equ 15
bdos_setdma    equ 26
bdos_read      equ 20
bdos	       equ 0005h  ; BDOS jump vector
cdisk          equ 0004h   ; current disk number, 0=a, 1=b ... 15=p 
; apparently also current user number is in here (in the top 4 bits?)
iobyte         equ 0003h   ; intel "standard" i/o byte (legacy)

; jump vector table used by CP/M
            jp boot         ; cold start
wboote:     jp wboot        ; warm start
            jp const        ; console status
            jp conin        ; console character in
            jp conout       ; console character out
            jp list         ; list character out
            jp auxout       ; auxiliary character out
            jp auxin        ; auxiliary character in
            jp home         ; move disk head to home position
            jp seldsk       ; select disk
            jp seltrk       ; set track number
            jp setsec       ; set setor number
            jp setdma       ; set DMA address
            jp read         ; read disk
            jp write        ; write disk
            jp listst       ; return list status
            jp sectran      ; sector translate
            jp conost	    ; console output ready
            jp auxist	    ; aux input is ready
            jp auxost	    ; aux output is ready
            jp devtbl	    ; device table
            jp devini	    ; devince init
            jp drvtbl	    ; drive table
            jp multio	    ; multi block I/O
            jp flush	    ; flush data to disc
            jp move	    ; block move (including banking)
            jp time	    ; get current data and time into SCB
            jp selmem	    ; select memory bank. Special: preserve regs
            jp setbnk	    ; set the bank for the next read/write sector
            jp xmove	    ; set up for cross bank move
            jp userf	    ; extended BIOS
            jp 0	    ; reserved
            jp 0	    ; reserved

; disk parameter header (16 bytes for each drive), see page 6-28 in CP/M 2.2
; operating system manual
; CP/M 3 style disk parameter header
;
; We keep private data in front of the dph pointer
            dw write_ide
            dw read_ide
dpbase0:
            ; disk 0 (A)
            dw 0            ; sector translation table (0 = no translation)
	    db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	    db 0            ; Media flag
            dw dpblkb       ; DPB (disk parameter block)
            dw 0	    ; CSV (unique scratch pad used to check for changed disks)
            dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	    dw 0FFFEh	    ; Directory buffer control block (auto assign)
	    dw 0FFFEh       ; Data BCB
            dw 0FFFEh       ; HASH
            db 00h          ; HASH bank
            ; end of disk 0

            dw write_ide
            dw read_ide
dpbase1:
            ; disk 1 (B)
            dw 0            ; sector translation table (0 = no translation)
	    db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	    db 0            ; Media flag
            dw dpblk        ; DPB (disk parameter block)
            dw 0            ; CSV (unique scratch pad used to check for changed disks)
            dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	    dw 0FFFEh	    ; Directory buffer control block (auto assign)
	    dw 0FFFEh       ; Data BCB
            dw 0FFFEh       ; HASH
            db 00h          ; HASH bank
            ; end of disk 1

            dw write_ide
            dw read_ide
dpbase2:
            ; disk 2 (C)
            dw 0            ; sector translation table (0 = no translation)
	    db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	    db 0            ; Media flag
            dw dpblk        ; DPB (disk parameter block)
            dw 0	    ; CSV (unique scratch pad used to check for changed disks)
            dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	    dw 0FFFEh	    ; Directory buffer control block (auto assign)
	    dw 0FFFEh       ; Data BCB
            dw 0FFFEh       ; HASH
            db 00h          ; HASH bank
            ; end of disk 0

            dw write_ide
            dw read_ide
dpbase3:
            ; disk 3 (D)
            dw 0            ; sector translation table (0 = no translation)
	    db 0,0,0,0,0,0,0,0,0  ; BDOS scratch area
	    db 0            ; Media flag
            dw dpblk        ; DPB (disk parameter block)
            dw 0            ; CSV (unique scratch pad used to check for changed disks)
            dw 0FFFEh       ; ALV (unique scratch pad for allocation information)
	    dw 0FFFEh	    ; Directory buffer control block (auto assign)
	    dw 0FFFEh       ; Data BCB
            dw 0FFFEh       ; HASH
            db 00h          ; HASH bank
            ; end of disk 1


dphtab	    dw dpbase0		; A:
	    dw dpbase1		; B:
	    dw dpbase2          ; C:
	    dw dpbase3		; D:
	    dw 0		; GenCPM requires the rest are here and 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0
	    dw 0

ndisks      equ 4               ; number of disks we defined

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
	    db 2	    ; PSH - 512 byte sectors
	    db 3	    ; PHM - 512 byte sectors
;
; non boot volumes
;
dpblk:
            dw 1024         ; SPT: number of 128 byte sectors per track
            db 5            ; BSH: block shift factor (see manual for table)
            db 31           ; BLM: block mask (see manual for table)
            db 1            ; EXM: extent mask (see manual for table, using entries
			    ; marked N/A turns out to be a bad idea!)
            dw 2015         ; DSM: (disk bytes / block bytes) - 1,
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

;
;	For now and testing this will do fine
;
chrtbl:
	    db 'UART0 '			; device 0
	    db MB_INOUT + MB_SERIAL
	    db BAUD_NONE
	    db 'UART1 '			; device 1
	    db MB_INOUT + MB_SERIAL
	    db BAUD_NONE

	    db 0	    ; End of table

scratch:
	    ds 256	    ; Provide a boot/wboot time stack and also a scratch
			    ; work space for bank copies
bootstack:

; bios functions follow
boot:       
	    ; Hardware initialization was mostly done by firmware
	    ; On entry we expect the UARTs configured and the CF in 8bit
	    ;
	    ; Set up the banking. We are currently in CP/M bank 0 which is
	    ; our alternate bank. Begin by adjusting the common partitioning
	    ; as the loader left itself a hole.
	    ld a,2
	    out (0eeh),a
	    ld a,0d0h
	    out (0efh),a	; common 0000-0FFF, E000-FFFF
	    ld a,3
	    out (0eeh),a	; and point at the right controls
            ; perform standard CPM initialisation
	    ld sp, bootstack
            xor a
	    call selmem
	    xor a
            ld (iobyte), a
            ld (cdisk), a
            ld a, 128             ; UART 0
            ld (CIVEC+1), a
            ld (COVEC+1), a
            ld a, 64              ; UART 1
            ld (AIVEC+1), a
            ld (AOVEC+1), a
            ld a, 64
            ld (LOVEC+1), a

            ; say hello before we switch to bank 1
            ld hl, bootmsg
            call strout
	    ld a, 0c3h	    ; put the IRQ vector in all banks
	    ld (38h), a
	    ld hl, clockint
	    ld (39h), hl   ; write a copy into RST 38
	    im 1
	    ld a, 1
	    call selmem
	    ld a, 0c3h	    ; put the IRQ vector in all banks
	    ld (38h), a
	    ld hl, clockint
	    ld (39h), hl   ; write a copy into RST 38
	    xor a
	    call selmem	    ; back to bank 0 as clockinit is banked
            ei
            jr gocpm

wboot:    
	    ld sp, bootstack

gocpm:
	; Remember in banked mode we need to write these into bank 1 for
	; CCP to use
	    ld a, 1
	    call selmem
            ld a, 0c3h      ; 0xc3 is a jmp instruction
            ld (0), a       ; write JMP instruction at 0x0000
            ld (5), a       ; write JMP instruction at 0x0005
            ld hl, wboote
            ld (1), hl      ; write vector for warm boot at 0x0001, 0x0002.
            ld hl, (MXTPA)  ; BDOS entry point
            ld (6), hl      ; write vector for BDOS at 0x0006, 0x0007.
	    xor a
	    call selmem
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
	    jr nz, openok   ; opened CCP.COM ok
	    ld hl, noccp
	    call strout	    ; 
	    call conin
	    jr ccpload
readfail:   ld hl, badccp
	    call strout	    ; 'try again'
	    call conin
	    jr ccpload

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
	    jr nz,readfail	    ; EOF is good
ccpok:
            ld bc, 0080h    ; default DMA address
            call setdma     ; configure DMA
	    ld a, 1	    ; single sector I/O
	    ld (MLTIO), a   ; set default blocking
	    call selmem	    ; CCP is in bank 1
            ld a, (cdisk)   ; get current disk
            ld c, a         ; send to ccp
            jp 0100h        ; and we're off!

ccpfcb:	    db 1
	    db 'CCP     COM'
ccpext:	    db 0,0,0
ccprc:	    db 0
	    db 0,0,0,0,0,0,0,0
	    db 0,0,0,0,0,0,0,0
fcbnr:	    db 0,0,0
	    db 0,0,0

noccp:	    db 'CCP.COM not found',10,13,0
badccp:	    db 'CCP.COM read failed',10,13,0

;
;	CP/M 3 supports device redirection. All the console type ops become
;       the sum of the devices assigned.
;
;	This looks uglier but it actually makes life simple as all the
;	aux and reader stuff just becomes calls to the same code with
;	the right vector loaded
;
;
;	Supporting devices (here so JR reaches)
;
list:       ; write character to listing device (we don't have one!)
            ld a, (LOVEC+1)
            jp outwrite

listst:     ; return list device status
            ld a, (LOVEC+1)
            jp outstatus

auxout:      ; write character to the aux device
            ld a, (AOVEC+1)
            jp outwrite

auxin:      ; read character from the aux device
            ld a, (AIVEC+1)
            jr inread

auxist:	    ; auxiliary is ready for input
            ld a, (AIVEC+1)
            jr instatus

auxost:	    ; auxiliary is ready for output
            ld a, (AOVEC+1)
	    jp outstatus

;
;	Console and helpers
;
const:
            ld a, (CIVEC+1)

            ;
            ;	Implement all our input status methods with I/O
            ;   redirection.
            ;
instatus:   ld l, a
            bit 7, l
            jr z, no_st_uart0
            in a, (SIOACmd)
            bit 0, a
            jr nz, const_ready
no_st_uart0:
            bit 6, l
            jr z, const_done
            in a, (SIOBCmd)
            bit 0, a
const_done:
	    ld a, 0
	    ret z
const_ready:
            ; we're ready
	    ld a,255
            ret
            
conin:      ; read character from console into A; wait if no character ready
            ld a, (CIVEC+1)
            ;
            ;	Implement all our input reading methods with I/O
            ;   redirection.
            ;
inread:     ld e, a
            bit 7, e
            jr z, conin_u1
conin_try:  in a, (SIOACmd)
            bit 0, a
            jr z, conin_u1 ; keep waiting if no character ready
            in a, (SIOAData) ; read character
conin_fix:  ; fix backspace
            cp 7fh ; backspace?
            ret nz
            ld a, 8 ; ctrl-h
            ret
conin_u1:   bit 6, e
            jr z, conin_try
            in a, (SIOBCmd)
            bit 0, a
            jr z, conin_try ; keep waiting if no character ready
            in a, (SIOBData) ; read character
            jr conin_fix


conost:     ; check if console is ready for output (CPM 3 onwards)
            ld a, (COVEC+1)
            ;
            ;	Implement all our output status methods with I/O
            ;   redirection.
            ;
outstatus:  ld l, a
conost_try: bit 7, l
            jr z, conost_nou0
	    in a, (SIOACmd)
	    bit 2,a
	    jr nz, conost_done
conost_nou0:bit 6, l
            jr z, conost_done
	    in a, (SIOBCmd)
	    bit 2,a
conost_done:
	    ld a,0
	    ret z
	    dec a
	    ret

conout:     ; write chracter from C to console
            ld a, (COVEC+1)
            ;
            ;	Implement all our output methods with I/O
            ;   redirection.
            ;
outwrite:   ld l, a
            bit 7, l
            jr z, conout_nou0
u0_wait:    in a, (SIOACmd)
            bit 2, a
            jr z, u0_wait ; loop again if transmitter is busy
            ld a, c
            out (SIOAData), a ; transmit character
conout_nou0:
            bit 6, l
	    ret z
u1_wait:    in a, (SIOBCmd)
            bit 2, a
            jr z, u1_wait ; loop again if transmitter is busy
            ld a, c
            out (SIOBData), a ; transmit character
            ret

seldsk:     ; select disk indicated by register C
            ld a, c
	    ld hl,0
            cp ndisks
            ret nc  ; return (with error code) if C >= ndisks ie illegal drive
	    add a
	    ld l,a
	    ld de, dphtab    ; find this disk in dphtab
	    add hl, de
	    ld e,(hl)
	    inc hl
	    ld d,(hl)
	    ex de,hl
	    ld a, l	     ; if the entry is 0 return 0 in hl
	    or h
	    ret z
	    ld a, c	     ; if not also set curdisk
            ld (curdisk), a  ; store current disk
            ld (diskptr), hl ; store the disk pointer
            ret

home:       ld c, 0
            ; fall through into seltrk
seltrk:     ; set track given by register BC
            ld a, c
            ld (curtrack), a
            ret

setsec:     ; set sector given by register BC
	    ; for CP/M 3 this is a *physical* sector
            ld (cursector), bc
            ret

sectran:    ; logical to physical sector translation
            ; HL=BC ie 1:1 mapping (no translation)
            ; in CP/M 3 this is physical sectors but as we don't translate
	    ; we don't care
	    ; we will need to check this if we ever add SD support
            ld h, b
            ld l, c
            ret

devtbl:	    ; device table, 0 if not implemented
	    ; we don't really implement it fully but we will want it for
	    ; baud rate setting later
	    ld hl, chrtbl
	    ret

devini:	    ; re-initialize device C, called on baud/mode change
            ; nothing to do for now
            ret

drvtbl:	    ; drive table - return drive table in HL or 0
	    ; pointer to an array of 16 DPH blocks
	    ; does not *have* to be in common space (but usually is)
	    ; must start with ld hl, address (GENCPM snoops this!)
	    ld hl, dphtab
	    ret

multio:	    ; BDOS is going to transfer consective sectors
            ; basically a deblocker hint. We don't care.
	    xor a
            ret

flush:      ; Flush any pending data to disc.
            xor a
            ret

move:       ; copy BC bytes from DE->HL.
	    ; FIXME: add support for xmove
            ex de, hl
            ldir
            ex de,hl
            ; return de,hl as next bytes to copy 
            ret

xmove:      ; set the next move to copy between banks. C = source, B = dest
            ; CP/M weirdomatic warning - if unimplemented this must just be
            ; a ret. This is really meant for platforms that can do fast
            ; direct interbank copies - eg via a DMA engine
	    ; Not supported
            ret

selmem:	    ; Set active bank - must preserve registers
	    ; Bank 0 is our alternate partial bank (CP/M itself)
	    ; Bank 1 is our A16 locked bank (TPA and common)
	    push af
	    rla
	    and 2
	    xor 2
	    push bc
	    ld c,a
	    in a,(0efh)
	    and 0fdh
	    or c
	    out (0efh),a	    
	    pop bc
	    pop af
            ret

setbnk:     ; set the bank to be used for the next read/write sector
            ; BDOS calls SETDMA, SETBNK (so we can pick the MMU setup based
            ; on the address)
	    ld (curbank), a
            ret

setdma:     ; set DMA address given by BC
	    ; In CP/M 3 this can be > 128 bytes long
            ld (curdmaaddr), bc
            ret

read:       ld hl, (diskptr)
diskop:     dec hl
            ld d, (hl)
            dec hl
            ld e, (hl)
            ex de, hl
            jp (hl)

write:      ld hl, (diskptr)
            dec hl
            dec hl
            jr diskop

read_ide:
            call ide_setup_read
	    jr z, rw_fail
	    ld a, (curbank)
	    call selmem
            inir
	    inir
rw_done:    xor a ; return to bank 0
	    jp selmem


write_ide:  ; write to our IDE disk
            ; In CP/M 3 this is physical sectors
	    ; C is now a re-blocking hint 0 - defer, 1 non-defer, 2 -
            ; deferred write of first sector of new block
            call ide_setup_write
	    ld a, (curbank)
	    call selmem
            otir
	    otir
	    xor a
	    call selmem
	    call ide_wait_done
            jr nz, rw_done
rw_fail:
	    ld a,1
	    ret

time:       ; FIXME: copy TOD clock into BOOT-0x0C
            ; Must preseve HL, DE. If C=0xFF set time
            ret

	    ; The IRQ handler must in common we could be in any bank when
	    ; this is invoked
clockint:   ; Ripple the clock, once a second, only using AF
	    push af
            ; if you add another IRQ do it before the timer, the timer IRQ
            ; timeout handler means clockevent cannot be called as a
            ; subroutine.
	    ld a, (SEC)
	    inc a
	    daa
	    cp 060h
	    jr nc, clockmin
	    ld (SEC), a
clockret:
	    pop af
	    ei
	    ret
clockmin:   xor a
	    ld (SEC), a
	    ld a, (MIN)
	    inc a
	    daa
	    cp 060h
	    jr nc, clockhr
	    ld (MIN), a
	    jr clockret
clockhr:    xor a
	    ld (MIN), a
	    ld a, (HOUR)
	    inc a
	    daa
	    cp 24h
	    jr nc, clockday
	    ld (HOUR), a
	    jr clockret
clockday:   xor a
	    ld (HOUR), a
	    ld a, (DATE)
	    inc a
	    ld (DATE), a	; we can store anyway if wrapped
	    jr z, clockday256
	    jr clockret
clockday256:ld a, (DATE+1)
	    inc a
	    ld (DATE+1), a
	    jr clockret

userf:      ; Extended BIOS call
	    ret

;---------------------------------------------------------------------------------------------------------------
; debug functions (ideally to be removed in final version, if we ever get that far!)
strout:     ; print string pointed to by HL
            push af
            push bc
            push de
stroutl:    ld a, (hl)
            cp 0
            jr z, stroute
            ld c, a
	    push hl
            call conout
            pop hl
            inc hl
            jr stroutl
stroute:    pop de
            pop bc
            pop af
            ret

outnibble:  and 0fh
            cp 10
            jr c, numeral
            add 07h
numeral:    add 30h
            ld c, a
            call conout
            ret

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

;---------------------------------------------------------------------------------------------------------------
; scratch RAM used by BIOS
curbank:    db 0
curdisk:    db 55h
curtrack:   db 55h
cursector:  dw 5555h   ; 16bit in CP/M 3
curdmaaddr: dw 5555h
diskptr:    dw 0        ; current disk dpb entry

;
;	GENCPM places cseg into the common area and dseg into bank 0
;
;	Bank 0 is allowed to contain certain types of driver code with
; 	strict limitations (see CP/M 3 system guide).
;
	dseg

bootmsg:    db 10, 13
	    db 'Micro80 CP/M 3.x Banked BIOS 0.03'
	    db 10,13
	    db 'Alan Cox 2019-10-01'
	    db 10,13,10,13,0

clockinit:
;
;	TODO - set up the CTC chain
;
	    ret


ide_map:
;
;   Block addressed
;   00000000 00000000 DDTTTTTT SSSSSSSS
;
;
	    ld a, (curdisk)
	    rra
	    rra
	    ld h,a
            ld a, (curtrack)	  ; track forms the upper 8bits
            or h
	    ld h,a
            ld a, (cursector)     ; sector forms the low 8bits
	    ld l,a
	    ld de,0		  ; will need updating for > 4 drives
            ret			  ; done


;
;	Read LBA EHL from current drive (we don't support multiple physical disks)
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
	jr z,readdrq
	ld bc,DATA	; expected by caller
	ld hl,(curdmaaddr)
	ret

ide_setup_write:
	call ide_map	; Get an LBA
	ld a,l		;
	out (LBA_0),a	; write LSB CF LA address
	ld a,h
	out (LBA_1),a
	ld a,e
	out (LBA_2),a
	ld a,1		; read one sector
	out (COUNT),a	; write to sector count with 1
	ld a,30h	; CF write command
	out (CMD),a
	ld de,4000h
	jr readdrq	; check drq bit set before writing

ide_wait_done:
	ld de,4000h
	; check busy bit for write completion
readbsy:
	; spin on CF status busy bit
	dec de
	ld a,d
	or e
	ret z
	in a,(CFSTATUS)	; read CF status 
	and 80h		; mask off all except busy bit
	jr nz,readbsy
	inc a		; NZ
	ret
