				.include	"address_map_arm.s"
				.include	"interrupt_ID.s"

/* ********************************************************************************
 * This program demonstrates use of interrupts and with assembly language code. 
 * The program responds to interrupts from the pushbutton KEY port, the MPCORE
 * timer, and the keystrokes on your keyboard via JTAG UART.
 *
 * The interrupt service routine for the pushbutton KEYs indicates which KEY has 
 * been pressed on the HEX0 display.
 *
 * The interrupt service routine for the timer is a simple counter program using 
 * the LEDs.
 * 
 * The interrupt service routine for the JTAG UART reads your keystrokes on the 
 * keyboard while in the Altera Monitor Program terminal and displays them to it.
 ********************************************************************************/

				.section .vectors, "ax"

				B 			_start					// reset vector
				B 			SERVICE_UND				// undefined instruction vector
				B 			SERVICE_SVC				// software interrrupt vector
				B 			SERVICE_ABT_INST		// aborted prefetch vector
				B 			SERVICE_ABT_DATA		// aborted data vector
				.word 	0							// unused vector
				B 			SERVICE_IRQ				// IRQ interrupt vector
				B 			SERVICE_FIQ				// FIQ interrupt vector

				.text
				.global	_start
_start:		
				/* Set up stack pointers for IRQ and SVC processor modes */
				MOV		R1, #0b11010010					// interrupts masked, MODE = IRQ
				MSR		CPSR_c, R1							// change to IRQ mode
				LDR		SP, =A9_ONCHIP_END - 3			// set IRQ stack to top of A9 onchip memory
				/* Change to SVC (supervisor) mode with interrupts disabled */
				MOV		R1, #0b11010011					// interrupts masked, MODE = SVC
				MSR		CPSR, R1								// change to supervisor mode
				LDR		SP, =DDR_END - 3					// set SVC stack to top of DDR3 memory

				BL			CONFIG_GIC							// configure the ARM generic interrupt controller
				
				// configure the timer
				LDR 	R0, =MPCORE_PRIV_TIMER						// MPCore private timer base address
				LDR 	R1, =100000000						// timeout = 1/(200MHz)*100*10^6 = 0.5 s
				STR 	R1, [R0]						// write to timer load register
				MOV 	R2, #0b111						// set interrupt = auto = enable = 1
				STR 	R2, [R0, #0x8]						// write to control registers
				
				// configure the JTAG UART
				LDR 	R0, =JTAG_UART_BASE						// JTAG UART base address
				MOV 	R1, #0b1						// set RE bit for interrupts when RAVAIL for recieve FIFO
				STR 	R1, [R0, #0x4]						// and clear WE bit when WSPACE for transmit FIFO
				
				// write to the pushbutton KEY interrupt mask register
				LDR		R0, =KEY_BASE						// pushbutton KEY base address
				MOV		R1, #0xF								// set interrupt mask bits
				STR		R1, [R0, #0x8]						// interrupt mask register is (base + 8)

				// enable IRQ interrupts in the processor
				MOV		R0, #0b01010011					// IRQ unmasked, MODE = SVC
				MSR		CPSR_c, R0

IDLE:
				LDR 	R0, =CHAR_FLAG
				LDR		R1, [R0]						// read value in CHAR_FLAG
				CMP 	R1, #1
				
				BNE			IDLE									// main program simply idles

READ_CHAR_BUFFER:
				LDR 	R1, =CHAR_BUFFER
				LDR 	R0, [R1]						// read value in CHAR_BUFFER
				
				BL			PUT_JTAG
				
				LDR		R0, =CHAR_FLAG
				MOV 	R1, #0						// set flag register
				STR		R1, [R0]						// set CHAR_FLAG to 0

				B			IDLE 									// main program simply idles			

/* Define the exception service routines */

/*--- Undefined instructions --------------------------------------------------*/
SERVICE_UND:
    			B SERVICE_UND 
 
/*--- Software interrupts -----------------------------------------------------*/
SERVICE_SVC:			
    			B SERVICE_SVC 

/*--- Aborted data reads ------------------------------------------------------*/
SERVICE_ABT_DATA:
    			B SERVICE_ABT_DATA 

/*--- Aborted instruction fetch -----------------------------------------------*/
SERVICE_ABT_INST:
    			B SERVICE_ABT_INST 
 
/*--- IRQ ---------------------------------------------------------------------*/
SERVICE_IRQ:
    			PUSH		{R0-R7, LR}
    
    			/* Read the ICCIAR from the CPU interface */
    			LDR		R4, =MPCORE_GIC_CPUIF
    			LDR		R5, [R4, #ICCIAR]			// read from ICCIAR
				
JTAG_UART_BASE_HANDLER:
				CMP 	R5, #JTAG_IRQ				// determine if interrupt source from JTAG UART
				BNE 	MPCORE_PRIV_TIMER_HANDLER
PROCESS_CHAR:
				LDR 	R0, =JTAG_UART_BASE
				LDRB 	R1, [R0]					// load 1 byte from DATA in data register
				LDR 	R2, =CHAR_BUFFER			// load CHAR_BUFFER address
				STRB 	R1, [R2]					// store the 8-bit ASCII value to CHAR_BUFFER
				MOV 	R0, #1						// set flag register
				LDR 	R1, =CHAR_FLAG				// load CHAR_FLAG address
				STR 	R0, [R1]					// set CHAR_FLAG to 1
				
				B 			EXIT_IRQ
				
MPCORE_PRIV_TIMER_HANDLER:
				CMP		R5, #MPCORE_PRIV_TIMER_IRQ	// determine if interrupt source from timer
				BNE 	FPGA_IRQ1_HANDLER
				
INCREMENT_COUNTER:
				MOV 	R0, #1						// set interrupt acknowledge/increment register
				LDR		R1, =MPCORE_PRIV_TIMER
				STR		R0, [R1, #0xC]				// reset F in the interrupt status register
			
				LDR		R1, =led_counter			// load led_counter address
				LDR 	R2, [R1]					// load previous value in led_counter
				ADD		R2, R2, R0					// increment led_counter
				STR		R2, [R1]					// store current value to led_counter
				
				LDR 	R1, =LEDR_BASE
				STR		R2, [R1]					// display value on the LEDs
				
				B 			EXIT_IRQ
				
FPGA_IRQ1_HANDLER:
    			CMP		R5, #KEYS_IRQ				// determine if interrupt source from key port

UNEXPECTED:		BNE		UNEXPECTED    				// if not recognized, stop here
    
    			BL			KEY_ISR

EXIT_IRQ:
    			/* Write to the End of Interrupt Register (ICCEOIR) */
    			STR		R5, [R4, #ICCEOIR]			// write to ICCEOIR
    
    			POP		{R0-R7, LR}
    			SUBS		PC, LR, #4

/*--- FIQ ---------------------------------------------------------------------*/
SERVICE_FIQ:
    			B			SERVICE_FIQ
				
/* initialize global variables */

led_counter:
.word 0

CHAR_BUFFER:
.word 0

CHAR_FLAG:
.word 0
				.end
