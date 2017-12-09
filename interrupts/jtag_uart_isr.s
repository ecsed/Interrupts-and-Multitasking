.include	"address_map_arm.s"

/****************************************************************************************
 * JTAG UART - Display Character                                
 *                                                                          
 * This routine sends the read character to the Altera Monitor Program terminal
 ***************************************************************************************/
				
				.global	PUT_JTAG
PUT_JTAG:	
			LDR		R1, =JTAG_UART_BASE		// JTAG UART base address
			LDR 	R2, [R1, #4]			// read the JTAG UART control register
			LDR 	R3, =0xFFFF
			ANDS	R2, R2, R3				// check for write space
			BEQ 	END_PUT					// if no space, ignore the character
			STR 	R0, [R1]				// send the character
END_PUT:	
			BX 		LR

				.end