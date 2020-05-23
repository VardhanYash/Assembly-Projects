/* Program that finds the largest number in a list of integers	*/

            .text                   // executable code follows
            .global _start                  
_start:                             
            MOV     R4, #RESULT     // R4 points to result location
            LDR     R2, [R4, #4]    // R2 holds the number of elements in the list
            MOV     R1, #NUMBERS    // R1 points to the start of the list
            BL      LARGE           
            STR     R0, [R4]        // R0 holds the subroutine return value

END:        B       END             

/* Subroutine to find the largest integer in a list
 * Parameters: R0 has the number of elements in the lisst
 *             R1 has the address of the start of the list
 * Returns: R0 returns the largest item in the list
 */
LARGE:      SUBS R2, #1 //decrements the loop counter
            MOVEQ R15, R14 // if all the elements have been looped through, returns control
            LDR R3, [R1] //loads the next number into R3
            ADD R1, #4 //moves to next element in the list of numbers
            CMP R0, R3 //compares R3 with the current largest val stored in R0
            BGE LARGE //keeps looping if R0 has the larger value
            MOV R0, R3 //moves the value from R3 into R0 if it is greater
            B LARGE //carries on the sub-routine

RESULT:     .word   0           
N:          .word   7           // number of entries in the list
NUMBERS:    .word   4, 5, 3, 6  // the data
            .word   1, 8, 2                 

            .end                            