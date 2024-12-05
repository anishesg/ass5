// Defining constants
        .equ    FALSE, 0
        .equ    TRUE, 1
        .equ    EOF, -1
        .equ    MAX_DIGITS, 32768
//----------------------------------------------------------------------
        
        .section .rodata

//----------------------------------------------------------------------

        .section .data

//----------------------------------------------------------------------

        .section .bss

//----------------------------------------------------------------------

        .section .text
        
//--------------------------------------------------------------
// Assign the sum of oAddend1 and oAddend2 to oSum.
// oSum should be distinct from oAddend1 and oAddend2.
// Return 0 (FALSE) if an overflow occurred,
// and 1 (TRUE) otherwise.
// int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
//--------------------------------------------------------------

// Must be a multiple of 16
        .equ    STACK_FRAME_SIZE, 48   // Changed from ADD_STACK_BYTECOUNT

// Local variable registers
SUM_LENGTH      .req x23              // Changed from LSUMLENGTH
INDEX           .req x22              // Changed from LINDEX

// Parameter registers
SUM_PTR         .req x21              // Changed from OSUM
ADDEND2_PTR     .req x20              // Changed from OADDEND2
ADDEND1_PTR     .req x19              // Changed from OADDEND1

// Structure field offsets
        .equ    DIGITS_OFFSET, 8       // Changed from AULDIGITS
        
        .global BigInt_add

BigInt_add:

        // Prologue
        sub     sp, sp, STACK_FRAME_SIZE
        stp     x30, x19, [sp]        // Using stp to store pair registers
        stp     x20, x21, [sp, 16]
        stp     x22, x23, [sp, 32]

        // Store parameters in registers
        mov     ADDEND1_PTR, x0
        mov     ADDEND2_PTR, x1
        mov     SUM_PTR, x2

        // Determine the larger length (inlined BigInt_larger)
        ldr     x0, [ADDEND1_PTR]      // x0 = oAddend1->lLength
        ldr     x1, [ADDEND2_PTR]      // x1 = oAddend2->lLength
        cmp     x0, x1
        ble     less_or_equal
        // SUM_LENGTH = oAddend1->lLength;
        mov     SUM_LENGTH, x0
        b       length_determined
less_or_equal:
        // SUM_LENGTH = oAddend2->lLength;
        mov     SUM_LENGTH, x1
length_determined:
        // Clear oSum's array if necessary

        // if (oSum->lLength <= SUM_LENGTH) skip clearing
        ldr     x0, [SUM_PTR]          // x0 = oSum->lLength
        cmp     x0, SUM_LENGTH
        ble     skip_clearing

        // memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long));
        add     x0, SUM_PTR, DIGITS_OFFSET
        mov     w1, #0
        mov     x2, #MAX_DIGITS
        lsl     x2, x2, #3             // x2 = MAX_DIGITS * 8
        bl      memset
        
skip_clearing:

        // INDEX = 0;
        mov     INDEX, #0
        
// Perform the addition

addition_loop:
        // Check if INDEX >= SUM_LENGTH
        cmp     INDEX, SUM_LENGTH
        bge     check_carry

        // Load digits from addend1 and addend2
        add     x3, ADDEND1_PTR, DIGITS_OFFSET
        ldr     x0, [x3, INDEX, lsl #3]  // x0 = oAddend1->aulDigits[INDEX]
        add     x4, ADDEND2_PTR, DIGITS_OFFSET
        ldr     x1, [x4, INDEX, lsl #3]  // x1 = oAddend2->aulDigits[INDEX]

        // Add with carry
        adcs    x1, x0, x1

        // Store result in oSum
        add     x5, SUM_PTR, DIGITS_OFFSET
        str     x1, [x5, INDEX, lsl #3]  // oSum->aulDigits[INDEX] = x1

        // INDEX++;
        add     INDEX, INDEX, #1

        // Loop back
        b       addition_loop

check_carry:
        // Check for a carry out of the last addition
        bcc     set_length             // If no carry, proceed to set length

        // if (SUM_LENGTH != MAX_DIGITS) add carry digit
        cmp     SUM_LENGTH, #MAX_DIGITS
        bne     add_carry_digit

        // Overflow occurred, return FALSE
        mov     w0, #FALSE
        // Epilogue
        ldp     x22, x23, [sp, 32]
        ldp     x20, x21, [sp, 16]
        ldp     x30, x19, [sp]
        add     sp, sp, STACK_FRAME_SIZE
        ret

add_carry_digit:
        // oSum->aulDigits[SUM_LENGTH] = 1;
        add     x0, SUM_PTR, DIGITS_OFFSET
        mov     x2, #1
        str     x2, [x0, SUM_LENGTH, lsl #3]

        // SUM_LENGTH++;
        add     SUM_LENGTH, SUM_LENGTH, #1

set_length:
        // Set the length of the sum
        str     SUM_LENGTH, [SUM_PTR]   // oSum->lLength = SUM_LENGTH

        // Return TRUE
        mov     w0, #TRUE
        // Epilogue
        ldp     x22, x23, [sp, 32]
        ldp     x20, x21, [sp, 16]
        ldp     x30, x19, [sp]
        add     sp, sp, STACK_FRAME_SIZE
        ret
.size   BigInt_add, (. - BigInt_add)