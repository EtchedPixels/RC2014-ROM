SCBBASE	       equ 0FE00h   ; 0FExx is magically relocated by GENCPM
CIVEC          equ 0FE22h   ; console redirection vector (input)
COVEC	       equ 0FE24h   ; console redirection vector (output)
AIVEC	       equ 0FE26h   ; auxiliary redirection vector (input)
AOVEC	       equ 0FE28h   ; auxiliary redirection vector (output)
LOVEC	       equ 0FE2Ah   ; list redirection vector (output)
BNKBF	       equ 0FE35h   ; 128 byte buffer for banked bios (bank only)
CRDMA          equ 0FE3Ch   ; current DMA address
CRDSK          equ 0FE3Eh   ; current disk
VINFO          equ 0FE3Fh   ; BDOS 'INFO' word
RESEL          equ 0FE41h   ; FCB flag
FX             equ 0FE43h   ; BDOS function code for error messages
USRCD          equ 0FE44h   ; Current user code
MLTIO          equ 0FE4Ah   ; Current multi-sector I/O counter
ERMDE          equ 0FE4Bh   ; BDOS error mode
ERDSK          equ 0FE51h   ; BDOS error byte
MEDIA          equ 0FE54h   ; Set by BIOS for "open door"
BFLGS          equ 0FE57h   ; BDOS message size flag
DATE           equ 0FE58h   ; Days since 1 Jan 78
HOUR           equ 0FE5Ah   ; Hour of day (BCD)
MIN            equ 0FE5Bh   ; Minute (BCD)
SEC            equ 0FE5Ch   ; Second (BCD)
ERJMP          equ 0FE5Fh   ; BDOS error message jump
MXTPA          equ 0FE62h   ; Top of TPA

;
;	These *must* be a separate file so that we get relocation records
;	for them, or GENCPM won't know about the relocations it needs to
;	adjust.
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
