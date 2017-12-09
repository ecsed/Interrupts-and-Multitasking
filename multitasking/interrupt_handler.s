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
 * The interrupt service routine for the timer continuously switches between two
 * processes at a timeout and uses a PD to save the interrupted process. Process 1 
 * is a simple counter program using the LEDs, and Process 0 is described below.
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
PROC0:						// simple keystroke echo to terminal program 
				LDR 	R0, =CHAR_FLAG
				LDR		R1, [R0]						// read value in CHAR_FLAG
				CMP 	R1, #1
				
				BNE			PROC0									// wait for keystroke

READ_CHAR_BUFFER:
				LDR 	R1, =CHAR_BUFFER
				LDR 	R0, [R1]						// read value in CHAR_BUFFER
				
				BL			PUT_JTAG
				
				LDR		R0, =CHAR_FLAG
				MOV 	R1, #0						// set flag register
				STR		R1, [R0]						// set CHAR_FLAG to 0

				B			IDLE 									// main program runs process 0			

PROC1:						// simple led counter program
				// store a delay constant in memory
				.equ LARGE_NUMBER, 0x11111111
										// int count = 0;
				MOV R0, #0 				// store 0 in R0 to initialize counter
				
										// int* ledr;
				LDR R1, =LEDR_BASE 		// store base address of LEDR controller (0xFF200000) in R1
				
										// int large_number = 0x11111111;			
				LDR R3, =LARGE_NUMBER	// store large value in R3 as delay constant called large_number

										// while(1) {
L1:										// count++;
				ADD R0, R0, #1			// add 1 to value in R0 to increment counter
				
										// *ledr = count;
				STR R0, [R1]			// display value in R0 on LEDs to display counter
				
										// int i = 0;
				MOV R2, #0				// store 0 in R2 to reset delay loop
	
										// do {
L2:										// i++;
				ADD R2, R2, #1			// add 1 to value in R2 to increment i
				
				CMP R2, R3 				// compare value in R2 with value in R3, or i with large_number
				
										// } while( i < large_number );					
				BLT L2					// stay in L2 until i is greater than or equal to large_number to
										// create delay loop

										// }
				B L1					// unconditional branch to L1 to create infinite while loop

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
				
PROC_SWITCH:
				MOV 	R0, #1						// set interrupt acknowledge register
				LDR		R1, =MPCORE_PRIV_TIMER
				STR		R0, [R1, #0xC]				// reset F in the interrupt status register
				
				LDR 	R1, =CURRENT_PID			// load CURRENT_PID address
				LDR 	R0, [R1]					// load process ID
				EOR 	R0, R0, #1					// switch process ID
				STR		R0, [R1]					// store process ID 	
				
				LDR 	R1, =PD_ARRAY				// load PD_ARRAY[0] for process 0
				
				CMP 	R0, #1						// determine from which PD_ARRAY index to
				BEQ 	SAVE_PROC					// begin save for which interrupted process
				
				ADD 	R1, R1, #68					// load PD_ARRAY[17] for process 1
				
SAVE_PROC:											// save interrupted process
				LDR 	R0, [SP]					// load R0 of interrupted process
				STR 	R0, [R1]					// store R0 to PD_ARRAY[0]/PD_ARRAY[17]
				
				LDR 	R0, [SP, #4]				// load R1 of interrupted process
				STR 	R0, [R1, #4]				// store R1 to PD_ARRAY[1]/PD_ARRAY[18]
				
				STR 	R2, [R1, #8]				// store R2 to PD_ARRAY[2]/PD_ARRAY[19]
				STR 	R3, [R1, #12]				// store R3 to PD_ARRAY[3]/PD_ARRAY[20]
				
				LDR 	R0, [SP, #12]				// load R4 of interrupted process
				STR 	R0, [R1, #16]				// store R4 to PD_ARRAY[4]/PD_ARRAY[21]
				
				LDR 	R0, [SP, #16]				// load R5 of interrupted process
				STR 	R0, [R1, #20]				// store R5 to PD_ARRAY[5]/PD_ARRAY[22]
				
				STR 	R6, [R1, #24]				// store R6 to PD_ARRAY[6]/PD_ARRAY[23]
				STR 	R7, [R1, #28]				// store R7 to PD_ARRAY[7]/PD_ARRAY[24]
				STR 	R8, [R1, #32]				// store R8 to PD_ARRAY[8]/PD_ARRAY[25]
				STR 	R9, [R1, #36]				// store R9 to PD_ARRAY[9]/PD_ARRAY[26]
				STR 	R10, [R1, #40]				// store R10 to PD_ARRAY[10]/PD_ARRAY[27]
				STR 	R11, [R1, #44]				// store R11 to PD_ARRAY[11]/PD_ARRAY[28]
				STR 	R12, [R1, #48]				// store R12 to PD_ARRAY[12]/PD_ARRAY[29]
				
				MOV		R0, #0b11010011				// interrupts masked, MODE = SVC
				MSR		CPSR, R0					// change to supervisor mode
				
				STR 	SP, [R1, #52]				// store SP_SVC to PD_ARRAY[13]/PD_ARRAY[30]
				STR 	LR, [R1, #56]				// store LR_SVC to PD_ARRAY[14]/PD_ARRAY[31]
				
				MOV		R0, #0b11010010				// interrupts masked, MODE = IRQ
				MSR		CPSR_c, R0					// change to IRQ mode
				
				STR 	LR, [R1, #60]				// store LR_IRQ to PD_ARRAY[15]/PD_ARRAY[32]
				
				MRS 	R0, SPSR
				STR 	R0, [R1, #64]				// store SPSR_IRQ to PD_ARRAY[16]/PD_ARRAY[33]
				
				ADD 	SP, SP, #32					// increase SP_IRQ to free stack space holding
													// saved registers of interrupted process		
LOAD_PROC_CONFIG:	
				LDR 	R3, =PS_COUNT				// load PS_COUNT address
				LDR 	R2, [R3]					// read PS_COUNT 
				ADD 	R2, R2, #1					// increment PS_COUNT
				STR 	R2, [R3]					// update PS_COUNT
				
				LDR 	R1, =CURRENT_PID			// load CURRENT_PID address
				LDR 	R0, [R1]					// load process ID	
				
				LDR 	R1, =PD_ARRAY				// load PD_ARRAY[0] for process 0
				
				CMP 	R0, #1						// determine from which PD_ARRAY index to
				BNE 	LOAD_PROC					// begin load for which next process
				
				ADD 	R1, R1, #68					// load PD_ARRAY[17] for process 1
				
				CMP 	R2, #1						// initialize process 1 if
				BEQ 	INIT_PROC					// this is the first run

LOAD_PROC:											// load next process
				LDR 	R12, [R1, #48]				// load R12 from PD_ARRAY[12]/PD_ARRAY[29]
				LDR 	R11, [R1, #44]				// load R11 from PD_ARRAY[11]/PD_ARRAY[28]
				LDR 	R10, [R1, #40]				// load R10 from PD_ARRAY[10]/PD_ARRAY[27]
				LDR 	R9, [R1, #36]				// load R9 from PD_ARRAY[9]/PD_ARRAY[26]
				LDR 	R8, [R1, #32]				// load R8 from PD_ARRAY[8]/PD_ARRAY[25]
				LDR 	R7, [R1, #28]				// load R7 from PD_ARRAY[7]/PD_ARRAY[24]
				LDR 	R6, [R1, #24]				// load R6 from PD_ARRAY[6]/PD_ARRAY[23]
				LDR 	R5, [R1, #20]				// load R5 from PD_ARRAY[5]/PD_ARRAY[22]
				LDR 	R4, [R1, #16]				// load R4 from PD_ARRAY[4]/PD_ARRAY[21]
				
INIT_PROC:											// initialize process 1
				MOV		R0, #0b11010011				// interrupts masked, MODE = SVC
				MSR		CPSR, R0					// change to supervisor mode
				
				LDR 	R0, [R1, #52]				// load SP from PD_ARRAY[13]/PD_ARRAY[30]
				MOV 	SP, R0						// initialize SP
				LDR 	R0, [R1, #56]				// load LR
				MOV 	LR, R0						// initialize LR from PD_ARRAY[14]/PD_ARRAY[31]
				
				MOV		R0, #0b11010010				// interrupts masked, MODE = IRQ
				MSR		CPSR_c, R0					// change to IRQ mode
				
				LDR 	R0, [R1, #60]				// load PC from PD_ARRAY[15]/PD_ARRAY[32]
				MOV 	LR, R0						// initialize PC
				
				LDR 	R0, [R1, #64]				// load CPSR from PD_ARRAY[16]/PD_ARRAY[33]
				MSR 	SPSR, R0					// initialize CPSR

EXIT_PS:						
				/* Write to the End of Interrupt Register (ICCEOIR) */
				LDR		R3, =MPCORE_GIC_CPUIF
    			LDR		R2, =MPCORE_PRIV_TIMER_IRQ	// avoid reading spurious interrupt from ICCIAR
    			STR		R2, [R3, #ICCEOIR]			// write to ICCEOIR
				
				LDR 	R2, [R1, #8]				// load R2 from PD_ARRAY[2]/PD_ARRAY[19]
				LDR 	R3, [R1, #12]				// load R3 from PD_ARRAY[3]/PD_ARRAY[20]
				LDR 	R0, [R1]					// load R0 from PD_ARRAY[0]/PD_ARRAY[17]
				LDR 	R1, [R1, #4]				// load R1 from PD_ARRAY[1]/PD_ARRAY[18]
				
    			SUBS		PC, LR, #4				// resume next process
				
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

CURRENT_PID:
.word 0

PD_ARRAY:
.fill 17,4,0xDEADBEEF
.fill 13,4,0xDEADBEE1
.word 0x3F000000 	// SP
.word 0				// LR
.word PROC1+4		// PC
.word 0x53			// CPSR (0x53 means IRQ enabled, mode = SVC)

PS_COUNT:
.word 0

led_counter:
.word 0

CHAR_BUFFER:
.word 0

CHAR_FLAG:
.word 0
				.end
