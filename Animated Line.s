/* Animated Line that moves across the screen */         
          .text                   // executable code follows
          .global _start                  
_start:
        LDR     SP, =0x3FFFFFFC
        LDR     R12, =0xFF203020
        BL      MAIN

// Question 1 (a)

WAIT_FOR_VSYNC:
        PUSH    {R0, LR}
        MOV     R0, #1
        STR     R0, [R12]           //*pixel_ctrl_ptr = 1;

WHILE:
        LDR     R0, [R12, #12]
        AND     R0, #0x01
        CMP     R0, #0
        BNE     WHILE
        POP     {R0, PC} 

// Question 1 (b)

PLOT_PIXEL: //given R0 = xcoord, R1 = ycoord, R2 = color
        PUSH    {R3, LR}
        LDR     R3, [R12, #4]       // R3 = backbuffer
        LSL     R0, #1              // x << 1
        LSL     R1, #10             // y << 10
        ADD     R3, R0              // back_buffer + (x << 1)
        ADD     R3, R1              // back_buffer + (y << 10)
        STRH    R2, [R3]            // *(back_buffer + (y << 10) + (x << 1)) = color
        LSR     R0, #1              // undo the changes that were made
        LSR     R1, #10
        POP     {R3, PC}

// Question 1 (c)

CLEAR_SCREEN:
        PUSH    {LR}
        MOV     R0, #0              // will loop through x coordinates
        MOV     R1, #0              // will loop through y coordinates
        MOV     R2, #0              // the color will be black
        
XLOOP:  
        CMP     R0, #320            // value of max x coordinate
        MOV     R1, #0
        BNE     YLOOP
        POP     {PC}

YLOOP:
        BL      PLOT_PIXEL
        ADD     R1, #1
        CMP     R1, #240            // value of max y coordinate
        BNE     YLOOP
        ADD     R0, #1
        B       XLOOP

// Question 1 (d)

DRAW_LINE: // R0 = x0, R1 = x1, R2 = y, R3 = color
        PUSH    {LR}

/* We must swap the register values so that R0 = x0, R1 = y, R2 = color since that is the way the plot_pixel works */       
        EOR     R2, R1, R2
        EOR     R1, R2, R1
        EOR     R2, R2, R1      // now we will have R1 = y, R2 = x1

        EOR     R3, R2, R3
        EOR     R2, R3, R2
        EOR     R3, R3, R2      // now we will have R2 = color and R3 = x1

DRAWLOOP:
        CMP     R0, R3          // checks if R0 <= R1

        BGT     SWAPBACK        // once we are done looping to x1 
        BL      PLOT_PIXEL      
        ADD     R0, #1          // increments R0 each loop
        B       DRAWLOOP

SWAPBACK:
        EOR     R3, R2, R3    // swap everything back to how it was
        EOR     R2, R3, R2
        EOR     R3, R3, R2    // now we will have R2 = x1, R3 = colour

        EOR     R2, R1, R2
        EOR     R1, R2, R1
        EOR     R2, R2, R1    // now we will have R1 = x1 and R2 = y
        

        POP   {PC}            // once R0 > R1, returns

// Question 1 (e)

MAIN:
        BL      CLEAR_SCREEN

        MOV     R0, #100        // x_0
        MOV     R1, #220        // x_1
        MOV     R2, #0          // y
        MOV     R4, #1          // y_dir
        
        LDR     R3, =0xFFFF     // changes the colour to white
        BL      DRAW_LINE
        
MAINLOOP:
        BL      WAIT_FOR_VSYNC
        MOV     R3, #0          // changes colour to black
        MOV     R0, #100        //resets value of R0 back to what its initialized as
        BL      DRAW_LINE

        ADD     R2, R4          // y = y + y_dir, changes the line position

        CMP     R2, #0
        MOVEQ   R4, #1
        
        CMP     R2, #239
        MVNEQ   R4, #0

        LDR     R3, =0xFFFF     // chagnes colour to white
        MOV     R0, #100        //resets value of R0 back to what its initialized as
        BL      DRAW_LINE
        B       MAINLOOP

.end