//-----------------------------------------------------------------------
// bigintaddoptopt.s
// Author: Anish K
// Description: Highly optimized ARMv8 assembly implementation of BigInt_add
//              Function includes inlining of BigInt_larger and uses
//              guarded loop pattern with ADC instructions.
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

// Register aliases using .req directives for clarity
LSUM_LENGTH_REG .req x19      // lSumLength
LINDEX_REG       .req x20      // lIndex
OADDEND1_REG     .req x21      // oAddend1
OADDEND2_REG     .req x22      // oAddend2
OSUM_REG         .req x23      // oSum

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

    // Prologue: Set up the stack frame and save callee-saved registers
    sub     sp, sp, ADDITION_STACK_SIZE
    stp     x29, x30, [sp, #0]               // Save frame pointer and link register
    mov     x29, sp                          // Set frame pointer
    stp     LSUM_LENGTH_REG, LINDEX_REG, [sp, #16]  // Save lSumLength and lIndex
    stp     OADDEND1_REG, OADDEND2_REG, [sp, #32]    // Save oAddend1 and oAddend2
    stp     OSUM_REG, x24, [sp, #48]         // Save oSum and an unused register (x24)

    // Move parameters to callee-saved registers
    mov     OADDEND1_REG, x0                  // oAddend1 = x0
    mov     OADDEND2_REG, x1                  // oAddend2 = x1
    mov     OSUM_REG, x2                      // oSum = x2

    // Inline BigInt_larger: Determine lSumLength = max(oAddend1->lLength, oAddend2->lLength)
    ldr     x4, [OADDEND1_REG, LENGTH_OFFSET] // Load oAddend1->lLength
    ldr     x5, [OADDEND2_REG, LENGTH_OFFSET] // Load oAddend2->lLength
    cmp     x4, x5
    csel    LSUM_LENGTH_REG, x4, x5, GT      // If oAddend1->lLength > oAddend2->lLength, set lSumLength = oAddend1->lLength
                                             // Else, set lSumLength = oAddend2->lLength

    // Check if oSum->lLength > lSumLength
    ldr     x6, [OSUM_REG, LENGTH_OFFSET]     // Load oSum->lLength
    cmp     x6, LSUM_LENGTH_REG
    ble     Skip_Clear_Digits                  // If oSum->lLength <= lSumLength, skip clearing digits

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    mov     x0, OSUM_REG                      // oSum
    add     x0, x0, DIGITS_OFFSET             // oSum->aulDigits
    mov     w1, 0                              // value to set
    mov     x2, MAX_DIGITS_COUNT              // number of digits
    lsl     x2, x2, #3                        // multiply by 8 (sizeof(unsigned long))
    bl      memset                             // Call memset

Skip_Clear_Digits:
    // Initialize lIndex to 0
    mov     LINDEX_REG, #0

    // Initialize carry flag to 0 by ensuring no carry is set
    // ARMv8 does not have a direct instruction to clear the carry flag,
    // but ensuring the first addition does not carry will suffice.

    // Guarded Loop Pattern with ADC
Loop_Start:
    // Compare lIndex with lSumLength
    cmp     LINDEX_REG, LSUM_LENGTH_REG
    bge     Handle_Carry                       // If lIndex >= lSumLength, handle carry

    // Load oAddend1->aulDigits[lIndex]
    ldr     x4, [OADDEND1_REG, DIGITS_OFFSET] // Pointer to oAddend1->aulDigits
    add     x4, x4, LINDEX_REG, lsl #3         // Address of aulDigits[lIndex]
    ldr     x4, [x4]                            // Load aulDigits[lIndex]

    // Load oAddend2->aulDigits[lIndex]
    ldr     x5, [OADDEND2_REG, DIGITS_OFFSET] // Pointer to oAddend2->aulDigits
    add     x5, x5, LINDEX_REG, lsl #3         // Address of aulDigits[lIndex]
    ldr     x5, [x5]                            // Load aulDigits[lIndex]

    // Add with carry: ULSUM = aulDigits1 + aulDigits2 + carry
    adc     x6, x4, x5                          // x6 = x4 + x5 + carry

    // Store the result in oSum->aulDigits[lIndex]
    ldr     x7, [OSUM_REG, DIGITS_OFFSET]       // Pointer to oSum->aulDigits
    add     x7, x7, LINDEX_REG, lsl #3         // Address of aulDigits[lIndex]
    str     x6, [x7]                            // Store ulSum

    // Increment lIndex
    add     LINDEX_REG, LINDEX_REG, #1

    // Continue the loop
    b       Loop_Start

//--------------------------------------------------------------
// Handle_Carry:
//   After the main loop, if carry flag is set, handle carry out
//--------------------------------------------------------------
Handle_Carry:
    // Check if carry flag is set
    bcc     Set_Sum_Length                      // If carry flag not set, skip carry handling

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     LSUM_LENGTH_REG, #MAX_DIGITS_COUNT
    beq     Overflow_Detected                   // If lSumLength == MAX_DIGITS_COUNT, overflow occurred

    // Set oSum->aulDigits[lSumLength] = 1 (carry)
    ldr     x4, [OSUM_REG, DIGITS_OFFSET]       // Pointer to oSum->aulDigits
    add     x4, x4, LSUM_LENGTH_REG, lsl #3     // Address of aulDigits[lSumLength]
    mov     x5, #1                              // Value to set
    str     x5, [x4]                            // Set carry digit to 1

    // Increment lSumLength
    add     LSUM_LENGTH_REG, LSUM_LENGTH_REG, #1

Set_Sum_Length:
    // Set oSum->lLength = lSumLength
    str     LSUM_LENGTH_REG, [OSUM_REG, LENGTH_OFFSET]

    // Jump to Epilog and return TRUE_VAL
    mov     w0, TRUE_VAL
    b       Epilog_Return

//--------------------------------------------------------------
// Overflow_Detected:
//   If an overflow occurred, set oSum->lLength and return FALSE_VAL
//--------------------------------------------------------------
Overflow_Detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    b       Epilog_Return

//--------------------------------------------------------------
// Epilog_Return:
//   Restore callee-saved registers and return
//--------------------------------------------------------------
Epilog_Return:
    ldp     LSUM_LENGTH_REG, LINDEX_REG, [sp, #16]    // Restore lSumLength and lIndex
    ldp     OADDEND1_REG, OADDEND2_REG, [sp, #32]    // Restore oAddend1 and oAddend2
    ldp     OSUM_REG, x24, [sp, #48]                 // Restore oSum and unused register
    ldp     x29, x30, [sp, #0]                        // Restore frame pointer and link register
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add