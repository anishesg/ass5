
// Defining constants
.equ    FALSE_VAL, 0
.equ    TRUE_VAL, 1
.equ    MAX_DIGITS_COUNT, 32768

// Structure field offsets for BigInt_T
.equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
.equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T

// Stack byte counts (should be multiples of 16 for alignment)
.equ    ADDITION_STACK_SIZE, 48  // Reduced stack size after optimizations

// Assign meaningful register names to variables using .req directives
ULSUM           .req x23    // ulSum
LINDEX          .req x24    // lIndex
LSUMLENGTH      .req x25    // lSumLength

OADDEND1        .req x26    // oAddend1
OADDEND2        .req x27    // oAddend2
OSUM            .req x28    // oSum

// Remove LLARGER, LLENGTH1, LLENGTH2 as they are inlined

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
    stp     x29, x30, [sp, #-16]!            // Save frame pointer and link register
    mov     x29, sp                          // Set frame pointer

    // Move parameters to callee-saved registers
    mov     OADDEND1, x0                      // oAddend1 = x0
    mov     OADDEND2, x1                      // oAddend2 = x1
    mov     OSUM, x2                          // oSum = x2

    // Determine the larger length: lSumLength = max(oAddend1->lLength, oAddend2->lLength)
    ldr     x19, [OADDEND1, LENGTH_OFFSET]     // load oAddend1->lLength into x19
    ldr     x20, [OADDEND2, LENGTH_OFFSET]     // load oAddend2->lLength into x20
    cmp     x19, x20                          // compare lLength1 and lLength2
    bgt     set_lsumlength1                    // if lLength1 > lLength2, set lSumLength = lLength1
    mov     LSUMLENGTH, x20                    // else, lSumLength = lLength2
    b       after_lsumlength

set_lsumlength1:
    mov     LSUMLENGTH, x19                    // lSumLength = lLength1

after_lsumlength:

    // Check if oSum->lLength <= lSumLength
    ldr     x21, [OSUM, LENGTH_OFFSET]         // load oSum->lLength into x21
    cmp     x21, LSUMLENGTH
    ble     skip_clear_digits                   // if oSum->lLength <= lSumLength, skip memset

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    add     x0, OSUM, DIGITS_OFFSET            // pointer to oSum->aulDigits
    mov     w1, 0                              // value to set
    mov     x2, MAX_DIGITS_COUNT               // size
    lsl     x2, x2, #3                         // multiply by 8 (sizeof(unsigned long))
    bl      memset                              // call memset

skip_clear_digits:

    // Initialize lIndex to 0
    mov     LINDEX, 0

    // Initialize carry flag to zero (C flag cleared)
    clrex                                     // Clear exclusive monitors and reset flags
    orr     xzr, xzr, xzr                      // Ensure carry flag is cleared

sumLoop:
    // Guarded loop condition: if (lIndex >= lSumLength) exit loop
    cmp     LINDEX, LSUMLENGTH
    bge     handle_carry                       // if lIndex >= lSumLength, handle carry

    // Load oAddend1->aulDigits[lIndex]
    add     x29, OADDEND1, DIGITS_OFFSET        // x29 = OADDEND1 + DIGITS_OFFSET
    add     x29, x29, LINDEX, lsl #3            // x29 += LINDEX << 3
    ldr     x0, [x29]                            // x0 = oAddend1->aulDigits[lIndex]

    // Add oAddend1->aulDigits[lIndex] to ulSum with carry
    adcs    ULSUM, ULSUM, x0                      // ulSum = ulSum + oAddend1->aulDigits[lIndex] + carry

    // Load oAddend2->aulDigits[lIndex]
    add     x30, OADDEND2, DIGITS_OFFSET        // x30 = OADDEND2 + DIGITS_OFFSET
    add     x30, x30, LINDEX, lsl #3            // x30 += LINDEX << 3
    ldr     x1, [x30]                            // x1 = oAddend2->aulDigits[lIndex]

    // Add oAddend2->aulDigits[lIndex] to ulSum with carry
    adcs    ULSUM, ULSUM, x1                      // ulSum = ulSum + oAddend2->aulDigits[lIndex] + carry

    // Store ulSum into oSum->aulDigits[lIndex]
    add     x31, OSUM, DIGITS_OFFSET            // x31 = OSUM + DIGITS_OFFSET
    add     x31, x31, LINDEX, lsl #3            // x31 += LINDEX << 3
    str     x23, [x31]                             // oSum->aulDigits[lIndex] = ulSum

    // Increment lIndex
    add     LINDEX, LINDEX, 1

    // Repeat the loop
    b       sumLoop

handle_carry:
    // Check if carry flag is set
    bcc     finalize_sum_length                 // if carry flag is not set, skip handling

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     LSUMLENGTH, MAX_DIGITS_COUNT
    beq     overflow_detected                   // if equal, overflow occurred

    // Set oSum->aulDigits[lSumLength] = 1
    add     x0, OSUM, DIGITS_OFFSET            // pointer to oSum->aulDigits
    add     x0, x0, LSUMLENGTH, lsl #3         // address of oSum->aulDigits[lSumLength]
    mov     x1, 1
    str     x1, [x0]                             // set the carry digit

    // Increment lSumLength
    add     LSUMLENGTH, LSUMLENGTH, 1

finalize_sum_length:
    // Set oSum->lLength = lSumLength
    str     LSUMLENGTH, [OSUM, LENGTH_OFFSET]   // store lSumLength into oSum->lLength

    // Epilogue: restore stack frame and return
    mov     w0, TRUE_VAL                        // return TRUE_VAL
    ldp     x29, x30, [sp], #16                  // Restore frame pointer and link register
    add     sp, sp, ADDITION_STACK_SIZE
    ret

overflow_detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL                       // return FALSE_VAL
    ldp     x29, x30, [sp], #16                  // Restore frame pointer and link register
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add