

// Define constants
        .equ    false, 0
        .equ    true, 1
        .equ    max_digits, 32768

//-----------------------------------------------------------------------

        .section .text

//-----------------------------------------------------------------------
// Function: int bigint_add(BigInt_T addend1, BigInt_T addend2, BigInt_T result)
// Description: Computes the sum of addend1 and addend2 and stores it in result.
//              Returns 0 (false) on overflow, 1 (true) otherwise.
//-----------------------------------------------------------------------

        .global bigint_add

bigint_add:

        // Prologue: set up the stack frame
        sub     sp, sp, #48                 // Allocate stack space (multiple of 16)
        stp     x29, x30, [sp, #32]         // Save frame pointer and link register
        stp     x19, x20, [sp, #16]         // Save callee-saved registers
        stp     x21, x22, [sp]              // Save more callee-saved registers
        add     x29, sp, #32                // Update frame pointer

        // Move parameters into callee-saved registers for efficiency
        mov     addend1Reg, x0              // addend1
        mov     addend2Reg, x1              // addend2
        mov     resultReg, x2               // result

        // Local variables
        // unsigned long sumDigit;
        // long index;
        // long sumLength;

        // Inline comparison to find the larger length
        ldr     x0, [addend1Reg]            // x0 = addend1->length
        ldr     x1, [addend2Reg]            // x1 = addend2->length
        cmp     x0, x1
        csel    sumLength, x1, x0, gt       // sumLength = (x0 > x1) ? x0 : x1

        // Clear result's digit array if necessary
        ldr     x3, [resultReg]
        cmp     x3, sumLength
        bgt     skip_clear

        // Call memset to clear result's digits
        add     x0, resultReg, #8           // x0 = &result->digits
        mov     x1, #0                      // Value to set (0)
        mov     x2, max_digits
        lsl     x2, x2, #3                  // x2 = max_digits * sizeof(unsigned long)
        bl      memset

skip_clear:

        // Initialize index to zero
        mov     index, #0

        // Clear carry flag before addition
        subs    xzr, xzr, xzr               // Clear carry flag

        // Check if we need to enter the loop
        cmp     index, sumLength
        bge     addition_done

addition_loop:

        // Perform addition with carry
        ldr     x0, [addend1Reg, index, lsl #3] // x0 = addend1->digits[index]
        ldr     x1, [addend2Reg, index, lsl #3] // x1 = addend2->digits[index]
        adcs    x0, x0, x1                      // x0 = x0 + x1 + carry
        str     x0, [resultReg, index, lsl #3]  // result->digits[index] = x0

        // Increment index
        add     index, index, #1

        // Loop condition
        cmp     index, sumLength
        blt     addition_loop

addition_done:

        // Handle final carry
        bcc     set_result_length              // If no carry, skip to setting length

        // Check for overflow
        cmp     sumLength, max_digits
        beq     return_overflow

        // Store carry in next digit
        mov     x0, #1
        str     x0, [resultReg, sumLength, lsl #3]
        add     sumLength, sumLength, #1

set_result_length:

        // Update result's length
        str     sumLength, [resultReg]

        // Epilogue: restore registers and return
        mov     w0, true
        ldp     x21, x22, [sp]              // Restore registers
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp, #32]
        add     sp, sp, #48                 // Deallocate stack space
        ret

return_overflow:

        // Handle overflow case
        mov     w0, false
        ldp     x21, x22, [sp]
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp, #32]
        add     sp, sp, #48
        ret

//----------------------------------------------------------------------