/*
 * main.asm
 *
 *  Created: 29-02-2020 23:39:24
 *   Author: Sondre
 */ 

.cseg

rjmp start

.include "initialization.asm"
.include "utilities.asm"

; State of the falling piece
.def r_piece_i = r23
.def r_piece_x = r24
.def r_piece_y = r25

; Variable to generate pseudo-random numbers
.def r_rngvar = r0

; 4x4 bitfields of all pieces, in all rotations
; Last two bits of MSN indicates how to change
; the index when the piece is rotated
;   (00: 0, 01: +1, 10: -1, 11: -3)
.align 0x100
pieces:
.dw \
    /* T */ 0x1464, 0x14E0, 0x14C4, 0x30E4, \
    /* L */ 0x144C, 0x10E2, 0x1644, 0x38E0, \
    /* J */ 0x1446, 0x12E0, 0x1C44, 0x30E8, \
    /* Z */ 0x1462, 0x206C, \
    /* S */ 0x1264, 0x20C6, \
    /* I */ 0x5444, 0x20F0, \
    /* O */ 0x0066

; Array containing the indices of the first
;   rotation of each piece. Used to get
;   equal distribution of pieces from the
;   rng
piece_index:
	.db 0, 4, 8, 12, 14, 16, 18, 0
	; (Last zero is only padding)


start:
	rcall mcu_init
	rcall display_clear

	ldi r_piece_i, 0
	ldi r_piece_x, 4
	ldi r_piece_y, 0

	rcall piece_draw

main_loop:
	rcall wait_long
	rcall rng_iterate

	rcall piece_clear
	
	; Handle player input
    in r16, VPORTA_IN

	; Backup piece position
	mov r17, r_piece_x
    sbrs r16, 1
		inc r_piece_x
    sbrs r16, 3
		dec r_piece_x
	rcall piece_intersects
	cpi r22, 0
	breq main_if1
		; Player input led to intersection
		mov r_piece_x, r17
	main_if1:
	
	; Backup piece rotation
	mov r17, r_piece_i
	sbrs r16, 2
		rcall piece_rotate
	rcall piece_intersects
	cpi r22, 0
	breq main_if2
		; Player input led to intersection
		mov r_piece_i, r17
	main_if2:

	
	; Do drop
	inc r_piece_y
	rcall piece_intersects
	cpi r22, 0
	breq main_if3
		; Drop led to intersection
		dec r_piece_y
		rcall piece_draw
		
		ldi ZH, HIGH(piece_index << 1)
		ldi ZL, LOW(piece_index << 1)
		clr r16
		add ZL, r_rngvar
		adc ZH, r16
		lpm r_piece_i, Z
		ldi r_piece_x, 4
		ldi r_piece_y, 0
	main_if3:

	rcall piece_draw
rjmp main_loop


; Clears the entire display
display_clear:
    push r16
    push XL
    push XH

    clr r16
    ldi XH, HIGH(display_data)
	clr XL

    display_clear_loop:
        st X+, r16
        cpi XL, 16
        brne display_clear_loop

    pop XH
    pop XL
    pop r16
ret


; Retreives a line from the current piece,
;   shifted to the correct position
; Argument in r22 indicates which line to fetch,
;   and the line is returned in r22
; If the line intersects the sides r21, will be
;   non-zero
piece_get_line:
	push r16
	push XL
	push XH
	push ZL
	push ZH

	; Set Z to address the current piece bitfield
	ldi ZH, HIGH(pieces << 1)
	mov ZL, r_piece_i
	lsl ZL

	; Get second byte if r22 > 1
	sbrc r22, 1
		inc ZL

	; Get byte
	lpm r16, Z

	; Get high nibble if r22 is 1 or 3
	sbrc r22, 0
		swap r16
	andi r16, 0xF

	; Mask out rotation sequence information
	cpi r22, 3
	brne piece_get_line_if_1
		andi r16, 0xC
	piece_get_line_if_1:

	; Move the line into r22
	mov r22, r16
	; Move x-pos into r16 to do the shifting
	mov r16, r_piece_x
	subi r16, 2

	; Shift right if position is less than 2
	brcs piece_get_line_shr

	; r21 will be set non-zero if any bits are
	;   shifted out of the line
	clr r21

	; Loop to shift left
	piece_get_line_loop1:
		cpi r16, 0
		breq piece_get_line_exit
		lsl r22
		brcc piece_get_line_if1
			ori r21, 1
		piece_get_line_if1:
		dec r16
		rjmp piece_get_line_loop1

	; Shift right once or twice
	piece_get_line_shr:
	lsr r22
	sbrs r16, 0
		lsr r22
	brcc piece_get_line_if2
		ori r21, 1
	piece_get_line_if2:

	piece_get_line_exit:
	pop ZH
	pop ZL
	pop XH
	pop XL
	pop r16
	rcall rng_iterate
ret


; Draws the current falling piece on the board
piece_draw:
	push r16
	push r17
	push r22
	push XL
	push XH
	
	ldi XH, HIGH(display_data)
	mov XL, r_piece_y

	clr r16
	piece_draw_loop:
		; Fetch line from board into r17
		ld r17, X

		; Fetch line from piece into r22
		mov r22, r16
		rcall piece_get_line

		; Or them together
		or r17, r22

		; Store result in board
		st X+, r17

		inc r16
		cpi r16, 4
		brlt piece_draw_loop

	pop XH
	pop XL
	pop r22
	pop r17
	pop r16
ret


; Draws the current falling piece on the board
piece_clear:
	push r16
	push r17
	push r22
	push XL
	push XH
	
	ldi XH, HIGH(display_data)
	mov XL, r_piece_y

	clr r16
	piece_clear_loop:
		; Fetch line from board into r17
		ld r17, X

		; Fetch line from piece into r22
		mov r22, r16
		rcall piece_get_line

		; And out the piece
		com r22
		and r17, r22

		; Store result in board
		st X+, r17

		inc r16
		cpi r16, 4
		brlt piece_clear_loop

	pop XH
	pop XL
	pop r22
	pop r17
	pop r16
ret


; Check if the current piece intersects the board
; Return value given in r22 (0 if no intersection)
piece_intersects:
	push r16
	push r17
	push r20
	push r21
	push XL
	push XH
	
	ldi XH, HIGH(display_data)
	mov XL, r_piece_y
	
	; r20 accumulates intersection points
	clr r20

	clr r17
	piece_intersects_loop:
		; Set board-line to full, then load value
		;   from board if the index is in range
		ldi r16, 0xFF
		cpi XL, 16
		brge piece_intersects_if1
			ld r16, X+
		piece_intersects_if1:

		; Fetch line from piece into r22
		mov r22, r17
		rcall piece_get_line
		
		; r21 is non-zero if line intersected
		;   the sides
		or r20, r21

		; Check for intersections with board
		and r16, r22

		; Add intrsecions to result
		or r20, r16

		inc r17
		cpi r17, 4
		brlt piece_intersects_loop

	mov r22, r20
	pop XH
	pop XL
	pop r21
	pop r20
	pop r17
	pop r16
ret


; Get the index of the rotated version of the
; current piece. Returned in r22.
piece_get_rotated_index:
	push r16
	push ZL
	push ZH
	
	; Set Z to address the current piece bitfield
	ldi ZH, HIGH(pieces << 1)
	mov ZL, r_piece_i
	lsl ZL

	; Get second byte
	inc ZL
	
	; Load byte, and get the rotation-information
	lpm r16, Z
	andi r16, 0x30

	mov r22, r_piece_i
	sbrc r16, 4
		inc r22
	sbrc r16, 5
		dec r22
	cpi r16, 0x30
	brne piece_get_rotated_index_exit
		subi r22, 3
	piece_get_rotated_index_exit:
	pop ZH
	pop ZL
	pop r16
ret


; Rotate the current piece by advancing r_piece_i
piece_rotate:
	push r22
	
	; Get index of piece to load (in r22)
	rcall piece_get_rotated_index

	; Load it
	mov r_piece_i, r22

	pop r22
	rcall rng_iterate
ret

rng_iterate:
	push r16
	inc r_rngvar
	ldi r16, 7
	cp r_rngvar, r16
	brne rng_iterate_if1
		clr r_rngvar
	rng_iterate_if1:

	pop r16
ret
