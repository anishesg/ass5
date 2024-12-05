//-----------------------------------------------------------------------
// bigintaddopt.s
// Author: anish k
//-----------------------------------------------------------------------

// Defining constants
.equ    FALSE_VAL, 0
.equ    TRUE_VAL, 1
.equ    MAX_DIGITS_COUNT, 32768

// Structure field offsets for BigInt_T
.equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
.equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T

// Stack byte counts (should be multiples of 16 for alignment)
.equ    LARGER_STACK_SIZE, 32
.equ    ADDITION_STACK_SIZE, 64

// Local variable registers using .req directives
// For BigInt_add
.equ    LSUMLENGTH_OFFSET, 8
.equ    LINDEX_OFFSET, 16
.equ    ULSUM_OFFSET, 24
.equ    ULCARRY_OFFSET, 32

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

LLARGER         .req x19    // lLarger
LLENGTH1        .req x20    // lLength1
LLENGTH2        .req x21    // lLength2

.global BigInt_larger
.global BigInt_add
//-----------------------------------------------------------------------


.section .rodata
//-----------------------------------------------------------------------

.section .data

//-----------------------------------------------------------------------

.section .bss

//-----------------------------------------------------------------------

.section .text

//--------------------------------------------------------------

.section .text

//--------------------------------------------------------------
// Return the larger of lLength1 and lLength2.
// long BigInt_larger(long lLength1, long lLength2)
// Parameters:
//   x0: lLength1
//   x1: lLength2
// Returns:
//   x0: larger of lLength1 and lLength2
//--------------------------------------------------------------

BigInt_larger:

    // Prologue: set up the stack frame
    sub     sp, sp, LARGER_STACK_SIZE
    str     x30, [sp]                        // save link register
    str     x19, [sp, 8]                     // save LLARGER
    str     x20, [sp, 16]                    // save LLENGTH1
    str     x21, [sp, 24]                    // save LLENGTH2

    // Move parameters to callee-saved registers
    mov     LLENGTH1, x0                     // lLength1 = x0
    mov     LLENGTH2, x1                     // lLength2 = x1

    // Compare lLength1 and lLength2
    cmp     LLENGTH1, LLENGTH2
    ble     select_length_two                 // if lLength1 <= lLength2, select lLength2

    // Set lLarger to lLength1
    mov     LLARGER, LLENGTH1

    // Jump to conclude
    b       conclude_larger

select_length_two:
    // Set lLarger to lLength2
    mov     LLARGER, LLENGTH2

conclude_larger:
    // Move lLarger to return register
    mov     x0, LLARGER

    // Epilogue: restore stack frame and return
    ldr     x30, [sp]                        // restore link register
    ldr     x19, [sp, 8]                     // restore LLARGER
    ldr     x20, [sp, 16]                    // restore LLENGTH1
    ldr     x21, [sp, 24]                    // restore LLENGTH2
    add     sp, sp, LARGER_STACK_SIZE
    ret

.size   BigInt_larger, .-BigInt_larger

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
    str     x22, [sp, ULCARRY_OFFSET]         // save ulCarry
    str     x23, [sp, ULSUM_OFFSET]           // save ulSum
    str     x24, [sp, LINDEX_OFFSET]          // save lIndex
    str     x25, [sp, LSUMLENGTH_OFFSET]      // save lSumLength
    str     x26, [sp, OADDEND1_OFFSET]         // save oAddend1
    str     x27, [sp, OADDEND2_OFFSET]         // save oAddend2
    str     x28, [sp, OSUM_OFFSET]             // save oSum

    // Move parameters to callee-saved registers
    mov     OADDEND1, x0                       // oAddend1 = x0
    mov     OADDEND2, x1                       // oAddend2 = x1
    mov     OSUM, x2                           // oSum = x2

    // Determine the larger length: lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength)
    ldr     x0, [OADDEND1, LENGTH_OFFSET]       // load oAddend1->lLength
    ldr     x1, [OADDEND2, LENGTH_OFFSET]       // load oAddend2->lLength
    bl      BigInt_larger                       // call BigInt_larger
    mov     LSUMLENGTH, x0                       // lSumLength = result

    // Check if oSum->lLength <= lSumLength
    ldr     x0, [OSUM, LENGTH_OFFSET]           // load oSum->lLength
    cmp     x0, LSUMLENGTH
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
    cmp     LINDEX, LSUMLENGTH
    bge     handle_carry                        // if lIndex >= lSumLength, handle carry

    // ulSum = ulCarry
    mov     ULSUM, ULCARRY

    // ulCarry = 0
    mov     ULCARRY, 0

    // ulSum += oAddend1->aulDigits[lIndex]
    add     x1, OADDEND1, DIGITS_OFFSET         // pointer to oAddend1->aulDigits
    add     x1, x1, LINDEX, lsl #3              // address of aulDigits[lIndex]
    ldr     x2, [x1]                             // load digit from oAddend1
    add     ULSUM, ULSUM, x2                     // ulSum += digit

    // Check for overflow: if (ulSum < oAddend1->aulDigits[lIndex]) ulCarry = 1
    cmp     ULSUM, x2
    bhs     no_overflow_one                      // if ulSum >= digit, no overflow
    mov     ULCARRY, 1                            // set ulCarry = 1

no_overflow_one:
    // ulSum += oAddend2->aulDigits[lIndex]
    add     x1, OADDEND2, DIGITS_OFFSET         // pointer to oAddend2->aulDigits
    add     x1, x1, LINDEX, lsl #3              // address of aulDigits[lIndex]
    ldr     x2, [x1]                             // load digit from oAddend2
    add     ULSUM, ULSUM, x2                     // ulSum += digit

    // Check for overflow: if (ulSum < oAddend2->aulDigits[lIndex]) ulCarry = 1
    cmp     ULSUM, x2
    bhs     no_overflow_two                      // if ulSum >= digit, no overflow
    mov     ULCARRY, 1                            // set ulCarry = 1

no_overflow_two:
    // Store ulSum into oSum->aulDigits[lIndex]
    add     x1, OSUM, DIGITS_OFFSET             // pointer to oSum->aulDigits
    add     x1, x1, LINDEX, lsl #3              // address of aulDigits[lIndex]
    str     ULSUM, [x1]                           // store ulSum

    // Increment lIndex
    add     LINDEX, LINDEX, 1

    // Repeat the loop
    b       addition_loop

handle_carry:
    // Check if ulCarry == 1
    cmp     ULCARRY, 1
    bne     finalize_sum_length                   // if ulCarry != 1, skip handling

    // Check if lSumLength == MAX_DIGITS_COUNT
    cmp     LSUMLENGTH, MAX_DIGITS_COUNT
    beq     overflow_detected                      // if equal, overflow occurred

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
    ldr     x30, [sp]                             // restore link register
    ldr     x22, [sp, ULCARRY_OFFSET]             // restore ulCarry
    ldr     x23, [sp, ULSUM_OFFSET]               // restore ulSum
    ldr     x24, [sp, LINDEX_OFFSET]              // restore lIndex
    ldr     x25, [sp, LSUMLENGTH_OFFSET]          // restore lSumLength
    ldr     x26, [sp, OADDEND1_OFFSET]             // restore oAddend1
    ldr     x27, [sp, OADDEND2_OFFSET]             // restore oAddend2
    ldr     x28, [sp, OSUM_OFFSET]                 // restore oSum
    add     sp, sp, ADDITION_STACK_SIZE
    ret

overflow_detected:
    // Return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    ldr     x30, [sp]                             // restore link register
    ldr     x22, [sp, ULCARRY_OFFSET]             // restore ulCarry
    ldr     x23, [sp, ULSUM_OFFSET]               // restore ulSum
    ldr     x24, [sp, LINDEX_OFFSET]              // restore lIndex
    ldr     x25, [sp, LSUMLENGTH_OFFSET]          // restore lSumLength
    ldr     x26, [sp, OADDEND1_OFFSET]             // restore oAddend1
    ldr     x27, [sp, OADDEND2_OFFSET]             // restore oAddend2
    ldr     x28, [sp, OSUM_OFFSET]                 // restore oSum
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add
