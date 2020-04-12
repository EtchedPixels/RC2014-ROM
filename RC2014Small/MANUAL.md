# New ROM and CP/M 3 For RC2014, SC108 and SC114 Systems

## Features

This ROM provides a monitor, and a clean interface to a CP/M BIOS, most of
which is paged in with the ROM. It allows the RC2014 classic, SC108 and
SC114 systems to use the same CP/M image, and it abstracts the hardware
interfaces so that the same CP/M image and CF card works for all the
systems.

## Supported Hardware

Systems:
* RC2014 with paged ROM and 64K RAM
* RC2014 with 512K/512K banked memory
* Small Computer Central SC108
* Small Computer Central SC114

Console Serial:
* 16550A at 0xA0
* ACIA at 0xA0
* Z80 SIO/2 at 0x80

Aux/List:
* Z80 SIO/2 at 0x80 (second port)

Disk Interface:
* IDE CF adapter at 0x10
* PPIDE at 0x20

Only one serial and disk interface is supported at a time. You cannot mix
and match.

## Monitor

On powering up the system enters the boot monitor. Where speed is settable
(16550A) the baud rate will be 38400 baud. For the ACIA and Z80 SIO it will
depend upon the clock being used, but is usually 115200.

The system displays an 'R' as early as possible in boot up so that problems
can be identified. The rest of the "C2014" is displayed once the system has
initialized the serial and memory interface. This will be followed by the
console serial type and the disk interface type and a prompt.

Commands are single letter with one or more arguments. All values are in
hexadecimal.

### B drive
Boot from a drive. The boot command knows how to boot a modern image and how
to tackle the legacy CP/M images, including working around the iobyte bug.
If no drive is given the default is C. Some software can only boot from
drive C at this point.

### G addr
Jump to an address. For example if you have BASIC in the second 8K of the
ROM then you can G 8000.

### I port
Read from an I/O port. A full 16bit address I/O read is done.

### O port value
Write to an I/O port. A full 16bit address I/O read is done.

### R addr
Read memory at addr. Eight or sixteen bytes will be dumped depending upon
the display width. Hitting return at the monitor prompt will dump the next
sixteen.

### W addr value
Write a byte to memory.

## Diagnostics

If you see only an 'R' then the system started but was unable to make
progress. This may be a BIOS software bug at this point but most likely your
RAM card is not working correctly.

If you see the message "RC2014 with no paging. Not supported" the ROM was
unable to page out. This will happen if you use the ROM on a system without
pageable RAM, or if you do not have the needed link between the pageable ROM
and paged RAM cards present.

The "bad hex" message is displayed if you failed to provide a valid
hexadecimal value on a monitor command line.

The "bad disk" error is displayed if the disk device did not respond
correctly. This will also be seen if you try to boot without a disk or
suitable interface present.

"Not bootable" indicates that the disk image does not appear to contain
either a legacy CP/M for RC2014, or a New ROM style boot block. Note that
the ROM cannot currently boot Fuzix images for the SC108/SC114.

"Disk error" usually suggest that a disk was detected but was not giving
sensible results. With the CF adapter the choice of CF card can be
problematic so this error may also indicate an unsuitable CF card.

## CP/M 3

To start CP/M 3 ensure CP/M 3 is on the first drive and give the "B"
command.

CP/M 3 uses the banked ROM to provide most of the BIOS. This gives a 53K TPA
which is larger than that of the 'classic' CP/M 2.2 provided with RC2014,
despite the extra functionality. In addition as most of the firmware is in
paged ROM this will not shrink much as video, keyboard and floppy are added.

Each drive is 32MB and they use the same format as CP/M 3 on the 8085 card,
and various of Bill Shen's boards. The layout is chosen so that all the
track and sector conversion to modern disk logical block mapping requires
no multiplications or complex shifts.

The first disk is mapped to drives C and D (2 32MB partitions), the second
to E and F. Drive A & B are reserved for the floppy disk interface once
added.

## Software Interface

The firmware occupies the ROM space from 0000h-1FFFh. It requires RAM from
8000h upwards. The top 512 bytes are reserved for the firmware to use.

The 'B' command loads the first 24 sectors of the disk from 8000h and then
inspects them to see if they are a legacy CP/M image or something else. If
sector 1 (that is the second sector) starts with the byte 31h (LD SP,nnnn)
then it will be considered bootable and a jump to 8200h (sector 1) will be
made. The code is invoked with the ROM mapped in.

The ROM BIOS provides the CP/M BIOS functions from wboot upwards in CP/M 3
format. As these systems are not banked XMOVE, SETBLK, and SELMEM do
nothing. Because the CP/M generation code needs to see the DPB blocks the
implementation of seldsk returns instead with B = 0 if it failed or B = 1 if
it worked. The caller needs to provide the DPB and set HL appropriately in
each case (including errors).

The ROM functions READ and WRITE know how to page the ROM back out during
disk I/O so can be used with any address. The MOVE function does not because
it makes no sense to use it when you can implement it in the CP/M BIOS
itself in less bytes than the call.

An additional set of routines are provided via vectors at fe00-fe08h

### FE00h

This routine pages the ROM in if it is currently out. The behaviour in other
cases is undefined. Only the AF registers will be modified.

### FE03h

This routine pages the ROM out if it is currently in. The behaviour in other
cases is undefined. Only the AF registers will be modified.

### FE06

This routine should only be used when the ROM is paged out. It pages the ROM
in and calls the routine at the address given in IX. All other registers on
entry to the function are as they were when this helper is called. On return
the ROM is paged back out and all the registers returned are as they were
when the called function returned. This is the primary method for calling
BIOS functions when the ROM is mapped.

Certain functions are also available with the ROM mapped via RST calls. This
is intended to space save in the ROM. These functions may change.

## CP/M Functionality Not Available In The BIOS

At this point in time the BIOS does not implement the extensions for DEVTBL
and DEVINI. TIME is also not yet provided but a future BIOS will add support
for the RC2014 RTC card.

SELMEM, SETBLK and XMOVE not provided as they are only relevant to banked CP/M.
Only the 512K/512K systems support banked CP/M and they already have ROMWBW.

No services via USERF are provided at this time.

