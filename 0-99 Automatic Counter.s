/* Timer that counts up every 0.25 seconds */

          .text                   // executable code follows
          .global _start                  
_start:                            
        MOV     R0, #0
        LDR     R1, =0xFF20005C     // Edgecapture register
        MOV     R4, #0
        MOV     R5, #0
        
        LDR     R6, =0xFFFEC600     // address of A9 timer
        LDR     R2, =50000000       // 0.25s delay
        STR     R2, [R6]
        MOV     R2, #0b011
        STR     R2, [R6, #8]
        
        
        MOV     R10, #0             // Global Counter
        MOV     R11, #0
        MOV     R12, #0             

        LDR     R7, =0xFF200020     // Loads R0 with the HEX3-0 Address
        LDR     R8, =0xFF200050     // Loads R1 with the KEYS Address
        LDR     R9, =BIT_CODES      
        

MAIN:   CMP     R10, #99            //Checks if the counter needs to be reset to 0
        MOVGT   R11, #0
        MOVGT   R12, #0
        MOVGT   R10, #0

        BL      CHECKKEY            //checks if a key is pushed
        BL      DO_DELAY            //Does the delay using the A9 timer
        
        ADD     R10, #1             //splits counter number into tens and ones
        ADD     R11, #1
        CMP     R11, #9
        ADDGT   R12, #1
        MOVGT   R11, #0

        LDRB    R4, [R9, R11]       //hex bit for ones
        LDRB    R5, [R9, R12]       //hex bit for tens
        LSL     R5, #8              
        ORR     R4, R5

        STR     R4, [R7]

        B       MAIN

CHECKKEY:
        PUSH    {R3, LR}
        LDR     R3, [R1]            //sees if a button was pushed by checking edge capture
        CMP     R3, #0
        BLGT    RESETEDGE           //resets the edge back to zero if it was
        BLGT    WAIT                //waits for another key to be pushed before continuing the timer count
        POP     {R3, PC}

WAIT:                              //waits until the edge capture is not zero (key is pushed)
        LDR     R3, [R1]
        CMP     R3, #0
        BEQ     WAIT
        B       RESETEDGE
        
RESETEDGE:
        PUSH    {R3, LR}            //resets the edge back to 0 to make it so that no KEYs have been pressed
        LDR     R3, =0b1111
        STR     R3, [R1]
        POP     {R3, PC}

DO_DELAY:
        LDR     R2, [R6, #0xC]
        CMP     R2, #0              //checks the F flag to see if the counter is done counting
        BEQ     DO_DELAY
        STR     R2, [R6, #0xC]
        MOV     PC, LR

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
            .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
            .skip   2      // pad with 2 bytes to maintain word alignment
          .end                            
