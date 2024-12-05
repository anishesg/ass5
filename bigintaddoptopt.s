//-----------------------------------------------------------------------
// bigint_add_optimized.s
// Author: anish k
//-----------------------------------------------------------------------

        .equ    false, 0
        .equ    true, 1
        .equ    max_digits, 32768

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

        // Define register aliases
        addend1Reg .req x0                  // addend1
        addend2Reg .req x1                  // addend2
        resultReg  .req x2                  // result
        sumLength  .req x4                  // sumLength
        index      .req x5                  // index
        tempReg    .req x6                  // Temporary register

        // Load lengths of addend1 and addend2
        ldr     x3, [addend1Reg, #0]        // x3 = addend1->lLength
        ldr     x4, [addend2Reg, #0]        // x4 = addend2->lLength

        // Determine the larger length
        cmp     x3, x4
        csel    sumLength, x3, x4, gt       // sumLength = (x3 > x4) ? x3 : x4

        // Clear result's digit array if necessary
        ldr     x7, [resultReg, #0]         // x7 = result->lLength
        cmp     x7, sumLength
        bgt     skip_clear

        // Call memset to clear result's digits
        add     x0, resultReg, #8           // x0 = &result->aulDigits
        mov     x1, #0                      // Value to set (0)
        mov     x2, max_digits
        lsl     x2, x2, #3                  // x2 = max_digits * sizeof(unsigned long)
        bl      memset

skip_clear:

        // Initialize index to zero
        mov     index, #0

        // Clear carry flag before addition
        subs    xzr, xzr, xzr               // Clear carry flag

        // Addition loop
addition_loop:
        cmp     index, sumLength
        bge     addition_done

        // Load digits from addend1 and addend2
        add     tempReg, addend1Reg, #8
        ldr     x3, [tempReg, index, lsl #3]    // x3 = addend1->aulDigits[index]
        add     tempReg, addend2Reg, #8
        ldr     x4, [tempReg, index, lsl #3]    // x4 = addend2->aulDigits[index]

        // Add digits with carry
        adcs    x3, x3, x4                      // x3 = x3 + x4 + carry

        // Store result digit
        add     tempReg, resultReg, #8
        str     x3, [tempReg, index, lsl #3]    // result->aulDigits[index] = x3

        // Increment index
        add     index, index, #1
        b       addition_loop

addition_done:

        // Handle final carry
        bcc     set_result_length              // If no carry, skip to setting length

        // Check for overflow
        cmp     sumLength, max_digits
        beq     return_overflow

        // Store carry in next digit
        mov     x0, #1
        add     tempReg, resultReg, #8
        str     x0, [tempReg, sumLength, lsl #3]
        add     sumLength, sumLength, #1

set_result_length:

        // Update result's length
        str     sumLength, [resultReg, #0]

        // Epilogue: restore registers and return
        mov     w0, #1                        // Return true
        ldp     x21, x22, [sp]                // Restore registers
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp, #32]
        add     sp, sp, #48                   // Deallocate stack space
        ret

return_overflow:

        // Handle overflow case
        mov     w0, #0                        // Return false
        ldp     x21, x22, [sp]
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp, #32]
        add     sp, sp, #48
        ret

//-----------------------------------------------------------------------