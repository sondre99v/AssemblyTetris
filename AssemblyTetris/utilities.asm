/*
 * utilities.asm
 *
 *  Created: 28-02-2020 16:23:53
 *   Author: Sondre
 */ 

wait_long:
	push r16
	push r17
	push r18
	ldi r16, 0xE0
	clr r17
	clr r18
	wait_long_l3:
		wait_long_l2:
			wait_long_l1:
				inc r18
				brne wait_long_l1
			inc r17
			brne wait_long_l2
		inc r16
		brne wait_long_l3

	pop r18
	pop r17
	pop r16
	ret
