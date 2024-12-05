
/* Optimized ARMv8 assembly implementation of BigInt_add function.
   Implements the following optimizations:
   - Inlines the BigInt_larger function.
   - Uses callee-saved registers for parameters and local variables.
   - Uses the adcs instruction to handle carries efficiently.
   - Employs the guarded loop pattern for the addition loop.
*/

        .section .text
        .global BigInt_add

/* Define constants */
        .equ    FALSE, 0
        .equ    TRUE, 1
        .equ    MAX_DIGITS, 32768
        .equ    LLENGTH_OFFSET, 0          /* Offset of lLength in BigInt_T */
        .equ    AULDIGITS_OFFSET, 8        /* Offset of aulDigits in BigInt_T */
        .equ    STACK_FRAME_SIZE, 64       /* Must be multiple of 16 */

/* BigInt_add function
   int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum);
*/
BigInt_add:
        /* Prologue */
        sub     sp, sp, STACK_FRAME_SIZE

        /* Save callee-saved registers and return address */
        stp     x29, x30, [sp, #56]        /* Save frame pointer and LR */
        stp     x25, x26, [sp, #40]
        stp     x23, x24, [sp, #24]
        stp     x21, x22, [sp, #8]
        stp     x19, x20, [sp]             /* Save x19 and x20 */

        /* Move parameters into callee-saved registers */
        mov     x19, x0            /* oAddend1 */
        mov     x20, x1            /* oAddend2 */
        mov     x21, x2            /* oSum */

        /*----------------------------------------------------------------*/
        /* Inline BigInt_larger: lSumLength = max(oAddend1->lLength, oAddend2->lLength); */

        /* Load oAddend1->lLength and oAddend2->lLength */
        ldr     x0, [x19, #LLENGTH_OFFSET]    /* x0 = oAddend1->lLength */
        ldr     x1, [x20, #LLENGTH_OFFSET]    /* x1 = oAddend2->lLength */

        /* Compute lSumLength = max(x0, x1) */
        cmp     x0, x1
        csel    x22, x0, x1, gt               /* x22 = x0 if x0 > x1, else x1 */
        /* x22 now holds lSumLength */

        /*----------------------------------------------------------------*/
        /* Clear oSum's array if necessary */
        /* if (oSum->lLength <= lSumLength) { memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long)); } */

        ldr     x3, [x21, #LLENGTH_OFFSET]    /* x3 = oSum->lLength */
        cmp     x3, x22
        bgt     skip_memset                   /* Skip memset if oSum->lLength > lSumLength */

        /* Prepare arguments for memset */
        add     x0, x21, #AULDIGITS_OFFSET    /* x0 = oSum->aulDigits */
        mov     x1, #0                        /* x1 = value to set (0) */
        mov     x2, #MAX_DIGITS
        lsl     x2, x2, #3                    /* x2 = MAX_DIGITS * 8 (size in bytes) */

        bl      memset                        /* Call memset */

skip_memset:
        /*----------------------------------------------------------------*/
        /* Initialize lIndex = 0 */
        mov     x23, #0                       /* lIndex = 0 */

        /* Prepare base addresses for aulDigits arrays */
        add     x24, x19, #AULDIGITS_OFFSET   /* x24 = oAddend1->aulDigits */
        add     x25, x20, #AULDIGITS_OFFSET   /* x25 = oAddend2->aulDigits */
        add     x26, x21, #AULDIGITS_OFFSET   /* x26 = oSum->aulDigits */

        /* Clear carry flag before addition */
        subs    x9, xzr, xzr                  /* Clear carry flag; x9 is a scratch register */

        /*----------------------------------------------------------------*/
        /* Guarded loop for addition */
        cmp     x23, x22                      /* Compare lIndex with lSumLength */
        bge     end_add_loop                  /* If lIndex >= lSumLength, skip loop */

add_loop:
        /* Load digits from oAddend1 and oAddend2 */
        ldr     x0, [x24, x23, LSL #3]        /* x0 = oAddend1->aulDigits[lIndex] */
        ldr     x1, [x25, x23, LSL #3]        /* x1 = oAddend2->aulDigits[lIndex] */

        /* Add digits with carry */
        adcs    x0, x0, x1                    /* x0 = x0 + x1 + C */
        /* Store result in oSum */
        str     x0, [x26, x23, LSL #3]        /* oSum->aulDigits[lIndex] = x0 */

        /* Increment lIndex */
        add     x23, x23, #1                  /* lIndex++ */

        /* Loop condition */
        cmp     x23, x22
        blt     add_loop

end_add_loop:
        /*----------------------------------------------------------------*/
        /* Check for carry out of the last addition */
        bcs     handle_carry                  /* If carry flag set, handle carry */
        b       set_length                    /* Else, proceed to set length */

handle_carry:
        /* Check if lSumLength == MAX_DIGITS */
        cmp     x22, #MAX_DIGITS
        beq     return_false                  /* If lSumLength == MAX_DIGITS, return FALSE */

        /* Set oSum->aulDigits[lSumLength] = 1 */
        mov     x0, #1
        str     x0, [x26, x22, LSL #3]        /* oSum->aulDigits[lSumLength] = 1 */

        /* Increment lSumLength */
        add     x22, x22, #1                  /* lSumLength++ */

        b       set_length

return_false:
        mov     w0, #FALSE                     /* Return value FALSE */
        b       epilogue

set_length:
        /* Set oSum->lLength = lSumLength */
        str     x22, [x21, #LLENGTH_OFFSET]   /* oSum->lLength = lSumLength */

        /* Return TRUE */
        mov     w0, #TRUE

        /*----------------------------------------------------------------*/
epilogue:
        /* Epilogue: Restore callee-saved registers and return */
        ldp     x19, x20, [sp]                /* Restore x19 and x20 */
        ldp     x21, x22, [sp, #8]            /* Restore x21 and x22 */
        ldp     x23, x24, [sp, #24]           /* Restore x23 and x24 */
        ldp     x25, x26, [sp, #40]           /* Restore x25 and x26 */
        ldp     x29, x30, [sp, #56]           /* Restore frame pointer and LR */
        add     sp, sp, STACK_FRAME_SIZE      /* Deallocate stack frame */
        ret                                   /* Return to caller */

/*--------------------------------------------------------------------*/