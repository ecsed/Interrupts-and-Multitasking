# Interrupts and Multitasking
This is an interrupt request (IRQ) handler for the ARM Cortex-A9 onboard the DE1-SoC, implemented in the ARMv7 instruction set. I was able 
to accomplish this with understanding of ARM’s Generic Interrupt Controller and ARM exception handling, among other I/O topics gained from 
my introductory microcomputers course (CPEN 211, taught by Professor Tor Aamodt).

I wrote interrupt service routines (ISRs) which interact with some DE1-SoC peripherals to exercise the IRQ handler:
- a pushbutton ISR which uses the pushbuttons to display a number N on the HEX display, the Nth pushbutton that was pressed
- a timer ISR which uses the LEDs and the MPCore Private Timer to create a counter
- a keyboard ISR which uses the JTAG UART to read the host computer's keyboard stroke and display it to the Altera Monitor Program terminal 

Seeing how operating systems like Windows, Android, and Linux are able to run multiple programs on a single processor, I extended the IRQ 
handler to enable preemptive multitasking between two different processes (the keystroke display program and the LED counter) by 
implementing a process descriptor to save the state of each program and using the MPCore Private Timer to trigger periodic interrupts to 
switch between them.
