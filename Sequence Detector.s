/* Subroutine to convert the digits from 0 to 9 to be shown on a HEX display.
 *    Parameters: R0 = the decimal value of the digit to be displayed
 *    Returns: R0 = bit patterm to be written to the HEX display
 */

SEG7_CODE:  MOV     R1, #BIT_CODES  
            ADD     R1, R0         // index into the BIT_CODES "array"
            LDRB    R0, [R1]       // load the bit pattern (to be returned)
            MOV     PC, LR              

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
            .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
            .skip   2      // pad with 2 bytes to maintain word alignment


DIVIDE:     MOV    R2, #0

CONT:       CMP    R0, #10 //Change #10 here to change base  
            BLT    DIV_END
            SUB    R0, #10 //Change #10 here to change base
            ADD    R2, #1
            B      CONT

DIV_END:    MOV    R1, R2
            MOV    PC, LR


/* Program that counts consecutive 1's */

          .text                   // executable code follows
          .global _start                  
_start:   MOV     SP, #0x40000000
          MOV     R8, #TEST_NUM   // load the data word ...   
          BL MAIN
                       
MAIN:  
          MOV     R0, #0          // R0 will hold the result
          LDR     R1, [R8]        // loads in number from list

          CMP     R1, #0          // Reach the last word in the list
          BEQ     DISPLAY

          
          BL      ONES            // used to find number of ones in a row
          CMP     R5, R0          // checks if R5 needs to be updated
          MOVLT   R5, R0
          MOV     R0, #0          // resets R0 back to 0 to be used to store max 0s, and alternating 0s and 1s
          
          MOVW    R9, #0xffff     // used to invert bits, stores a sequence of all 1s
          MOVT    R9, #0xffff
          LDR     R1, [R8]
          EOR     R1, R1, R9      // inverts all the bits
          BL      ONES            // finds num of ones in a row (0s in original number)
          CMP     R6, R0          // checks if R6 needs to be updated
          MOVLT   R6, R0
          MOV     R0, #0

          MOVW    R9, #0x5555     // stores alternating 1s and 0s
          MOVT    R9, #0x5555
          LDR     R1, [R8]
          EOR     R1, R1, R9      // the number of 1s in a row represent the alternating sequence
          BL      ONES
          CMP     R7, R0          // checks if R7 needs to be updated
          MOVLT   R7, R0

          MOVW    R9, #0xaaaa     // stores alternating 0s and 1s
          MOVT    R9, #0xaaaa
          LDR     R1, [R8]
          EOR     R1, R1, R9      // the number of 1s in a row represent the alternating sequence
          BL      ONES
          CMP     R7, R0          // checks if R7 needs to be updated
          MOVLT   R7, R0
          
          ADD     R8, #4          // moves to next number in list
          B       MAIN

ONES:     CMP     R1, #0          // loop until the data contains no more 1's
          MOVEQ   PC, LR             
          LSR     R2, R1, #1      // perform SHIFT, followed by AND
          AND     R1, R1, R2      
          ADD     R0, #1          // count the string length so far
          B       ONES                      

TEST_NUM: .word   0x103fe00f, 0xf0342fff, 0x103ad688, 0x920394a1, 0x1112d90a, 0x223111ad, 0x88aa90a1, 0x00000aaa, 0xaaab2fff, 0xabcdef00, 0x00000000


/* Display R5 on HEX1-0, R6 on HEX3-2 and R7 on HEX5-4 */
DISPLAY:    LDR     R8, =0xFF200020 // base address of HEX3-HEX0

            // R5 code to show number of 1s in a row
            MOV     R0, R5          // display R5 on HEX1-0
            BL      DIVIDE          // ones digit will be in R0; tens digit in R1
            MOV     R9, R1          // save the tens digit

            BL      SEG7_CODE       
            MOV     R4, R0          // save bit code
            MOV     R0, R9          // retrieve the tens digit, get bit code

            BL      SEG7_CODE       
            LSL     R0, #8
            ORR     R4, R0
            STR     R4, [R8]        // display the numbers from R6 and R5

            // R6 code to show number of 0s in a row
            MOV     R0, R6          // display R5 on HEX1-0
            BL      DIVIDE          // ones digit will be in R0; tens digit in R1
            MOV     R9, R1          // save the tens digit

            BL      SEG7_CODE
            LSL     R0, #16       
            ORR     R4, R0          // save bit code
            MOV     R0, R9          // retrieve the tens digit, get bit code

            BL      SEG7_CODE       
            LSL     R0, #24
            ORR     R4, R0
            
            STR     R4, [R8]        // display the numbers from R6 and R5
            LDR     R8, =0xFF200030 // base address of HEX5-HEX4
            
            // R7 code to show number of alternating 1s and 0s in a row
            MOV     R0, R7          // display R5 on HEX1-0
            BL      DIVIDE          // ones digit will be in R0; tens
                                    // digit in R1
            MOV     R9, R1          // save the tens digit
            BL      SEG7_CODE       
            MOV     R4, R0          // save bit code
            MOV     R0, R9          // retrieve the tens digit, get bit
                                    // code
            BL      SEG7_CODE       
            LSL     R0, #8
            ORR     R4, R0

            STR     R4, [R8]        // display the number from R7
            BL       END

END:        B       END   

.end