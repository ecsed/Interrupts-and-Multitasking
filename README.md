# Interrupts
All computers need to interface with the outside world to be useful. They do this through one or more I/O devices like your keyboard. For the computer to operate efficiently, an important question is “when should the computer access an I/O device when it wants to send/recieve data?” and the answer is to let the computer continue working on its current process and only talk to the interrupting I/O device when it's ready. This is accomplished by using an interrupt request (IRQ) handler to service all of the interrupts coming from I/O devices. The IRQ handler switches to the respective interrupt service routine (ISR) for an I/O device asserting an interrupt request to the processor when it's free.

That being said, this is an IRQ handler for the ARM Cortex-A9 onboard the DE1-SoC, implemented in the ARMv7 instruction set. I wrote 3 interrupt service routines (ISRs) which interact with some DE1-SoC peripherals to exercise the IRQ handler:
1. a pushbutton ISR which uses the pushbuttons to write a number N on the HEX display, where N is the Nth pushbutton pressed
2. a timer ISR which uses the MPCore Private Timer to create an integer counter and displays the integer on the LEDs in binary
3. a keyboard ISR which uses the JTAG UART to read the host computer's keystrokes and sends the characters to the Intel FPGA Monitor Program terminal

# Multitasking
Seeing how operating systems like Windows, Android, and Linux are able to run multiple programs on a single processor, I extended the IRQ handler to support preemptive multitasking on the ARM Cortex-A9 between two different processes (the keystroke display program and the LED counter). I did this by using the MPCore Private Timer to trigger periodic interrupts to switch between programs and implementing a process descriptor to save the states of each program. By doing so, both processes switch quickly enough such that it seems to the user as if they're running concurrently, and either process can continue where it left off before it was interrupted.

I was able to accomplish this project with the understanding of ARM’s Generic Interrupt Controller, ARM exception handling, and among other I/O topics gained from my introductory microcomputers course (CPEN 211, taught by Professor Tor Aamodt).
