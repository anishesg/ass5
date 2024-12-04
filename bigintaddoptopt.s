//-----------------------------------------------------------------------
// bigintaddoptopt.s
// Author: anish
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

    stp     x19, x20, [sp, #16]                // Save lSumLength (x19) and lIndex (x20)
    stp     x21, x22, [sp, #32]                // Save ulSum (x21) and ulCarry (x22)
    stp     x23, x24, [sp, #48]                // Save oAddend1 (x23) and oAddend2 (x24)
    stp     x25, x26, [sp, #64]                // Save oSum (x25) and unused register (x26)

    // Move parameters to registers
    mov     x23, x0                            // oAddend1 = x0
    mov     x24, x1                            // oAddend2 = x1
    mov     x25, x2                            // oSum = x2

    // Inlined BigInt_larger logic to determine lSumLength
    ldr     x0, [x23, LENGTH_OFFSET]           // load oAddend1->lLength
    ldr     x1, [x24, LENGTH_OFFSET]           // load oAddend2->lLength
    cmp     x0, x1
    csel    x19, x0, x1, GT                    // lSumLength = (x0 > x1) ? x0 : x1

    // Check if oSum->lLength <= lSumLength
    ldr     x0, [x25, LENGTH_OFFSET]           // load oSum->lLength
    cmp     x0, x19
    ble     skip_clear_digits                   // if oSum->lLength <= lSumLength, skip memset

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    add     x0, x25, DIGITS_OFFSET             // pointer to oSum->aulDigits
    mov     w1, 0                               // value to set
    mov     x2, MAX_DIGITS_COUNT               // size
    lsl     x2, x2, #3                          // multiply by 8 (sizeof unsigned long)
    bl      memset                              // call memset

skip_clear_digits:
    // Initialize ulCarry to 0
    mov     x22, #0

    // Initialize lIndex to 0
    mov     x20, #0

addition_loop:
    // Check if lIndex >= lSumLength
    cmp     x20, x19
    bge     handle_carry                        // if lIndex >= lSumLength, handle carry

    // Load oAddend1->aulDigits[lIndex]
    ldr     x0, [x23, DIGITS_OFFSET]           // base address of oAddend1->aulDigits
    add     x0, x0, x20, LSL #3                 // address of aulDigits[lIndex]
    ldr     x1, [x0]                             // load oAddend1->aulDigits[lIndex]

    // Load oAddend2->aulDigits[lIndex]
    ldr     x2, [x24, DIGITS_OFFSET]           // base address of oAddend2->aulDigits
    add     x2, x2, x20, LSL #3                 // address of aulDigits[lIndex]
    ldr     x3, [x2]                             // load oAddend2->aulDigits[lIndex]

    // Add aulDigits1 + aulDigits2 with carry
    adds    x4, x1, x3                           // x4 = x1 + x3, sets flags
    adcs    x4, x4, x22                          // x4 += ulCarry, sets carry
    // Store the carry
    cset    x22, CC                              // if carry set by adcs, set x22 to 1

    // Store the result into oSum->aulDigits[lIndex]
    ldr     x5, [x25, DIGITS_OFFSET]           // base address of oSum->aulDigits
    add     x5, x5, x20, LSL #3                 // address of oSum->aulDigits[lIndex]
    str     x4, [x5]                             // store the sum

    // Increment lIndex
    add     x20, x20, #1

    // Loop back
    b       addition_loop

handle_carry:
    // Check if ulCarry == 1
    cmp     x22, #1
    bne     finalize_sum_length                   // if ulCarry != 1, skip handling

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     x19, MAX_DIGITS_COUNT
    beq     overflow_detected                       // If equal, overflow occurred

    // Set oSum->aulDigits[lSumLength] = 1
    ldr     x0, [x25, DIGITS_OFFSET]               // base address of oSum->aulDigits
    add     x0, x0, x19, LSL #3                      // address of oSum->aulDigits[lSumLength]
    mov     x1, #1
    str     x1, [x0]                                 // set the carry digit

    // Increment lSumLength
    add     x19, x19, #1

finalize_sum_length:
    // Set oSum->lLength = lSumLength
    str     x19, [x25, LENGTH_OFFSET]              // store lSumLength into oSum->lLength

    // Epilogue: restore stack frame and return
    mov     w0, TRUE_VAL                             // return TRUE_VAL
    ldp     x19, x20, [sp, #16]                      // restore lSumLength and lIndex
    ldp     x21, x22, [sp, #32]                      // restore ulSum and ulCarry
    ldp     x23, x24, [sp, #48]                      // restore oAddend1 and oAddend2
    ldp     x25, x26, [sp, #64]                      // restore oSum and unused register