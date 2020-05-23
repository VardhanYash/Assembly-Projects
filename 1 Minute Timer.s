                .section .vectors, "ax"                  
                B        _start              // reset vector
                B        SERVICE_UND         // undefined instruction vector
                B        SERVICE_SVC         // software interrupt vector
                B        SERVICE_ABT_INST    // aborted prefetch vector
                B        SERVICE_ABT_DATA    // aborted data vector
                .word    0                   // unused vector
                B        SERVICE_IRQ         // IRQ interrupt vector
                B        SERVICE_FIQ         // FIQ interrupt vector

                .text                                       
                .global _start                              
_start:                                         
/* Set up stack pointers for IRQ and SVC processor modes */
                MOV      R0, #0b10010    // bits for IRQ mode
                MSR      CPSR, R0        // change to IRQ mode
                LDR      SP, =0x20000    // set SP for IRQ mode

                MOV      R0, #0b10011    // bits for SVC mode
                MSR      CPSR, R0        // change to SVC mode
                LDR      SP, =0x3FFFFFFC    // set SP for SVC mode

                BL      CONFIG_GIC          // configure the ARM generic
                                            // interrupt controller
                BL      CONFIG_PRIV_TIMER   // configure the private timer
                BL      CONFIG_TIMER        // configure the Interval Timer
                BL      CONFIG_KEYS         // configure the pushbutton
                                            // KEYs port
/* Enable IRQ interrupts in the ARM processor */
                // the 7th bit is already set to 0 (interrupt is enabled) from earlier MSR instruction
                LDR     R5, =0xFF200000     // LEDR base address
                LDR     R6, =0xFF200020     // HEX3-0 base address
LOOP:                                           
                LDR     R4, COUNT           // global variable
                STR     R4, [R5]            // light up the red lights
                LDR     R4, HEX_code        // global variable
                STR     R4, [R6]            // show the time in format
                                                // SS:DD
                B       LOOP                

SERVICE_IRQ:    PUSH     {R0-R7, LR}     
                LDR      R4, =0xFFFEC100 // GIC CPU interface base address
                LDR      R5, [R4, #0x0C] // read the ICCIAR in the CPU
                                         // interface

KEYS_HANDLER:                       
                CMP     R5, #73         // check the interrupt ID    
                BNE     TIMER_HANDLER
                BLEQ    KEY_ISR  
                B       EXIT_IRQ
TIMER_HANDLER:
                CMP     R5, #72
                BNE     PRIVATE_TIMER_HANDLER
                BLEQ    TIMER_ISR
                B       EXIT_IRQ

PRIVATE_TIMER_HANDLER:
                CMP     R5, #29

UNEXPECTED:     BNE     UNEXPECTED
                BL      PRIVATE_TIMER_ISR
                B       EXIT_IRQ

EXIT_IRQ:       STR     R5, [R4, #0x10] // write to the End of Interrupt Register (ICCEOIR)
                POP     {R0-R7, LR}     
                SUBS    PC, LR, #4      // return from exception

KEY_ISR:        
                LDR     R0, =0xFF20005C
                LDR     R0, [R0]

                CMP     R0, #0b0001
                BEQ     STARTSTOP

                CMP     R0, #0b0010
                BEQ     FASTER

                CMP     R0, #0b0100
                BEQ     SLOWER

                CMP     R0, #0b1000
                BEQ     TOGGLECLOCK

CLEAR_KEY_ISR:  LDR     R0, =0xFF20005C // resets the edge capture bits
                MOV     R1, #0b1111
                STR     R1, [R0]
                MOV     PC, LR

STARTSTOP:      LDR     R0, =RUN       
                LDR     R1, [R0]
                CMP     R1, #0          //switches the value of RUN based on if its 0 or 1
                MOVEQ   R2, #1
                MOVNE   R2, #0 

                STR     R2, [R0]

                B       CLEAR_KEY_ISR

FASTER:         LDR     R0, =0xFF202000
                LDR     R1, [R0, #0xC]  //upper bits of the delay
                LDR     R2, [R0, #0x8]  //lower bits of the delay

                LSL     R1, #16
                ORR     R1, R2          //R1 now has the entire delay

                LSR     R1, #1          //divides the delay by 2 to double the speed

                STR     R1, [R0, #0x8]  //stores the new values lower bits 
                LSR     R1, #16
                STR     R1, [R0, #0xC]  //stores the new values upper bits

                MOV     R1, #0b0101     //turns the stop and cont bit to 0 and makes start and ITO 1
                STR     R1, [R0, #0x4]  //write the value to the timer

                B       CLEAR_KEY_ISR

SLOWER:         LDR     R0, =0xFF202000
                LDR     R1, [R0, #0xC]  //upper bits of the delay
                LDR     R2, [R0, #0x8]  //lower bits of the delay

                LSL     R1, #16
                ORR     R1, R2          //R1 now has the entire delay

                MOV     R2, #2
                MUL     R1, R2          //multiplies the delay by 2 to double the speed

                STR     R1, [R0, #0x8]  //stores the new values lower bits 
                LSR     R1, #16
                STR     R1, [R0, #0xC]  //stores the new values upper bits

                MOV     R1, #0b0101     //turns the stop and cont bit to 0 and makes start and ITO 1
                STR     R1, [R0, #0x4]  //write the value to the timer

                B       CLEAR_KEY_ISR

TOGGLECLOCK:
                LDR     R0, =0xFFFEC608 // address of the Enable bit for the counter
                LDR     R3, [R0]
                EOR     R3, #0b1        //flips the enable bit
                STR     R3, [R0]

                B       CLEAR_KEY_ISR
TIMER_ISR:
                LDR     R0, =0xFF202000
                LDR     R1, =RUN
                LDR     R2, =COUNT 

                LDR     R1, [R1]        //gets values of run
                LDR     R3, [R2]        //gets value of count

                ADD     R3, R1          //Count = count + run
                STR     R3, [R2]        //saves the value back to count

                MOV     R1, #0
                STR     R1, [R0]        //restarts the count of the timer

                MOV     R1, #0b0101     //turns the stop and cont bit to 0 and makes start and ITO 1
                STR     R1, [R0, #0x4]  //write the value to the timer

                MOV     PC, LR

PRIVATE_TIMER_ISR:
                PUSH    {R0-R12, LR}

                LDR     R4, =TIME
                LDR     R5, =HEX_code
                LDR     R6, =BIT_CODES
                LDR     R8, =6000

                LDR     R7, [R4]        // gets value of TIME
                ADD     R7, #1          // adds +1
                CMP     R7, R8     // 60s have been reached
                MOVEQ   R7, #0
                STR     R7, [R4]        // stores the value back to TIME

                MOV     R0, R7
                BL      DIVIDE          // hundreths digit in R0, rest of the digits in R1
                MOV     R12, R0
                
                MOV     R0, R1
                BL      DIVIDE          // tenths digit in R0, rest of the digits in R1
                MOV     R11, R0

                MOV     R0, R1
                BL      DIVIDE          // ones digit in R0, tens in R1
                MOV     R10, R0
                MOV     R9, R1

                LDRB    R0, [R6, R12]       //hex bit for hundreths
        
                LDRB    R1, [R6, R11]       //hex bit for tenths
                LSL     R1, #8          
                ORR     R0, R1

                LDRB    R1, [R6, R10]       //hex bit for ones
                LSL     R1, #16
                ORR     R0, R1

                LDRB    R1, [R6, R9]        //hex bits for tens
                LSL     R1, #24
                ORR     R0, R1

                STR     R0, [R5]            //writes the value to the global variable HEX_code

                LDR     R4, =0xFFFEC600
                MOV     R1, #1
                STR     R1, [R4, #0xC]        //restarts count of timer

                POP     {R0-R12, PC}

DIVIDE:     MOV    R2, #0

CONT:       CMP    R0, #10 //Change #10 here to change base  
            BLT    DIV_END
            SUB    R0, #10 //Change #10 here to change base
            ADD    R2, #1
            B      CONT

DIV_END:    MOV    R1, R2
            MOV    PC, LR

/* Configure the MPCore private timer to create interrupts every 1/100 seconds */
CONFIG_PRIV_TIMER:                              
                PUSH    {R0-R12}
                LDR     R0, =0xFFFEC600
                LDR     R1, =2000000      //value for 0.01s delay
                STR     R1, [R0]    
                MOV     R2, #0b111        // setting I, A and E bits to 1
                STR     R2, [R0, #8]

                POP     {R0-R12}
                BX      LR        

/* Configure the Interval Timer to create interrupts at 0.25 second intervals */
CONFIG_TIMER:                               
                PUSH    {R0-R12}                          
                LDR     R0, =0xFF202000 //timer address

                MOVW    R1, #0x17D       //upper bits of 25000000 in hex(number to get a 0.25s delay)
                STR     R1, [R0, #0xC]

                MOVW    R1, #0x7840       //lower bits of 25000000 in hex(number to get a 0.25s delay)
                STR     R1, [R0, #0x8]

                MOV     R6, #0b0101     //turns the stop and cont bit to 0 and makes start and ITO 1
                STR     R6, [R0, #0x4]  //write the value to the timer

                POP     {R0-R12}
                BX      LR                  
/* Configure the pushbutton KEYS to generate interrupts */
CONFIG_KEYS:                                    
                PUSH     {R0-R12}                                
                LDR      R0, =0xFF200050 // base address of the KEY switches
                MOV      R1, #0b1111
                STR      R1, [R0, #0x8]  // used to set Interrupt Mask to 1 for all KEYs

                POP     {R0-R12}
                BX      LR                        

/* Global variables */
                .global COUNT                               
COUNT:          .word   0x0       // used by timer
                .global RUN       // used by pushbutton KEYs
RUN:            .word   0x1       // initial value to increment COUNT
                .global TIME                                
TIME:           .word   0x0       // used for real-time clock
                .global HEX_code                            
HEX_code:       .word   0x0       // used for 7-segment displays

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
            .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
            .skip   2      // pad with 2 bytes to maintain word alignment

                
CONFIG_GIC:
				PUSH		{LR}
    			/* Configure the A9 Private Timer interrupt, FPGA KEYs, and FPGA Timer
				/* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
    			MOV		R0, #MPCORE_PRIV_TIMER_IRQ
    			MOV		R1, #CPU0
    			BL			CONFIG_INTERRUPT
    			MOV		R0, #INTERVAL_TIMER_IRQ
    			MOV		R1, #CPU0
    			BL			CONFIG_INTERRUPT
    			MOV		R0, #KEYS_IRQ
    			MOV		R1, #CPU0
    			BL			CONFIG_INTERRUPT

				/* configure the GIC CPU interface */
    			LDR		R0, =0xFFFEC100		// base address of CPU interface
    			/* Set Interrupt Priority Mask Register (ICCPMR) */
    			LDR		R1, =0xFFFF 			// enable interrupts of all priorities levels
    			STR		R1, [R0, #0x04]
    			/* Set the enable bit in the CPU Interface Control Register (ICCICR). This bit
				 * allows interrupts to be forwarded to the CPU(s) */
    			MOV		R1, #1
    			STR		R1, [R0]
    
    			/* Set the enable bit in the Distributor Control Register (ICDDCR). This bit
				 * allows the distributor to forward interrupts to the CPU interface(s) */
    			LDR		R0, =0xFFFED000
    			STR		R1, [R0]    
    
    			POP     	{PC}
/* 
 * Configure registers in the GIC for an individual interrupt ID
 * We configure only the Interrupt Set Enable Registers (ICDISERn) and Interrupt 
 * Processor Target Registers (ICDIPTRn). The default (reset) values are used for 
 * other registers in the GIC
 * Arguments: R0 = interrupt ID, N
 *            R1 = CPU target
*/
CONFIG_INTERRUPT:
    			PUSH		{R4-R5, LR}
    
    			/* Configure Interrupt Set-Enable Registers (ICDISERn). 
				 * reg_offset = (integer_div(N / 32) * 4
				 * value = 1 << (N mod 32) */
    			LSR		R4, R0, #3							// calculate reg_offset
    			BIC		R4, R4, #3							// R4 = reg_offset
				LDR		R2, =0xFFFED100
				ADD		R4, R2, R4							// R4 = address of ICDISER
    
    			AND		R2, R0, #0x1F   					// N mod 32
				MOV		R5, #1								// enable
    			LSL		R2, R5, R2							// R2 = value

				/* now that we have the register address (R4) and value (R2), we need to set the
				 * correct bit in the GIC register */
    			LDR		R3, [R4]								// read current register value
    			ORR		R3, R3, R2							// set the enable bit
    			STR		R3, [R4]								// store the new register value

    			/* Configure Interrupt Processor Targets Register (ICDIPTRn)
     			 * reg_offset = integer_div(N / 4) * 4
     			 * index = N mod 4 */
    			BIC		R4, R0, #3							// R4 = reg_offset
				LDR		R2, =0xFFFED800
				ADD		R4, R2, R4							// R4 = word address of ICDIPTR
    			AND		R2, R0, #0x3						// N mod 4
				ADD		R4, R2, R4							// R4 = byte address in ICDIPTR

				/* now that we have the register address (R4) and value (R2), write to (only)
				 * the appropriate byte */
				STRB		R1, [R4]
    
    			POP		{R4-R5, PC}

/* FPGA interrupts (there are 64 in total; only a few are defined below) */
			.equ	INTERVAL_TIMER_IRQ, 			72
			.equ	KEYS_IRQ, 						73
			.equ	FPGA_IRQ2, 						74
			.equ	FPGA_IRQ3, 						75
			.equ	FPGA_IRQ4, 						76
			.equ	FPGA_IRQ5, 						77
			.equ	AUDIO_IRQ, 						78
			.equ	PS2_IRQ, 						79
			.equ	JTAG_IRQ, 						80
			.equ	IrDA_IRQ, 						81
			.equ	FPGA_IRQ10,						82
			.equ	JP1_IRQ,							83
			.equ	JP2_IRQ,							84
			.equ	FPGA_IRQ13,						85
			.equ	FPGA_IRQ14,						86
			.equ	FPGA_IRQ15,						87
			.equ	FPGA_IRQ16,						88
			.equ	PS2_DUAL_IRQ,					89
			.equ	FPGA_IRQ18,						90
			.equ	FPGA_IRQ19,						91

/* ARM A9 MPCORE devices (there are many; only a few are defined below) */
			.equ	MPCORE_GLOBAL_TIMER_IRQ,	27
			.equ	MPCORE_PRIV_TIMER_IRQ,		29
			.equ	MPCORE_WATCHDOG_IRQ,			30

/* HPS devices (there are many; only a few are defined below) */
			.equ	HPS_UART0_IRQ,   				194
			.equ	HPS_UART1_IRQ,   				195
			.equ	HPS_GPIO0_IRQ,          	196
			.equ	HPS_GPIO1_IRQ,          	197
			.equ	HPS_GPIO2_IRQ,          	198
			.equ	HPS_TIMER0_IRQ,         	199
			.equ	HPS_TIMER1_IRQ,         	200
			.equ	HPS_TIMER2_IRQ,         	201
			.equ	HPS_TIMER3_IRQ,         	202
			.equ	HPS_WATCHDOG0_IRQ,     		203
			.equ	HPS_WATCHDOG1_IRQ,     		204

/* Undefined instructions */
SERVICE_UND:                                
                    B   SERVICE_UND         
/* Software interrupts */
SERVICE_SVC:                                
                    B   SERVICE_SVC         
/* Aborted data reads */
SERVICE_ABT_DATA:                           
                    B   SERVICE_ABT_DATA    
/* Aborted instruction fetch */
SERVICE_ABT_INST:                           
                    B   SERVICE_ABT_INST    
SERVICE_FIQ:                                
                    B   SERVICE_FIQ     

			.equ		EDGE_TRIGGERED,         0x1
			.equ		LEVEL_SENSITIVE,        0x0
			.equ		CPU0,         				0x01	// bit-mask; bit 0 represents cpu0
			.equ		ENABLE, 						0x1

			.equ		KEY0, 						0b0001
			.equ		KEY1, 						0b0010
			.equ		KEY2,							0b0100
			.equ		KEY3,							0b1000

			.equ		RIGHT,						1
			.equ		LEFT,							2

			.equ		USER_MODE,					0b10000
			.equ		FIQ_MODE,					0b10001
			.equ		IRQ_MODE,					0b10010
			.equ		SVC_MODE,					0b10011
			.equ		ABORT_MODE,					0b10111
			.equ		UNDEF_MODE,					0b11011
			.equ		SYS_MODE,					0b11111

			.equ		INT_ENABLE,					0b01000000
			.equ		INT_DISABLE,				0b11000000


/* Memory */
        .equ  DDR_BASE,	            0x00000000
        .equ  DDR_END,              0x3FFFFFFF
        .equ  A9_ONCHIP_BASE,	      0xFFFF0000
        .equ  A9_ONCHIP_END,        0xFFFFFFFF
        .equ  SDRAM_BASE,    	      0xC0000000
        .equ  SDRAM_END,            0xC3FFFFFF
        .equ  FPGA_ONCHIP_BASE,	   0xC8000000
        .equ  FPGA_ONCHIP_END,      0xC803FFFF
        .equ  FPGA_CHAR_BASE,   	   0xC9000000
        .equ  FPGA_CHAR_END,        0xC9001FFF

/* Cyclone V FPGA devices */
        .equ  LEDR_BASE,             0xFF200000
        .equ  HEX3_HEX0_BASE,        0xFF200020
        .equ  HEX5_HEX4_BASE,        0xFF200030
        .equ  SW_BASE,               0xFF200040
        .equ  KEY_BASE,              0xFF200050
        .equ  JP1_BASE,              0xFF200060
        .equ  JP2_BASE,              0xFF200070
        .equ  PS2_BASE,              0xFF200100
        .equ  PS2_DUAL_BASE,         0xFF200108
        .equ  JTAG_UART_BASE,        0xFF201000
        .equ  JTAG_UART_2_BASE,      0xFF201008
        .equ  IrDA_BASE,             0xFF201020
        .equ  TIMER_BASE,            0xFF202000
        .equ  AV_CONFIG_BASE,        0xFF203000
        .equ  PIXEL_BUF_CTRL_BASE,   0xFF203020
        .equ  CHAR_BUF_CTRL_BASE,    0xFF203030
        .equ  AUDIO_BASE,            0xFF203040
        .equ  VIDEO_IN_BASE,         0xFF203060
        .equ  ADC_BASE,              0xFF204000

/* Cyclone V HPS devices */
        .equ   HPS_GPIO1_BASE,       0xFF709000
        .equ   HPS_TIMER0_BASE,      0xFFC08000
        .equ   HPS_TIMER1_BASE,      0xFFC09000
        .equ   HPS_TIMER2_BASE,      0xFFD00000
        .equ   HPS_TIMER3_BASE,      0xFFD01000
        .equ   FPGA_BRIDGE,          0xFFD0501C

/* ARM A9 MPCORE devices */
        .equ   PERIPH_BASE,          0xFFFEC000   /* base address of peripheral devices */
        .equ   MPCORE_PRIV_TIMER,    0xFFFEC600   /* PERIPH_BASE + 0x0600 */

        /* Interrupt controller (GIC) CPU interface(s) */
        .equ   MPCORE_GIC_CPUIF,     0xFFFEC100   /* PERIPH_BASE + 0x100 */
        .equ   ICCICR,               0x00         /* CPU interface control register */
        .equ   ICCPMR,               0x04         /* interrupt priority mask register */
        .equ   ICCIAR,               0x0C         /* interrupt acknowledge register */
        .equ   ICCEOIR,              0x10         /* end of interrupt register */
        /* Interrupt controller (GIC) distributor interface(s) */
        .equ   MPCORE_GIC_DIST,      0xFFFED000   /* PERIPH_BASE + 0x1000 */
        .equ   ICDDCR,               0x00         /* distributor control register */
        .equ   ICDISER,              0x100        /* interrupt set-enable registers */
        .equ   ICDICER,              0x180        /* interrupt clear-enable registers */
        .equ   ICDIPTR,              0x800        /* interrupt processor targets registers */
        .equ   ICDICFR,              0xC00        /* interrupt configuration registers */
        .end                                                                        
