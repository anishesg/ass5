//-----------------------------------------------------------------------
// bigintaddoptopt.s
// Author: Anish K.
// Description: Highly optimized ARMv8 assembly implementation of BigInt_add
//              with inlined BigInt_larger and guarded loop pattern.
//              Utilizes the 'adcs' instruction for efficient carry handling.
//-----------------------------------------------------------------------

// Defining constants
.equ    FALSE_VAL, 0
.equ    TRUE_VAL, 1
.equ    MAX_DIGITS_COUNT, 32768

// Structure field offsets for BigInt_T
.equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
.equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T

// Stack byte counts (must be multiples of 16 for alignment)
.equ    ADDITION_STACK_SIZE, 64

// Local variable stack offsets for BigInt_add
.equ    VAR_SUM_LENGTH, 8
.equ    VAR_INDEX, 16
.equ    VAR_SUM, 24
.equ    VAR_CARRY, 32
.equ    PARAM_OADDEND1, 40
.equ    PARAM_OADDEND2, 48
.equ    PARAM_OSUM, 56

// Register aliases using .req for clarity
ULSUM           .req    x23    // ulSum
LINDEX          .req    x24    // lIndex
LSUMLENGTH      .req    x25    // lSumLength
OADDEND1        .req    x26    // oAddend1
OADDEND2        .req    x27    // oAddend2
OSUM            .req    x28    // oSum

// Additional temporary registers
TEMP1           .req    x19    // Temporary register 1
TEMP2           .req    x20    // Temporary register 2

.global BigInt_add

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

BigInt_add:

    // Prologue: set up the stack frame
    sub     sp, sp, ADDITION_STACK_SIZE
    stp     x30, x19, [sp]                     // Save link register and TEMP1
    stp     x20, x21, [sp, 16]                 // Save TEMP2 and unused (alignment)
    stp     x22, x23, [sp, 32]                 // Save ULCARRY and ULSUM
    stp     x24, x25, [sp, 48]                 // Save LINDEX and LSUMLENGTH
    stp     x26, x27, [sp, 56]                 // Save OADDEND1 and OADDEND2
    stp     x28, xzr, [sp, 64]                 // Save OSUM and unused

    // Move parameters to designated registers
    mov     OADDEND1, x0                        // oAddend1 = x0
    mov     OADDEND2, x1                        // oAddend2 = x1
    mov     OSUM, x2                            // oSum = x2

    // Inlined BigInt_larger:
    // Determine the larger length: lSumLength = max(oAddend1->lLength, oAddend2->lLength)

    ldr     TEMP1, [OADDEND1, LENGTH_OFFSET]     // TEMP1 = oAddend1->lLength
    ldr     TEMP2, [OADDEND2, LENGTH_OFFSET]     // TEMP2 = oAddend2->lLength
    cmp     TEMP1, TEMP2
    csel    LSUMLENGTH, TEMP1, TEMP2, GT        // LSUMLENGTH = (TEMP1 > TEMP2) ? TEMP1 : TEMP2

    // Check if oSum->lLength > lSumLength
    ldr     TEMP1, [OSUM, LENGTH_OFFSET]         // TEMP1 = oSum->lLength
    cmp     TEMP1, LSUMLENGTH
    ble     Skip_Clear_Digits                    // If oSum->lLength <= lSumLength, skip memset

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    add     x0, OSUM, DIGITS_OFFSET              // x0 = &oSum->aulDigits
    mov     w1, 0                                // Value to set (0)
    mov     x2, MAX_DIGITS_COUNT                // Number of digits
    lsl     x2, x2, #3                           // Size in bytes (8 * MAX_DIGITS_COUNT)
    bl      memset                               // Call memset

Skip_Clear_Digits:

    // Initialize carry flag to 0 (no carry)
    mov     x0, 0                                // Clear carry flag
    // Initialize lIndex to 0
    mov     LINDEX, 0                            // lIndex = 0

    // Initialize LSUMLENGTH if oSum->lLength was modified by memset
    ldr     TEMP1, [OSUM, LENGTH_OFFSET]         // Reload oSum->lLength
    mov     LSUMLENGTH, TEMP1                     // lSumLength = oSum->lLength

    // Initialize the sum digits in oSum to 0 up to lSumLength if needed
    // Not necessary here since we used memset if required

    // Guarded Loop Pattern:
    // Initialize loop counters and set up the loop to handle carry using adcs

Loop_Start:
    // Compare lIndex with lSumLength
    cmp     LINDEX, LSUMLENGTH
    bge     Check_Carry_Out                      // If lIndex >= lSumLength, exit loop

    // Load digits from oAddend1 and oAddend2
    ldr     x1, [OADDEND1, DIGITS_OFFSET + LINDEX, lsl #3] // x1 = oAddend1->aulDigits[lIndex]
    ldr     x2, [OADDEND2, DIGITS_OFFSET + LINDEX, lsl #3] // x2 = oAddend2->aulDigits[lIndex]

    // Perform addition with carry
    add     x3, x1, x2                           // x3 = oAddend1->aulDigits[lIndex] + oAddend2->aulDigits[lIndex]
    adcs    ULSUM, x3, xzr                        // ULSUM = x3 + carry (C flag)
    str     ULSUM, [OSUM, DIGITS_OFFSET + LINDEX, lsl #3] // oSum->aulDigits[lIndex] = ULSUM

    // Increment lIndex
    add     LINDEX, LINDEX, 1                     // lIndex++

    // Loop back
    b       Loop_Start

Check_Carry_Out:
    // After the loop, check if there was a carry out
    // The carry flag is already set by the last adcs instruction

    // If carry flag is not set, skip carry handling
    cbnz    xzr, Handle_Carry                     // If carry flag is set, handle carry

    // Set lSumLength to lSumLength
    // Already set, no action needed

    // Jump to finalize
    b       Finalize_Sum_Length

Handle_Carry:
    // Check if lSumLength < MAX_DIGITS_COUNT
    cmp     LSUMLENGTH, MAX_DIGITS_COUNT
    bge     Overflow_Detected                     // If lSumLength >= MAX_DIGITS_COUNT, overflow

    // Set oSum->aulDigits[lSumLength] = 1 to account for carry
    mov     x1, 1                                // x1 = 1
    str     x1, [OSUM, DIGITS_OFFSET + LSUMLENGTH, lsl #3] // oSum->aulDigits[lSumLength] = 1

    // Increment lSumLength
    add     LSUMLENGTH, LSUMLENGTH, 1             // lSumLength++

Finalize_Sum_Length:
    // Update oSum->lLength = lSumLength
    str     LSUMLENGTH, [OSUM, LENGTH_OFFSET]    // oSum->lLength = lSumLength

    // Set return value to TRUE_VAL (1)
    mov     w0, TRUE_VAL

    // Epilogue: restore stack frame and return
    ldp     x30, x19, [sp]                        // Restore link register and TEMP1
    ldp     x20, x21, [sp, 16]                    // Restore TEMP2 and unused
    ldp     x22, x23, [sp, 32]                    // Restore ULCARRY and ULSUM
    ldp     x24, x25, [sp, 48]                    // Restore LINDEX and LSUMLENGTH
    ldp     x26, x27, [sp, 56]                    // Restore OADDEND1 and OADDEND2
    ldp     x28, xzr, [sp, 64]                    // Restore OSUM and unused
    add     sp, sp, ADDITION_STACK_SIZE           // Deallocate stack frame
    ret

Overflow_Detected:
    // Set return value to FALSE_VAL (0) due to overflow
    mov     w0, FALSE_VAL

    // Epilogue: restore stack frame and return
    ldp     x30, x19, [sp]                        // Restore link register and TEMP1
    ldp     x20, x21, [sp, 16]                    // Restore TEMP2 and unused
    ldp     x22, x23, [sp, 32]                    // Restore ULCARRY and ULSUM
    ldp     x24, x25, [sp, 48]                    // Restore LINDEX and LSUMLENGTH
    ldp     x26, x27, [sp, 56]                    // Restore OADDEND1 and OADDEND2
    ldp     x28, xzr, [sp, 64]                    // Restore OSUM and unused
    add     sp, sp, ADDITION_STACK_SIZE           // Deallocate stack frame
    ret

.size   BigInt_add, .-BigInt_add