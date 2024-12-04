//-----------------------------------------------------------------------
// bigintaddoptopt.s
// Author: anish k
// Description: Further optimized ARMv8 assembly implementation of BigInt_add
//              with inlined BigInt_larger function and guarded loop pattern.
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

// Parameter stack offsets for BigInt_add
.equ    PARAM_SUM, 40
.equ    PARAM_ADDEND2, 48
.equ    PARAM_ADDEND1, 56

// Assign meaningful register names to variables
ULCARRY         .req x22    // ulCarry
ULSUM           .req x23    // ulSum
LINDEX          .req x24    // lIndex
LSUMLENGTH      .req x25    // lSumLength

OADDEND1        .req x26    // oAddend1
OADDEND2        .req x27    // oAddend2
OSUM            .req x28    // oSum

LLARGER         .req x19    // lLarger (inlined)
LLENGTH1        .req x20    // lLength1 (inlined)
LLENGTH2        .req x21    // lLength2 (inlined)

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
    str     x30, [sp]                         // save link register
    str     x22, [sp, VAR_CARRY]             // save ulCarry
    str     x23, [sp, VAR_SUM]                // save ulSum
    str     x24, [sp, VAR_INDEX]               // save lIndex
    str     x25, [sp, VAR_SUM_LENGTH]         // save lSumLength
    str     x26, [sp, PARAM_ADDEND1]          // save oAddend1
    str     x27, [sp, PARAM_ADDEND2]          // save oAddend2
    str     x28, [sp, PARAM_SUM]              // save oSum

    // Move parameters to callee-saved registers
    mov     OADDEND1, x0                       // oAddend1 = x0
    mov     OADDEND2, x1                       // oAddend2 = x1
    mov     OSUM, x2                           // oSum = x2

    // *** Inlined BigInt_larger Function ***
    // Load lLength1 and lLength2
    ldr     LLENGTH1, [OADDEND1, LENGTH_OFFSET] // load oAddend1->lLength into LLENGTH1
    ldr     LLENGTH2, [OADDEND2, LENGTH_OFFSET] // load oAddend2->lLength into LLENGTH2

    // Compare lLength1 and lLength2
    cmp     LLENGTH1, LLENGTH2
    ble     select_length_two                  // if lLength1 <= lLength2, select lLength2

    // Set lLarger to lLength1
    mov     LLARGER, LLENGTH1

    // Jump to conclude
    b       conclude_larger

select_length_two:
    // Set lLarger to lLength2
    mov     LLARGER, LLENGTH2

conclude_larger:
    // Set lSumLength to lLarger
    mov     LSUMLENGTH, LLARGER

    // *** End of Inlined BigInt_larger ***

    // Check if oSum->lLength <= lSumLength
    ldr     x0, [OSUM, LENGTH_OFFSET]          // load oSum->lLength
    cmp     x0, LSUMLENGTH
    ble     skip_clear_digits                  // if oSum->lLength <= lSumLength, skip memset

    // Perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    add     x0, OSUM, DIGITS_OFFSET            // pointer to oSum->aulDigits
    mov     w1, 0                              // value to set
    mov     x2, MAX_DIGITS_COUNT              // size
    lsl     x2, x2, #3                         // multiply by 8 (sizeof(unsigned long))
    bl      memset                              // call memset

skip_clear_digits:
    // Initialize ulCarry to 0
    mov     ULCARRY, 0

    // Initialize lIndex to 0
    mov     LINDEX, 0

// *** Implementing Guarded Loop Pattern ***
addition_loop_guarded:
    // Guarded Loop: Check if lIndex < lSumLength
    cmp     LINDEX, LSUMLENGTH
    bge     handle_carry                        // if lIndex >= lSumLength, handle carry

sumLoop_guarded:
    // ulSum = ulCarry
    mov     ULSUM, ULCARRY

    // ulCarry = 0 (reset carry)
    mov     ULCARRY, 0

    // Load oAddend1->aulDigits[lIndex]
    ldr     x1, [OADDEND1, DIGITS_OFFSET]       // pointer to oAddend1->aulDigits
    add     x1, x1, LINDEX, lsl #3              // address of aulDigits[lIndex]
    ldr     x2, [x1]                             // load digit from oAddend1
    adds    ULSUM, ULSUM, x2                     // ulSum += digit and set flags

    // Use adcs to add oAddend2->aulDigits[lIndex] with carry
    ldr     x1, [OADDEND2, DIGITS_OFFSET]       // pointer to oAddend2->aulDigits
    add     x1, x1, LINDEX, lsl #3              // address of aulDigits[lIndex]
    ldr     x3, [x1]                             // load digit from oAddend2
    adcs    ULSUM, ULSUM, x3                     // ulSum += digit + carry, update flags

    // Store ulSum into oSum->aulDigits[lIndex]
    add     x1, OSUM, DIGITS_OFFSET             // pointer to oSum->aulDigits
    add     x1, x1, LINDEX, lsl #3              // address of aulDigits[lIndex]
    str     ULSUM, [x1]                           // store ulSum

    // Increment lIndex
    add     LINDEX, LINDEX, 1

    // Branch back to guarded loop
    b       addition_loop_guarded

// *** End of Guarded Loop Pattern ***

handle_carry:
    // Check if carry flag is set
    bcc     finalize_sum_length                  // if carry not set, skip handling

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     LSUMLENGTH, MAX_DIGITS_COUNT
    beq     overflow_detected                    // if equal, overflow occurred

    // Set oSum->aulDigits[lSumLength] = 1
    add     x0, OSUM, DIGITS_OFFSET             // pointer to oSum->aulDigits
    add     x0, x0, LSUMLENGTH, lsl #3          // address of aulDigits[lSumLength]
    mov     x1, 1
    str     x1, [x0]                             // set the carry digit

    // Increment lSumLength
    add     LSUMLENGTH, LSUMLENGTH, 1

finalize_sum_length:
    // Set oSum->lLength = lSumLength
    str     LSUMLENGTH, [OSUM, LENGTH_OFFSET]    // store lSumLength into oSum->lLength

    // Return TRUE_VAL
    mov     w0, TRUE_VAL
    ldr     x30, [sp]                            // restore link register
    ldr     x22, [sp, VAR_CARRY]                // restore ulCarry
    ldr     x23, [sp, VAR_SUM]                   // restore ulSum
    ldr     x24, [sp, VAR_INDEX]                 // restore lIndex
    ldr     x25, [sp, VAR_SUM_LENGTH]           // restore lSumLength
    ldr     x26, [sp, PARAM_ADDEND1]             // restore oAddend1
    ldr     x27, [sp, PARAM_ADDEND2]             // restore oAddend2
    ldr     x28, [sp, PARAM_SUM]                 // restore oSum
    add     sp, sp, ADDITION_STACK_SIZE
    ret

overflow_detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    ldr     x30, [sp]                            // restore link register
    ldr     x22, [sp, VAR_CARRY]                // restore ulCarry
    ldr     x23, [sp, VAR_SUM]                   // restore ulSum
    ldr     x24, [sp, VAR_INDEX]                 // restore lIndex
    ldr     x25, [sp, VAR_SUM_LENGTH]           // restore lSumLength
    ldr     x26, [sp, PARAM_ADDEND1]             // restore oAddend1
    ldr     x27, [sp, PARAM_ADDEND2]             // restore oAddend2
    ldr     x28, [sp, PARAM_SUM]                 // restore oSum
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add