/* Program that converts a binary number to decimal */
           .text               // executable code follows
           .global _start
_start:
            MOV    R4, #N
            MOV    R5, #Digits  // R5 points to the decimal digits storage location
            LDR    R4, [R4]     // R4 holds N
            MOV    R10, R4       // parameter for DIVIDE goes in R0
            
            BL     DIVIDE
            MOV    R0, R11
            STRB   R0, [R5]     // Ones digit is in R0 
            
            BL     DIVIDE
            MOV    R1, R11
            STRB   R1, [R5, #1] // Tens digit is now in R1

            BL     DIVIDE
            MOV    R2, R11
            STRB   R2, [R5, #2] // Hundredths digit is now in R2

            BL     DIVIDE
            MOV    R3, R11
            STRB   R3, [R5, #3] // Thousandths digit is now in R3

END:        B      END

/* Subroutine to perform the integer division R10 / 10.
 * Returns: quotient in R9, and remainder in R11
*/
DIVIDE:     MOV    R9, #0

CONT:       CMP    R10, #10 //Change #10 here to change base  
            BLT    DIV_END
            SUB    R10, #10 //Change #10 here to change base
            ADD    R9, #1
            B      CONT

DIV_END:    MOV    R11, R10
            MOV    R10, R9     // quotient in R10 (remainder in R11)
            MOV    PC, LR

N:          .word  3123         // the decimal number to be converted
Digits:     .space 4          // storage space for the decimal digits

            .end