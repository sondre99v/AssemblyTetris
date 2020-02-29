/*
 * initialization.asm
 *
 *  Created: 28-02-2020 12:09:59
 *   Author: Sondre
 */ 

rjmp main

; Interrupt Vector Table
.org 0x08 rjmp ISR_TCA0_OVF

.dseg
.align 0x100
display_data: .byte 16
line_index: .byte 1

.cseg
ISR_TCA0_OVF:
	push ZL
	push ZH
	push r16

	ldi ZH, HIGH(display_data)
	lds ZL, line_index
	ld r16, Z
	out VPORTC_OUT, ZL
	out VPORTB_DIR, r16
	
	inc ZL
	andi ZL, 0x0F
	sts line_index, ZL

	pop r16
	pop ZH
	pop ZL

	ldi r18, TCA_SINGLE_OVF_bm
	sts TCA0_SINGLE_INTFLAGS, r18
	reti

mcu_init:
	; Set clock source to 20 MHz, with div 2 prescaler
	ldi r16, CPU_CCP_IOREG_gc
	out CPU_CCP, r16
	ldi r16, CLKCTRL_PEN_bm
	sts CLKCTRL_MCLKCTRLB, r16

	; Setup TCA0 for periodic interrupt ev. 0x1000 clock cycles
	ldi r16, TCA_SINGLE_OVF_bm
	sts TCA0_SINGLE_INTCTRL, r16
	ldi r16, 0x10
	sts (TCA0_SINGLE_PER+1), r16
	ldi r16, TCA_SINGLE_CLKSEL_DIV2_gc | TCA_SINGLE_ENABLE_bm
	sts TCA0_SINGLE_CTRLA, r16
	
	; Set all PB-pins to GND, but disable driver for now
    clr r16
	out VPORTB_DIR, r16
	out VPORTB_OUT, r16

	; Setup PA1-3 for button input
	ldi r16, PORT_PULLUPEN_bm
	sts PORTA_PIN1CTRL, r16
	sts PORTA_PIN2CTRL, r16
	sts PORTA_PIN3CTRL, r16
	
	; Setup PC0-3 as outputs to address decoder
	ldi r16, 0x0F
	out VPORTC_DIR, r16
	ldi r16, PORT_INVEN_bm
	sts PORTC_PIN0CTRL, r16
	sts PORTC_PIN1CTRL, r16
	sts PORTC_PIN2CTRL, r16
	sts PORTC_PIN3CTRL, r16
	
	sei
	ret
