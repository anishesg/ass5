//-----------------------------------------------------------------------
// bigintaddoptopt.s
// Author: Anish K 
// Description: Highly optimized ARMv8 assembly implementation of BigInt_add
//              with inlined BigInt_larger, guarded loop pattern, and 
//              effective use of ADCS instruction for carry handling.
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
.equ    VAR_SUM, 24
.equ    VAR_CARRY, 32

.equ    PARAM_SUM, 40
.equ    PARAM_ADDEND2, 48
.equ    PARAM_ADDEND1, 56

// Register aliases using .req directives
ULSUM           .req    x19    // ulSum
LINDEX          .req    x20    // lIndex
LSUMLENGTH      .req    x21    // lSumLength

OADDEND1        .req    x22    // oAddend1
OADDEND2        .req    x23    // oAddend2
OSUM            .req    x24    // oSum

// Callee-saved registers that will be used
// x19, x20, x21, x22, x23, x24

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
    stp     x30, x19, [sp, 0]                 // save link register and x19
    stp     x20, x21, [sp, 16]                // save x20, x21
    stp     x22, x23, [sp, 32]                // save x22, x23
    stp     x24, x25, [sp, 48]                // save x24, x25

    // Move parameters to callee-saved registers
    mov     OADDEND1, x0                       // oAddend1 = x0
    mov     OADDEND2, x1                       // oAddend2 = x1
    mov     OSUM, x2                           // oSum = x2

    // Inline BigInt_larger:
    // Determine lSumLength = max(oAddend1->lLength, oAddend2->lLength)
    ldr     x5, [OADDEND1, LENGTH_OFFSET]       // load oAddend1->lLength
    ldr     x6, [OADDEND2, LENGTH_OFFSET]       // load oAddend2->lLength
    cmp     x5, x6
    movgt   x21, x5                            // if oAddend1->lLength > oAddend2->lLength, lSumLength = oAddend1->lLength
    movle   x21, x6                            // else, lSumLength = oAddend2->lLength

    // Check if oSum->lLength <= lSumLength
    ldr     x7, [OSUM, LENGTH_OFFSET]           // load oSum->lLength
    cmp     x7, x21
    ble     skip_clear_digits                   // if oSum->lLength <= lSumLength, skip memset

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    add     x0, OSUM, DIGITS_OFFSET             // pointer to oSum->aulDigits
    mov     w1, 0                               // value to set
    mov     x2, MAX_DIGITS_COUNT               // number of digits
    lsl     x2, x2, #3                          // size = MAX_DIGITS_COUNT * 8
    bl      memset                              // call memset

skip_clear_digits:
    // Initialize lIndex to 0
    mov     x20, 0                              // lIndex = 0

    // Initialize ulSum to 0
    mov     x19, 0                              // ulSum = 0

    // Initialize carry flag to 0 by clearing the carry
    clrex                                      // Clear exclusive monitor (optional, safety)
    mov     x25, 0                              // lSumLength will be updated later if carry occurs

    // Guarded loop setup
    // Compute the end address based on lSumLength
    mov     x9, x21                             // end = lSumLength
    cmp     x20, x9
    bge     handle_carry                        // if lIndex >= lSumLength, handle carry

addition_guarded_loop:
    // Load digits from oAddend1 and oAddend2
    ldr     x10, [OADDEND1, DIGITS_OFFSET]      // base address of oAddend1->aulDigits
    add     x10, x10, x20, lsl #3               // address of oAddend1->aulDigits[lIndex]
    ldr     x11, [x10]                           // load oAddend1->aulDigits[lIndex]

    ldr     x12, [OADDEND2, DIGITS_OFFSET]      // base address of oAddend2->aulDigits
    add     x12, x12, x20, lsl #3               // address of oAddend2->aulDigits[lIndex]
    ldr     x13, [x12]                           // load oAddend2->aulDigits[lIndex]

    // Perform addition with carry
    adcs    x19, x19, x11                        // ulSum += oAddend1->aulDigits[lIndex] + carry
    adcs    x19, x19, x13                        // ulSum += oAddend2->aulDigits[lIndex] + carry

    // Store the result in oSum->aulDigits[lIndex]
    ldr     x14, [OSUM, DIGITS_OFFSET]           // base address of oSum->aulDigits
    add     x14, x14, x20, lsl #3                // address of oSum->aulDigits[lIndex]
    str     x19, [x14]                            // store ulSum

    // Increment lIndex
    add     x20, x20, 1                           // lIndex++

    // Check if lIndex < lSumLength
    cmp     x20, x9
    blt     addition_guarded_loop                  // continue loop if lIndex < lSumLength

handle_carry:
    // After loop, check the carry flag
    cset    w0, CS                                // w0 = 1 if carry set, else 0

    cmp     w0, 1
    bne     finalize_sum_length                   // if no carry, finalize sum length

    // Handle carry out
    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     x21, MAX_DIGITS_COUNT
    beq     overflow_detected                      // if lSumLength == MAX_DIGITS_COUNT, overflow

    // Set oSum->aulDigits[lSumLength] = 1
    ldr     x15, [OSUM, DIGITS_OFFSET]           // base address of oSum->aulDigits
    add     x15, x15, x21, lsl #3                // address of oSum->aulDigits[lSumLength]
    mov     x16, 1
    str     x16, [x15]                            // set carry digit to 1

    // Increment lSumLength
    add     x21, x21, 1                           // lSumLength++

finalize_sum_length:
    // Set oSum->lLength = lSumLength
    str     x21, [OSUM, LENGTH_OFFSET]            // store lSumLength into oSum->lLength

    // Set return value to TRUE_VAL
    mov     w0, TRUE_VAL

    // Epilogue: restore stack frame and return
    ldp     x30, x19, [sp, 0]                     // restore link register and x19
    ldp     x20, x21, [sp, 16]                    // restore x20, x21
    ldp     x22, x23, [sp, 32]                    // restore oAddend1, oAddend2
    ldp     x24, x25, [sp, 48]                    // restore oSum, lSumLength
    add     sp, sp, ADDITION_STACK_SIZE
    ret

overflow_detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    // Epilogue: restore stack frame and return
    ldp     x30, x19, [sp, 0]                     // restore link register and x19
    ldp     x20, x21, [sp, 16]                    // restore x20, x21
    ldp     x22, x23, [sp, 32]                    // restore oAddend1, oAddend2
    ldp     x24, x25, [sp, 48]                    // restore oSum, lSumLength
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add