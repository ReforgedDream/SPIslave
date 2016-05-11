; Created: 30.03.2016 10:27:56

.include "m16def.inc"
.device atmega16

;--------------------------------------------------------------------------------------------

//constants definition

//symbolic custom registers names

;--------------------------------------------------------------------------------------------

;Macro definitions

.macro UOUT        ;Universal OUT command. Works with either memory mapped and usual I/O registers.
.if @0 < 0x40
	OUT @0,@1         
.else
	STS @0,@1
.endif
.endm

.macro UIN        ;Universal IN command. Works with either memory mapped and usual I/O registers.
.if @1 < 0x40
	IN @0,@1         
.else
	LDS @0,@1
.endif
.endm

.macro PUSHSREG
PUSH R16		//Stores the value of R16 in stack
IN R16, SREG	//Stores SREG in R16...
PUSH R16		//...and then stores the value of SREG in stack
.endm

.macro POPSREG
POP R16			//Extract SREG value from stack...
OUT SREG, R16	//...and apply it to SREG
POP R16			//Extract R16 value from stack
.endm

;--------------------------------------------------------------------------------------------

.DSEG			//SRAM memory segment
.ORG SRAM_START //start from the beginning

;--------------------------------------------------------------------------------------------

.CSEG

//Reset and Interrupt Vectors table

	.ORG 0x0000	;(RESET) 
	RJMP Reset

	.ORG INT0addr	;(INT0) External Interrupt Request 0
	RETI
	.ORG INT1addr	;(INT1) External Interrupt Request 1
	RETI
	.ORG OC2addr	;(TIMER2 COMP) Timer/Counter2 Compare Match
	RETI
	.ORG OVF2addr	;(TIMER2 OVF) Timer/Counter2 Overflow
	RETI
	.ORG ICP1addr	;(TIMER1 CAPT) Timer/Counter1 Capture Event
	RETI
	.ORG OC1Aaddr	;(TIMER1 COMPA) Timer/Counter1 Compare Match A
	RETI
	.ORG OC1Baddr	;(TIMER1 COMPB) Timer/Counter1 Compare Match B
	RETI
	.ORG OVF1addr	;(TIMER1 OVF) Timer/Counter1 Overflow
	RETI
	.ORG OVF0addr	;(TIMER0 OVF) Timer/Counter0 Overflow
	RETI
	.ORG SPIaddr	;(SPI,STC) Serial Transfer Complete
	RETI
	.ORG URXCaddr	;(USART,RXC) USART, Rx Complete
	RETI
	.ORG UDREaddr	;(USART,UDRE) USART Data Register Empty
	RETI
	.ORG UTXCaddr	;(USART,TXC) USART, Tx Complete
	RETI
	.ORG ADCCaddr	;(ADC) ADC Conversion Complete
	RETI
	.ORG ERDYaddr	;(EE_RDY) EEPROM Ready
	RETI
	.ORG ACIaddr	;(ANA_COMP) Analog Comparator
	RETI
	.ORG TWIaddr	;(TWI) 2-wire Serial Interface
	RETI
	.ORG INT2addr	;(INT2) External Interrupt Request 2
	RETI
	.ORG OC0addr	;(TIMER0 COMP) Timer/Counter0 Compare Match
	RETI
	.ORG SPMRaddr	;(SPM_RDY) Store Program Memory Ready
	RETI

.ORG INT_VECTORS_SIZE	;end of table

;--------------------------------------------------------------------------------------------

//Interrupts Handler//

//End of Interrupts Handler//

;--------------------------------------------------------------------------------------------

//Storage of static data in flash

;--------------------------------------------------------------------------------------------

Reset:
//SRAM flush
			LDI	ZL, Low(SRAM_START)	; Load Z with SRAM start address
			LDI	ZH, High(SRAM_START)
			CLR	R16					; R16 <- 0x00
Flush:		ST 	Z+, R16				; Flush byte and increment
			CPI	ZH, High(RAMEND+1)	; Is ZH == high half of the RAMEND address?
			BRNE Flush				; Loop if no
 
			CPI	ZL, Low(RAMEND+1)	; Same for low half of the address
			BRNE Flush

		CLR	ZL
		CLR	ZH

//R0-R31 flush
	LDI	ZL, 0x1E	; Address of R30 (in SRAM address space)
	CLR	ZH
	DEC	ZL			; Decrement address (flushing begins from R29 since we use R30:R31 as an address pointer)
	ST Z, ZH		; Load register with zero
	BRNE PC-2		; If Zero flag is cleared step back 2 times

//Thanks for code to DI HALT, Testicq and all fellow comrades from easyelectronics.ru

	LDI R16, Low(RAMEND)	//stack initialization
	OUT SPL, R16
	LDI R16, High(RAMEND)
	OUT SPH, R16

//SPI Initialization

//SPI pinout:
;PB7	SCK
;PB6	MISO
;PB5	MOSI
;PB4	SS

LDI R16, (1<<DDB6)
OUT DDRB, R16		//MISO set as output, all others as input	

//SPCR - SPI Control Register
//7 – (SPIE): SPI Interrupt Enable
//6 – (SPE): SPI Enable
//5 – (DORD): Data Order
//4 – (MSTR): Master/Slave Select
//3 – (CPOL): Clock Polarity
//2 – (CPHA): Clock Phase
//1 - (SPR1): SPI Clock Rate Select 1
//0 - (SPR0): SPI Clock Rate Select 0
//Int. disable, SPI enable, MSBit first, Slave Mode, ...
//...SCK is low when idle, read on leading SCK edge
LDI R16, 0b_0100_0000
UOUT SPCR, R16

//SPSR – SPI Status Register
//7 – (SPIF): SPI Interrupt Flag	r/o
//6 – (WCOL): Write COLlision Flag	r/o
//5:1 – (Res): Reserved Bits		r/o
//0 – (SPI2X): Double SPI Speed Bit
LDI R16, 0b_0000_0000
UOUT SPSR, R16

LDI R16, 0x5A
UOUT SPDR, R16		//initial value

;--------------------------------------------------------------------------------------------
// 0xA4 == 164 == 0b10100100
// 0xC8 == 200 == 0b11001000
// 0x92 == 146 == 0b10010010

// 0x69 == 105 == 0b01101001 == "i"
// 0x64 == 100 == 0b01100100 == "d"
// 0x5A ==  90 == 0b01011010 == "Z"
// 0x51 ==  81 == 0b01010001 == "Q"
// 0x37 ==  55 == 0b00110111 == "7"

//Main Routine//

Start:

SBIC SPSR, SPIF	//If nothing is received...
RJMP newData

RJMP Start		//...then loop

newData:
IN R16, SPDR	//Else read the new data

OUT SPDR, R16	//And send it for the next transmission

RJMP Start		//Go to start
//End of Main Routine//