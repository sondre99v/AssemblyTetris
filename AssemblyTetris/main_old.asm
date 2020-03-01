;
; AssemblyTetris.asm
;
; Created: 28-02-2020 11:14:50
; Author : Sondre
;

.dseg
    falling_piece: .byte 4 ; Bitfield of four lines, making up falling piece
    falling_pos:   .byte 1 ; Horizontal position (0-7) of falling piece
    falling_type:  .byte 1 ; Type and rotation of falling piece
    falling_index: .byte 1 ; Vertical position of falling piece


.cseg
.include "tn817def.inc"
.include "initialization.asm"
.include "utilities.asm"

; 4x4 bitfields of all pieces, in all rotations
; Last two bits of MSB indicates how to change the index when the piece is rotated
;   (00: 0, 01: +1, 10: -1, 11: -3)
.align 0x100
pieces:
.dw \
    /* O */ (0x0066|0x000), \
    /* I */ (0x000F|0x100), (0x4444|0x200), \
    /* S */ (0x006C|0x100), (0x2046|0x200), \
    /* Z */ (0x00C6|0x100), (0x4026|0x200), \
    /* T */ (0x2023|0x100), (0x2007|0x100), (0x2026|0x100), (0x0027|0x300), \
    /* J */ (0xC044|0x100), (0x008E|0x100), (0x4064|0x100), (0x200E|0x300), \
    /* L */ (0x6044|0x100), (0x002E|0x100), (0x40C4|0x100), (0x800E|0x300)   



main:
    rcall mcu_init
    rcall display_clear
    
    ldi r21, 7
    rcall piece_spawn

main_loop:
    rcall wait_long


	; Take backup of piece state
	lds r4, (falling_piece+0)
	lds r5, (falling_piece+1)
	lds r6, (falling_piece+2)
	lds r7, (falling_piece+3)
	lds r8, falling_pos
	lds r9, falling_type
	lds r10, falling_index

	rcall piece_clear

	; Do player movement
    in r16, VPORTA_IN
	sbrs r16, 2
		rcall piece_rotate
    ldi r20, 0
    sbrs r16, 1
		ldi r20, 2
    sbrs r16, 3
		ldi r20, 1
    rcall piece_shift

	rcall piece_intersects
	cpi r19, 0 ; If not 0, piece intersects the board, and cannot be here! Load backup
	breq main_if1
		sts (falling_piece+0), r4
		sts (falling_piece+1), r5
		sts (falling_piece+2), r6
		sts (falling_piece+3), r7
		sts falling_pos, r8
		sts falling_type , r9
		sts falling_index, r10
	main_if1:
    
	
	; Do piece drop (TODO: Do every n loops later)
	; Take backup of piece state
	lds r4, (falling_piece+0)
	lds r5, (falling_piece+1)
	lds r6, (falling_piece+2)
	lds r7, (falling_piece+3)
	lds r8, falling_pos
	lds r9, falling_type
	lds r10, falling_index

    rcall piece_lower

	rcall piece_intersects
	cpi r19, 0 ; If not 0, piece intersects the board, and cannot be here! Load backup and lock piece
	breq main_if2
		sts (falling_piece+0), r4
		sts (falling_piece+1), r5
		sts (falling_piece+2), r6
		sts (falling_piece+3), r7
		sts falling_pos, r8
		sts falling_type , r9
		sts falling_index, r10
	main_if2:

	rcall piece_draw

    rjmp main_loop


display_clear:
    push r16
    push XL
    push XH
    clr r16
    clr ZL
    ldi XH, HIGH(display_data)
    display_clear_loop:
        st X+, r16
        cpi XL, 16
        brne display_clear_loop

    pop XH
    pop XL
    pop r16
    ret

; Spawn a piece by initializing all the piece_* variables
;   Argument in r21 indicates which piece to spawn
piece_spawn:
    push r16

    sts falling_type, r21
    clr r16
    sts falling_index, r16
    sts falling_pos, r16

	rcall piece_load

	ldi r20, 0
    rcall piece_draw

    pop r16

    ret

; Load piece into falling_piece array, in position indicated by falling_pos
;   Argument in r21 indicates which piece to load
piece_load:
    push r16
    push r17
    push r18
    push ZL
    push ZH
    push YL
    push YH

    ldi ZH, HIGH(pieces << 1)
    mov ZL, r21
    lsl ZL

    ldi YH, HIGH(falling_piece)
    ldi YL, LOW(falling_piece)
    
	ldi r17, 4
	piece_load_loop:
		lpm r16, Z
		sbrc r17, 0
			inc ZL
		sbrs r17, 0
			swap r16
		andi r16, 0x0F
		cpi r17, 1
		brne piece_load_if1
			andi r16, 0x0C
		piece_load_if1:
		
		lds r18, falling_pos
		cpi r18, 0
		brlt piece_load_loop2_exit

		piece_load_loop2:
			cpi r18, 0
			breq piece_load_loop2_exit
			lsl r16
			dec r18
		rjmp piece_load_loop2
		piece_load_loop2_exit:

		st Y+, r16
		
		dec r17
		brne piece_load_loop

    pop YH
    pop YL
    pop ZH
    pop ZL
    pop r18
    pop r17
    pop r16
	ret
	

; Load piece from falling_piece array to display_data
;   r20[1..0] indicates if piece should be shifted first
;     0: No shift
;     1: Shift right
;     2: Shift left
piece_draw:
    push r16
    push r17
    push r18
    push XL
    push XH
    push YL
    push YH

    ldi XH, HIGH(display_data)
    lds XL, falling_index
    ldi YH, HIGH(falling_piece)
    ldi YL, LOW(falling_piece)
    
    ldi r18, 4
    piece_draw_loop:
        ld r17, X
        ld r16, Y
        sbrc r20, 0
            lsr r16
        sbrc r20, 1
            lsl r16
        or r17, r16
        st Y+, r16
        st X+, r17
        dec r18
        brne piece_draw_loop

    pop YH
    pop YL
    pop XH
    pop XL
    pop r18
    pop r17
    pop r16
    ret

piece_clear:
    push r16
    push r17
    push r18
    push XL
    push XH
    push YL
    push YH

    ldi XH, HIGH(display_data)
    lds XL, falling_index
    ldi YH, HIGH(falling_piece)
    ldi YL, LOW(falling_piece)
    
    ldi r18, 4
    piece_clear_loop:
        ld r17, X
        ld r16, Y+
        com r16
        and r17, r16
        st X+, r17
        dec r18
        brne piece_clear_loop

    pop YH
    pop YL
    pop XH
    pop XL
    pop r18
    pop r17
    pop r16
    ret


; Check if current state of the falling piece intersects the board
;    r19 returns the binary intersection state
piece_intersects:
    push r16
    push r17
    push r18
    push XL
    push XH
    push YL
    push YH

    ldi XH, HIGH(display_data)
    lds XL, falling_index
    ldi YH, HIGH(falling_piece)
    ldi YL, LOW(falling_piece)
    
	clr r19

    ldi r18, 4
    piece_intersects_loop:
        ld r17, X+
        ld r16, Y+
        and r17, r16
		or r19, r17
        dec r18
        brne piece_intersects_loop

    pop YH
    pop YL
    pop XH
    pop XL
    pop r18
    pop r17
    pop r16
	ret


piece_lower:
    push r16

    lds r16, falling_index
    inc r16
    sts falling_index, r16
    
    pop r16
    ret

; Argument in r20
;   1: Shift right
;   2: Shift left
piece_shift:
    push r16
    lds r16, falling_pos
    sbrc r20, 0
        dec r16
    sbrc r20, 1
        inc r16
    sts falling_pos, r16
    pop r16
    ret

piece_rotate:
    push r16
    push ZL
    push ZH
	
    ldi ZH, HIGH(pieces << 1)
    mov ZL, r21
    lsl ZL
	ori ZL, 1

	lpm r16, Z
	andi r16, 0x03
	
	; r16=1: r21++, r16=2: r21--, r16=3: r21-=3
	sbrc r16, 0
		inc r21
	sbrc r16, 1
		dec r21
	inc r16
	sbrc r16, 2
		subi r21, 3

	rcall piece_load

	pop ZH
	pop ZL
	pop r16

    ret