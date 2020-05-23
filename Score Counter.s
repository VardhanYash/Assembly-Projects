/* Incrementing/Decrementing Counter Program */

          .text                   // executable code follows
          .global _start                  
_start:                            
        LDR     R0, =0xFF200020     // Loads R0 with the HEX3-0 Address
        LDR     R1, =0xFF200050     // Loads R1 with the KEYS Address
        LDR     R2, =BIT_CODES      
        MOV     R3, #0              // Global Counter

MAIN:
        MOV     R5, #0
        LDR     R5, [R1]

        CMP     R3, #0              //Checks if the counter needs to loop back to 9
        MOVLT   R3, #9

        CMP     R3, #9              //Checks if the counter needs to loop back to 0
        MOVGT   R3, #0

        CMP     R5, #0b0001         //Checks if KEY0 is pushed
        BLEQ    WRITEZERO

        CMP     R5, #0b0010         //Checks if KEY1 is pushed
        BLEQ    INCREASE


        CMP     R5, #0b0100         //Checks if KEY2 is pushed
        BLEQ    DECREASE


        CMP     R5, #0b1000         //Checks if KEY3 is pushed
        BLEQ    CLEAR
        BLEQ    WAIT

        LDRB    R4, [R2, R3]
        STR     R4, [R0]

        B       MAIN                //Loops if none of the above

WRITEZERO:
        PUSH    {R5, LR}
        MOV     R3, #0              //Makes the global counter 0

ZEROWAIT:
        LDR     R5, [R1]            
        CMP     R5, #0b0010         //Checks if the KEY1 has been released
        POPNE   {R5, PC}            // (for when increment hits 9 and needs to be reset)
        B       ZEROWAIT            

INCREASE:   
        PUSH    {R5, LR}
        ADD     R3, #1              //increments the global counter

INCREASEWAIT:                       //waits for KEY1 to be released (to not infinitely increase)
        LDR     R5, [R1]            
        CMP     R5, #0b0010
        POPNE   {R5, PC}
        B       INCREASEWAIT

DECREASE:
        PUSH    {R5, LR}
        SUB     R3, #1

DECREASEWAIT:                       //waits for KEY2 to be released (to not infinitely decrease)
        LDR     R5, [R1]            
        CMP     R5, #0b0100
        POPNE   {R5, PC}
        B       DECREASEWAIT
CLEAR:                              //makes sure none of the LEDS are on for all HEXes
        PUSH    {R4, LR}            
        MOV     R4, #0
        STR     R4, [R0]
        POP     {R4, PC}

WAIT:   PUSH {R5, LR}

LOOP:                               //keeps display clear until another key is hit
        LDR     R5, [R1]            
        CMP     R5, #0
        BLNE    WRITEZERO
        POPNE   {R5, PC}
        B       LOOP

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
            .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
            .skip   2      // pad with 2 bytes to maintain word alignment
          .end                            
