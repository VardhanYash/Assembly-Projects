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

/* Enable IRQ interrupts in the ARM processor */
                // the 7th bit is already set to 0 (interrupt is enabled) from earlier MSR instruction

IDLE:           B       IDLE  

SERVICE_IRQ:    PUSH     {R0-R7, LR}     
                LDR      R4, =0xFFFEC100 // GIC CPU interface base address
                LDR      R5, [R4, #0x0C] // read the ICCIAR in the CPU
                                         // interface


PRIVATE_TIMER_HANDLER:
                CMP     R5, #29

UNEXPECTED:     BNE     UNEXPECTED
                BL      PRIVATE_TIMER_ISR
                B       EXIT_IRQ

EXIT_IRQ:       STR     R5, [R4, #0x10] // write to the End of Interrupt Register (ICCEOIR)
                POP     {R0-R7, LR}     
                SUBS    PC, LR, #4      // return from exception

PRIVATE_TIMER_ISR:
                PUSH    {R0-R12, LR}

                LDR     R9, =BIT_CODES
                LDR     R10, =0xFF200040        // address of the SWITCHES
                LDR     R11, =0xFF200020        // address of the HEX3-0
                LDR     R12, =0xFF200030        // address of the HEX5-4

                
                LDR     R4, [R10]

                CMP     R4, #0
                BEQ     WRITE1

                CMP     R4, #1
                BEQ     WRITE1

                CMP     R4, #2
                BEQ     WRITE1

                CMP     R4, #3
                BEQ     WRITE1

                CMP     R4, #4
                BEQ     WRITE2

                CMP     R4, #5
                BEQ     WRITE2

WRITE1:
                LDRB    R5, [R9, R4]            // loads the bit code for based on what R4 is (what number to show on the HEX)
                LDRB    R6, [R11, R4]           // loads the particular HEX that we are going to display on (0-3)
                
                LDR     R0, =HEX_CODE_1
                LDR     R2, [R0]
                
                MOV     R7, #8
                MUL     R4, R7                  // does R4 x 8, will be used to determine how much to shift in next step
                LSL     R5, R4

                ORR     R2, R5                  // aligns the sequence correctly and stores it in the global HEX_CODE_1
                STR     R2, [R0]

                LDR     R8, [R11]
                CMP     R6, #0           // check if the given HEX is already ON
                SUBNE   R8, R5           // if it is ON then make it 0
                ADDEQ   R8, R5           // if it is OFF then write the number
                STR     R8, [R11]

                B       FLASH

WRITE2:
                LDRB    R5, [R9, R4]            // loads the bit code for based on what R4 is (what number to show on the HEX)
                
                LDR     R1, =HEX_CODE_2
                LDR     R2, [R1]
                MOV     R3, R4

                SUB     R3, #4                  // since the address of the HEX will now change, we must take no shift = HEX4
                LDRB    R6, [R12, R3]           // loads the particular HEX that we are going to display on (4-5)
                
                MOV     R7, #8
                MUL     R3, R7                  // does R3 x 8, will be used to determine how much to shift in next step
                LSL     R5, R3

                ORR     R2, R5                   // aligns the sequence correctly and stores it in the global HEX_CODE_2
                STR     R2, [R1]

                LDR     R8, [R12]
                CMP     R6, #0           // check if the given HEX is already ON
                SUBNE   R8, R5           // if it is ON then make it 0
                ADDEQ   R8, R5           // if it is OFF then write the number
                STR     R8, [R12]

                B       FLASH

FLASH:
				LDR		R0, =ON
				LDR		R1, [R0]
				CMP		R1, #0			// switches the value of whatever ON is to the opposite
				MOVNE   R1, #0
				MOVEQ	R1, #1


				STR		R1, [R0]		// the value of ON is now flipped
                
                LDR     R4, =0xFFFEC600
                MOV     R1, #1
                STR     R1, [R4, #0xC]        //restarts count of timer

                POP     {R0-R12, PC}

/* Configure the MPCore private timer to create interrupts every 1/100 seconds */
CONFIG_PRIV_TIMER:                              
                PUSH    {R0-R12}
                LDR     R0, =0xFFFEC600
                LDR     R1, =100000000      //value for 0.25s delay
                STR     R1, [R0]    
                MOV     R2, #0b111        // setting I, A and E bits to 1
                STR     R2, [R0, #8]

                POP     {R0-R12}
                BX      LR        

                .global ON   //used to flash the LED ON and OFF    
ON:             .word   0x1  // initially ON
                .global CURRENT_SWITCH  // to see what the current toggled switch is
HEX_CODE_1:     .word   0x0             
                .global HEX_CODE_2  // the value for the HEXs5-4
HEX_CODE_2:     .word   0x0            

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
