;
;	An initial Z8 test ROM
;

		.abs
		.org 0
		.export loop
vectors:
	.word irq0
	.word irq1
	.word irq2
	.word irq3
	.word irq4
	.word irq5
start:
	ld 246,#1	; only P2 imput is MISO
	ld 247,#0x51	; no parity P3.7 and P3.0 are serial
			; P3.4 is DM P3.2 input and 3.5 output
			; push pull
	ld 2,#0xAA	; pattern for debug, ensure IOCS and CTS are low
	ld r8,#0xFF	; Write to 0xFF80 (lights)
	ld r9,#0x80
	ld r10,#0xAA
	lde @rr8,r10	; lights to 0xAA

	ld 245,#0x0D	; prescaler 3, continuous
	ld 244,#1	; count 1		19200 baud
	ld 241,#3	; enable

	ld 255,#0xF0	; stack
	ld 251,#0x18	; serial interrupts only

	ld 240,#'X'
	ei
loop:
	jp loop


irq0:
irq1:
irq2:
	iret
irq3:
	ld 128,240	; RX byte - discard
	iret
irq4:
	ld 240,#'X'	; keep sending
	iret
irq5:
	iret
