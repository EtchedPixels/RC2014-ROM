;
;	We start with everything ROM but do not panic the 816 unlike the 02
;	can actually cope very nicely with this situation
;
;	We start with the latch at 0 - so the 64K ROM is mapped at $0000
;	and $10000
;

		.segment "CODE"

		.p816
		.i16
		.a16

start:
		; 65C816 mode
		clc
		xce
		rep #$30
		sep #$20

		.a8
		.i16

		lda #$80
		sta $808000	;	Debug lights

		lda #3
		sta $80A000
		dec
		sta $80A000
		lda #$96
		sta $80A000	;	8N1 RTS low

		lda #'R'
		sta $80A100	;	Print an 'R' as early as we can

		jmp f:$10000+go
go:
		lda #08
		sta $803800	;	put RAM in the low 64K

		; Running from bank 1 ROM with RAM in bank 0
		ldx #$FFFF
		txs
		ldx #0
		
		; Now we can start to behave like a sane platform

		ldx #hello
		jsr print

		; Set up the CF adapter

		lda #1
		sta $801100
		lda #$EF
		sta $800017
		jsr wait_ready
		lda #0
		sta $801300
		sta $801400
		sta $801500
		inc
		sta $801200
		lda #$20
		sta $801700
		jsr wait_drq
		ldx #$1000
		ldy #$0100		; CF

		.a16
		rep #$20

		phb

		lda #$100
		mvn #$80,#$0		; from I/O to memory
		ldx #$1000
		lda #$100
		mvn #$80,#$0		; second 256 bytes

		plb

		jsr wait_ready

		ldx #runos

		sep #$20
		.a8

		jsr print

		jmp f:000100

wait_ready:
		lda $801700
		and #$40
		beq wait_ready
		rts

wait_drq:
		lda $801700
		and #8
		beq wait_drq
print_done:		
		rts
print:
		lda $80A000
		and #$02
		beq print
		lda 0,x
		beq print_done
		inx
		sta $80A100
		bra print

dobrk:		ldx #brkerr
		bra doprint
donmi:
		ldx #nmierr
doprint:
		jsr print
die:		bra die


runos:
		.byte "Transferring control to bootstrap loader"
		.byte 13,10,0
hello:
		.byte "C2014 65C816 Extended Memory System."
		.byte 13,10,13,10
		.byte "Booting from compact flash"
		.byte 13,10,13,10
		.byte 0
nmierr:		.byte "NMI"
		.byte 0
brkerr:		.byte "BRK"
		.byte 0

		.segment "VECTORS"
		.word donmi
		.word start
		.word dobrk
