//-----------------------------------------------------------------------
// bigintaddoptopt.s
// Author: Anish K
// Description: Highly Optimized ARMv8 Assembly Implementation of BigInt_add
//              Incorporates Guarded Loop Pattern, Inlined BigInt_larger,
//              and Effective Use of ADCS Instruction
//-----------------------------------------------------------------------

// Defining constants
.equ    FALSE_VAL, 0
.equ    TRUE_VAL, 1
.equ    MAX_DIGITS_COUNT, 32768

// Structure field offsets for BigInt_T
.equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
.equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T

// Stack byte counts (should be multiples of 16 for alignment)
.equ    ADDITION_STACK_SIZE, 64

// Local variable stack offsets for BigInt_add
.equ    VAR_SUM_LENGTH, 8
.equ    VAR_INDEX, 16

// Parameter stack offsets for BigInt_add
.equ    PARAM_SUM, 24
.equ    PARAM_ADDEND2, 32
.equ    PARAM_ADDEND1, 40

// Assign meaningful register names to variables using .req directives
// Using callee-saved registers to minimize stack accesses
.equ    ULCARRY_REG, x22    // ulCarry (Carry flag)
.equ    ULSUM_REG, x23      // ulSum
.equ    LINDEX_REG, x24     // lIndex
.equ    LSUMLENGTH_REG, x25 // lSumLength

.equ    OADDEND1_REG, x26    // oAddend1
.equ    OADDEND2_REG, x27    // oAddend2
.equ    OSUM_REG, x28        // oSum

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
    sub     sp, sp, ADDITION_STACK_SIZE       // Allocate stack space
    stp     x30, x19, [sp, 0]                  // Save link register and x19
    stp     x20, x21, [sp, 16]                 // Save x20, x21

    // Move parameters to callee-saved registers
    mov     OADDEND1_REG, x0                    // oAddend1 = x0
    mov     OADDEND2_REG, x1                    // oAddend2 = x1
    mov     OSUM_REG, x2                        // oSum = x2

    // Inline BigInt_larger: Determine lSumLength = max(oAddend1->lLength, oAddend2->lLength)
    ldr     x19, [OADDEND1_REG, LENGTH_OFFSET]  // Load oAddend1->lLength into x19
    ldr     x20, [OADDEND2_REG, LENGTH_OFFSET]  // Load oAddend2->lLength into x20
    cmp     x19, x20                            // Compare lLength1 and lLength2
    cset    w25, HI                             // Set w25 to 1 if lLength1 > lLength2
    mov     x25, x19                            // Move lLength1 to x25 (lSumLength)
    csel    x25, x20, x25, LT                   // If lLength1 <= lLength2, set lSumLength = lLength2

    // Initialize lSumLength
    mov     LSUMLENGTH_REG, x25                  // lSumLength = max(lLength1, lLength2)

    // Check if oSum->lLength <= lSumLength
    ldr     x21, [OSUM_REG, LENGTH_OFFSET]       // Load oSum->lLength into x21
    cmp     x21, x25                             // Compare oSum->lLength and lSumLength
    ble     skip_clear_digits                    // If oSum->lLength <= lSumLength, skip memset

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    add     x0, OSUM_REG, DIGITS_OFFSET          // Pointer to oSum->aulDigits
    mov     w1, 0                                // Value to set
    mov     x2, MAX_DIGITS_COUNT                // Number of digits
    lsl     x2, x2, #3                           // Multiply by 8 (sizeof(unsigned long))
    bl      memset                               // Call memset

skip_clear_digits:
    // Initialize ulCarry to 0
    mov     ULCARRY_REG, xzr                     // ulCarry = 0

    // Initialize lIndex to 0
    mov     LINDEX_REG, xzr                      // lIndex = 0

    // Guarded Loop Pattern Start
    cmp     LINDEX_REG, LSUMLENGTH_REG           // Compare lIndex with lSumLength
    bge     handle_carry                         // If lIndex >= lSumLength, handle carry

sumLoop:
    // Load oAddend1->aulDigits[lIndex] into x4
    ldr     x4, [OADDEND1_REG, DIGITS_OFFSET]    // Base address of oAddend1->aulDigits
    add     x4, x4, LINDEX_REG, LSL #3           // Address of aulDigits[lIndex]
    ldr     x4, [x4]                              // Load oAddend1->aulDigits[lIndex]

    // Load oAddend2->aulDigits[lIndex] into x5
    ldr     x5, [OADDEND2_REG, DIGITS_OFFSET]    // Base address of oAddend2->aulDigits
    add     x5, x5, LINDEX_REG, LSL #3           // Address of aulDigits[lIndex]
    ldr     x5, [x5]                              // Load oAddend2->aulDigits[lIndex]

    // Load oSum->aulDigits[lIndex] into x6 (optional, not needed here)

    // Perform addition with carry: ulSum = oAddend1->digits + oAddend2->digits + ulCarry
    // Using ADDS and ADCS for efficient carry handling
    add     x6, x4, x5                            // x6 = oAddend1->digits + oAddend2->digits
    adcs    x6, x6, ULCARRY_REG                   // x6 = x6 + ulCarry with carry

    // Store ulSum back to oSum->aulDigits[lIndex]
    str     x6, [OSUM_REG, DIGITS_OFFSET]         // Store ulSum

    // Update ulCarry based on carry flag
    // After ADCS, the carry flag is set if there was a carry out
    // So, we can set ulCarry = 1 if carry flag is set, else 0
    cset    w22, C                                // Set w22 to 1 if carry flag is set, else 0
    mov     ULCARRY_REG, x22                       // ulCarry = (w22)

    // Increment lIndex
    add     LINDEX_REG, LINDEX_REG, 1              // lIndex++

    // Guarded Loop Condition Check
    cmp     LINDEX_REG, LSUMLENGTH_REG            // Compare lIndex with lSumLength
    blt     sumLoop                                // If lIndex < lSumLength, continue loop

handle_carry:
    // After loop, check if there was a carry out of the last addition
    cmp     ULCARRY_REG, 1                         // Check if ulCarry == 1
    bne     finalize_sum_length                     // If ulCarry != 1, skip carry handling

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     LSUMLENGTH_REG, MAX_DIGITS_COUNT        // Compare lSumLength with MAX_DIGITS_COUNT
    beq     overflow_detected                       // If equal, overflow occurred

    // Set oSum->aulDigits[lSumLength] = 1 (handle carry)
    add     x0, OSUM_REG, DIGITS_OFFSET             // Pointer to oSum->aulDigits
    add     x0, x0, LSUMLENGTH_REG, LSL #3          // Address of aulDigits[lSumLength]
    mov     x1, 1                                   // Value to set
    str     x1, [x0]                                 // Set carry digit

    // Increment lSumLength
    add     LSUMLENGTH_REG, LSUMLENGTH_REG, 1        // lSumLength++

finalize_sum_length:
    // Set oSum->lLength = lSumLength
    str     LSUMLENGTH_REG, [OSUM_REG, LENGTH_OFFSET] // oSum->lLength = lSumLength

    // Return TRUE_VAL
    mov     w0, TRUE_VAL

    // Epilogue: restore stack frame and return
    ldp     x30, x19, [sp, 0]                      // Restore link register and x19
    ldp     x20, x21, [sp, 16]                     // Restore x20, x21
    add     sp, sp, ADDITION_STACK_SIZE            // Deallocate stack space
    ret

overflow_detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    // Epilogue: restore stack frame and return
    ldp     x30, x19, [sp, 0]                      // Restore link register and x19
    ldp     x20, x21, [sp, 16]                     // Restore x20, x21
    add     sp, sp, ADDITION_STACK_SIZE            // Deallocate stack space
    ret

.size   BigInt_add, .-BigInt_add