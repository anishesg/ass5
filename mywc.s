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
.equ    ADDITION_STACK_SIZE, 64

// Local variable registers using .req directives
// For BigInt_add
.equ    LSUMLENGTH_OFFSET, 8
.equ    LINDEX_OFFSET, 16
.equ    ULCARRY_OFFSET, 24
.equ    ULSUM_OFFSET, 32
.equ    OADDEND1_OFFSET, 40 
.equ    OADDEND2_OFFSET, 48
.equ    OSUM_OFFSET, 56

// Assign meaningful register names to variables
ULCARRY         .req x22    // ulCarry
ULSUM           .req x23    // ulSum
LINDEX          .req x24    // lIndex
LSUMLENGTH      .req x25    // lSumLength

OADDEND1        .req x26    // oAddend1
OADDEND2        .req x27    // oAddend2
OSUM            .req x28    // oSum

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

    stp     x22, x23, [sp, #16]                // Save ulCarry and ulSum
    stp     x24, x25, [sp, #32]                // Save lIndex and lSumLength
    stp     x26, x27, [sp, #48]                // Save oAddend1 and oAddend2
    stp     x28, x9, [sp, #64]                 // Save oSum and unused register (x9)

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
    mov     x2, MAX_DIGITS_COUNT               // size
    lsl     x2, x2, #3                          // multiply by 8 (sizeof(unsigned long))
    bl      memset                              // call memset

skip_clear_digits:
    // Initialize ulCarry to 0
    mov     ULCARRY, 0

    // Initialize lIndex to 0
    mov     LINDEX, 0

addition_loop:
    // Check if lIndex >= lSumLength
    cmp     LINDEX, x25
    bge     handle_carry                        // if lIndex >= lSumLength, handle carry

    // Load oAddend1->aulDigits[lIndex]
    ldr     x1, [OADDEND1, DIGITS_OFFSET]       // base address of oAddend1->aulDigits
    add     x1, x1, LINDEX, LSL #3              // address of aulDigits[lIndex]
    ldr     x2, [x1]                             // load oAddend1->aulDigits[lIndex]

    // Load oAddend2->aulDigits[lIndex]
    ldr     x3, [OADDEND2, DIGITS_OFFSET]       // base address of oAddend2->aulDigits
    add     x3, x3, LINDEX, LSL #3              // address of aulDigits[lIndex]
    ldr     x4, [x3]                             // load oAddend2->aulDigits[lIndex]

    // Add with carry
    add     x5, x2, x4                           // temp sum = aulDigits1 + aulDigits2
    adc     x6, xzr, xzr                         // ulCarry = carry from addition

    // Add carry from previous iteration
    adcs    x5, x5, xzr                          // x5 += ulCarry, update carry
    mov     ULCARRY, xzr                         // Reset ulCarry (handled by adcs)

    // Store the result into oSum->aulDigits[lIndex]
    ldr     x7, [OSUM, DIGITS_OFFSET]           // base address of oSum->aulDigits
    add     x7, x7, LINDEX, LSL #3              // address of oSum->aulDigits[lIndex]
    str     x5, [x7]                             // store the sum

    // Increment lIndex
    add     LINDEX, LINDEX, 1

    // Loop back
    b       addition_loop

handle_carry:
    // Check if there was a carry from the last addition
    cset    w9, CC                                 // Set w9 to carry flag
    cmp     w9, 0
    beq     finalize_sum_length                     // If no carry, finalize

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     x25, MAX_DIGITS_COUNT
    beq     overflow_detected                       // If equal, overflow occurred

    // Set oSum->aulDigits[lSumLength] = 1
    ldr     x0, [OSUM, DIGITS_OFFSET]               // base address of oSum->aulDigits
    add     x0, x0, x25, LSL #3                      // address of oSum->aulDigits[lSumLength]
    mov     x1, 1
    str     x1, [x0]                                 // set the carry digit

    // Increment lSumLength
    add     x25, x25, 1

finalize_sum_length:
    // Set oSum->lLength = lSumLength
    str     x25, [OSUM, LENGTH_OFFSET]              // store lSumLength into oSum->lLength

    // Epilogue: restore stack frame and return
    mov     w0, TRUE_VAL                             // return TRUE_VAL
    ldp     x22, x23, [sp, #16]                      // restore ulCarry and ulSum
    ldp     x24, x25, [sp, #32]                      // restore lIndex and lSumLength
    ldp     x26, x27, [sp, #48]                      // restore oAddend1 and oAddend2
    ldp     x28, x9, [sp, #64]                       // restore oSum and unused register
    ldp     x29, x30, [sp, #0]                       // restore frame pointer and link register
    add     sp, sp, ADDITION_STACK_SIZE              // deallocate stack frame
    ret

overflow_detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    ldp     x22, x23, [sp, #16]                      // restore ulCarry and ulSum
    ldp     x24, x25, [sp, #32]                      // restore lIndex and lSumLength
    ldp     x26, x27, [sp, #48]                      // restore oAddend1 and oAddend2
    ldp     x28, x9, [sp, #64]                       // restore oSum and unused register
    ldp     x29, x30, [sp, #0]                       // restore frame pointer and link register
    add     sp, sp, ADDITION_STACK_SIZE              // deallocate stack frame
    ret

.size   BigInt_add, .-BigInt_add