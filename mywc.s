//----------------------------------------------------------------------
    // bigintaddoptopt.s
    // Author: Anish K (Optimized by ChatGPT)
    //----------------------------------------------------------------------

    // Defining constants
    .equ    FALSE_VAL, 0
    .equ    TRUE_VAL, 1
    .equ    MAX_DIGITS_COUNT, 32768

    // Structure field offsets for BigInt_T
    .equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
    .equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T

    // Stack byte counts (should be multiples of 16 for alignment)
    .equ    ADDITION_STACK_SIZE, 80    // Adjusted to accommodate all saved registers

    // Local variable registers using .req directives
    // For BigInt_add
    .req    ULCARRY, x22    // ulCarry
    .req    ULSUM, x23      // ulSum
    .req    LINDEX, x24     // lIndex
    .req    LSUMLENGTH, x25  // lSumLength

    .req    OADDEND1, x26    // oAddend1
    .req    OADDEND2, x27    // oAddend2
    .req    OSUM, x28        // oSum

    .section .text

    //--------------------------------------------------------------
    // Assign the sum of oAddend1 and oAddend2 to oSum.
    // oSum should be distinct from oAddend1 and oAddend2.
    // Return 0 (FALSE_VAL) if an overflow occurred, and 1 (TRUE_VAL) otherwise.
    // int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
    // Parameters:
    //   x0: oAddend1
    //   x1: oAddend2
    //   x2: oSum
    // Returns:
    //   w0: TRUE_VAL (1) if successful, FALSE_VAL (0) if overflow occurred
    //--------------------------------------------------------------

    .global BigInt_add

    BigInt_add:

        // Prologue: set up the stack frame
        sub     sp, sp, ADDITION_STACK_SIZE
        stp     x29, x30, [sp, #0]                 // Save frame pointer and link register
        mov     x29, sp                            // Set frame pointer

        stp     ULCARRY, ULSUM, [sp, #16]          // Save ulCarry and ulSum
        stp     LINDEX, LSUMLENGTH, [sp, #32]      // Save lIndex and lSumLength
        stp     OADDEND1, OADDEND2, [sp, #48]      // Save oAddend1 and oAddend2
        stp     OSUM, x9, [sp, #64]                // Save oSum and an unused register (x9)

        // Move parameters to callee-saved registers
        mov     OADDEND1, x0                       // oAddend1 = x0
        mov     OADDEND2, x1                       // oAddend2 = x1
        mov     OSUM, x2                           // oSum = x2

        // Inlined BigInt_larger logic to determine lSumLength
        ldr     x0, [OADDEND1, LENGTH_OFFSET]       // load oAddend1->lLength
        ldr     x1, [OADDEND2, LENGTH_OFFSET]       // load oAddend2->lLength
        cmp     x0, x1
        csel    x25, x0, x1, GT                    // lSumLength = (x0 > x1) ? x0 : x1

        // Check if oSum->lLength <= lSumLength
        ldr     x0, [OSUM, LENGTH_OFFSET]           // load oSum->lLength
        cmp     x0, x25
        ble     skip_clear_digits                   // if oSum->lLength <= lSumLength, skip memset

        // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
        add     x0, OSUM, DIGITS_OFFSET             // pointer to oSum->aulDigits
        mov     w1, 0                               // value to set
        mov     x2, MAX_DIGITS_COUNT               // number of digits
        lsl     x2, x2, #3                          // size = MAX_DIGITS_COUNT * 8
        bl      memset                              // call memset

    skip_clear_digits:
        // Initialize ulCarry to 0
        mov     ULCARRY, wzr

        // Initialize lIndex to 0
        mov     LINDEX, wzr

    addition_loop:
        // Check if lIndex >= lSumLength
        cmp     LINDEX, x25
        bge     handle_carry                        // if lIndex >= lSumLength, handle carry

        // Load oAddend1->aulDigits[lIndex]
        ldr     x1, [OADDEND1, DIGITS_OFFSET]       // base address of oAddend1->aulDigits
        ldr     x2, [x1, x24, LSL #3]               // load oAddend1->aulDigits[lIndex]

        // Load oAddend2->aulDigits[lIndex]
        ldr     x3, [OADDEND2, DIGITS_OFFSET]       // base address of oAddend2->aulDigits
        ldr     x4, [x3, x24, LSL #3]               // load oAddend2->aulDigits[lIndex]

        // Add the two digits with carry
        add     x5, x2, x4                           // x5 = aulDigits1 + aulDigits2
        adcs    x5, x5, wzr                          // x5 += carry, update carry flag

        // Store the result into oSum->aulDigits[lIndex]
        ldr     x6, [OSUM, DIGITS_OFFSET]           // base address of oSum->aulDigits
        str     x5, [x6, x24, LSL #3]               // store the sum

        // Increment lIndex
        add     LINDEX, LINDEX, #1

        // Loop back
        b       addition_loop

    handle_carry:
        // Check if there was a carry from the last addition
        cset    w9, cs                              // Set w9 to carry flag (cs = carry set)

        cmp     w9, #0
        beq     finalize_sum_length                  // If no carry, finalize

        // Check if lSumLength == MAX_DIGITS_COUNT
        cmp     x25, MAX_DIGITS_COUNT
        beq     overflow_detected                    // If equal, overflow occurred

        // Set oSum->aulDigits[lSumLength] = 1
        ldr     x0, [OSUM, DIGITS_OFFSET]           // base address of oSum->aulDigits
        ldr     x1, =1
        str     x1, [x0, x25, LSL #3]               // set the carry digit

        // Increment lSumLength
        add     x25, x25, #1

    finalize_sum_length:
        // Set oSum->lLength = lSumLength
        str     x25, [OSUM, LENGTH_OFFSET]          // store lSumLength into oSum->lLength

        // Epilogue: restore stack frame and return
        mov     w0, TRUE_VAL                        // return TRUE_VAL
        ldp     ULCARRY, ULSUM, [sp, #16]            // restore ulCarry and ulSum
        ldp     LINDEX, LSUMLENGTH, [sp, #32]        // restore lIndex and lSumLength
        ldp     OADDEND1, OADDEND2, [sp, #48]        // restore oAddend1 and oAddend2
        ldp     OSUM, x9, [sp, #64]                  // restore oSum and unused register
        ldp     x29, x30, [sp, #0]                   // restore frame pointer and link register
        add     sp, sp, ADDITION_STACK_SIZE          // deallocate stack frame
        ret

    overflow_detected:
        // Return FALSE_VAL due to overflow
        mov     w0, FALSE_VAL
        ldp     ULCARRY, ULSUM, [sp, #16]            // restore ulCarry and ulSum
        ldp     LINDEX, LSUMLENGTH, [sp, #32]        // restore lIndex and lSumLength
        ldp     OADDEND1, OADDEND2, [sp, #48]        // restore oAddend1 and oAddend2
        ldp     OSUM, x9, [sp, #64]                  // restore oSum and unused register
        ldp     x29, x30, [sp, #0]                   // restore frame pointer and link register
        add     sp, sp, ADDITION_STACK_SIZE          // deallocate stack frame
        ret

    .size   BigInt_add, .-BigInt_add