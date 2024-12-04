//-----------------------------------------------------------------------
// bigintaddoptopt.s
// Author: anish k
// Description: Highly optimized ARMv8 assembly implementation of BigInt_add
//              Incorporates guarded loop pattern, inlines BigInt_larger,
//              and utilizes the ADCS instruction for carry handling.
//-----------------------------------------------------------------------

// Defining constants
.equ    FALSE_VAL, 0
.equ    TRUE_VAL, 1
.equ    MAX_DIGITS_COUNT, 32768

// Structure field offsets for BigInt_T
.equ    LENGTH_OFFSET, 0          // Offset of lLength in BigInt_T
.equ    DIGITS_OFFSET, 8          // Offset of aulDigits in BigInt_T

// Stack byte counts (should be multiples of 16 for alignment)
.equ    ADDITION_STACK_SIZE, 64

// Local variable stack offsets for BigInt_add
.equ    VAR_SUM_LENGTH, 8
.equ    VAR_INDEX, 16
.equ    VAR_SUM, 24

// Parameter stack offsets for BigInt_add
.equ    PARAM_SUM, 40
.equ    PARAM_ADDEND2, 48
.equ    PARAM_ADDEND1, 56

// Assign meaningful register names to variables using .req directives
ULCARRY         .req x22    // ulCarry (No longer needed but kept for compatibility)
ULSUM           .req x23    // ulSum
LINDEX          .req x24    // lIndex
LSUMLENGTH      .req x25    // lSumLength

OADDEND1        .req x26    // oAddend1
OADDEND2        .req x27    // oAddend2
OSUM            .req x28    // oSum

LLARGER         .req x19    // lLarger (Inlined logic)

// Global symbols
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

    // Prologue: Set up the stack frame
    sub     sp, sp, ADDITION_STACK_SIZE
    stp     x30, x19, [sp, 0]                   // Save link register and x19 (LLARGER)
    stp     x20, x21, [sp, 16]                  // Save x20 (unused), x21 (unused)
    stp     x22, x23, [sp, 32]                  // Save ULCARRY and ULSUM
    stp     x24, x25, [sp, 48]                  // Save LINDEX and LSUMLENGTH
    stp     x26, x27, [sp, 64]                  // Save OADDEND1 and OADDEND2
    stp     x28, xzr, [sp, 80]                  // Save OSUM and unused register

    // Move parameters to callee-saved registers
    mov     OADDEND1, x0                         // oAddend1 = x0
    mov     OADDEND2, x1                         // oAddend2 = x1
    mov     OSUM, x2                             // oSum = x2

    // Inline BigInt_larger:
    // Determine lSumLength = max(oAddend1->lLength, oAddend2->lLength)
    ldr     x0, [OADDEND1, LENGTH_OFFSET]         // Load oAddend1->lLength
    ldr     x1, [OADDEND2, LENGTH_OFFSET]         // Load oAddend2->lLength
    cmp     x0, x1
    csel    x25, x0, x1, GT                      // LSUMLENGTH = (x0 > x1) ? x0 : x1

    // Check if oSum->lLength <= lSumLength
    ldr     x0, [OSUM, LENGTH_OFFSET]             // Load oSum->lLength
    cmp     x0, x25
    ble     skip_clear_digits                     // If oSum->lLength <= lSumLength, skip memset

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    add     x0, OSUM, DIGITS_OFFSET               // Pointer to oSum->aulDigits
    mov     w1, 0                                 // Value to set
    mov     x2, MAX_DIGITS_COUNT                 // Number of digits
    lsl     x2, x2, #3                            // Multiply by 8 (size of unsigned long)
    bl      memset                                // Call memset

skip_clear_digits:

    // Initialize lIndex to 0
    mov     x24, 0                                // lIndex = 0

    // Initialize carry flag to 0 using adds
    mov     x0, xzr
    adds    x0, xzr, xzr                          // Clear carry flag

    // Guarded Loop: Check if lIndex < lSumLength before entering loop
    cmp     x24, x25
    bge     handle_carry                           // If lIndex >= lSumLength, skip loop

sumLoop:
    // Load oAddend1->aulDigits[lIndex] into x0
    ldr     x0, [OADDEND1, DIGITS_OFFSET + x24, LSL #3]

    // Load oAddend2->aulDigits[lIndex] into x1
    ldr     x1, [OADDEND2, DIGITS_OFFSET + x24, LSL #3]

    // Add with carry: x0 = oAddend1->digit + oAddend2->digit + carry
    adcs    x0, x0, x1                             // x0 = x0 + x1 + carry

    // Store the result in oSum->aulDigits[lIndex]
    str     x0, [OSUM, DIGITS_OFFSET + x24, LSL #3]

    // Increment lIndex
    add     x24, x24, 1

    // Guarded Loop Condition: Check if lIndex < lSumLength
    cmp     x24, x25
    blt     sumLoop                                // If lIndex < lSumLength, continue loop

handle_carry:
    // Check if carry flag is set (C == 1)
    cset    w4, CC                                 // w4 = (carry set) ? 1 : 0
    cbz     w4, finalize_sum_length                // If carry not set, skip carry handling

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     x25, MAX_DIGITS_COUNT
    beq     overflow_detected                      // If equal, overflow occurred

    // Set oSum->aulDigits[lSumLength] = 1 (carry digit)
    mov     x0, 1                                  // Value to set
    str     x0, [OSUM, DIGITS_OFFSET + x25, LSL #3]

    // Increment lSumLength
    add     x25, x25, 1

finalize_sum_length:
    // Set oSum->lLength = lSumLength
    str     x25, [OSUM, LENGTH_OFFSET]

    // Return TRUE_VAL
    mov     w0, TRUE_VAL

    // Epilogue: Restore stack frame and return
    ldp     x30, x19, [sp, 0]                      // Restore link register and x19 (LLARGER)
    ldp     x20, x21, [sp, 16]                     // Restore x20 and x21
    ldp     x22, x23, [sp, 32]                     // Restore ULCARRY and ULSUM
    ldp     x24, x25, [sp, 48]                     // Restore LINDEX and LSUMLENGTH
    ldp     x26, x27, [sp, 64]                     // Restore OADDEND1 and OADDEND2
    ldp     x28, xzr, [sp, 80]                     // Restore OSUM and unused register
    add     sp, sp, ADDITION_STACK_SIZE
    ret

overflow_detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL

    // Epilogue: Restore stack frame and return
    ldp     x30, x19, [sp, 0]                      // Restore link register and x19 (LLARGER)
    ldp     x20, x21, [sp, 16]                     // Restore x20 and x21
    ldp     x22, x23, [sp, 32]                     // Restore ULCARRY and ULSUM
    ldp     x24, x25, [sp, 48]                     // Restore LINDEX and LSUMLENGTH
    ldp     x26, x27, [sp, 64]                     // Restore OADDEND1 and OADDEND2
    ldp     x28, xzr, [sp, 80]                     // Restore OSUM and unused register
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size BigInt_add, .-BigInt_add