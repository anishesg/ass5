//-----------------------------------------------------------------------
// bigintadd.s
// Author: anish k
// 
//-----------------------------------------------------------------------

// defining constants
.equ    FALSE_VAL, 0
.equ    TRUE_VAL, 1
.equ    MAX_DIGITS_COUNT, 32768

// structure field offsets for BigInt_T
.equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
.equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T

// stack byte counts (should be multiples of 16 for alignment)
.equ    LARGER_STACK_SIZE, 32
.equ    ADDITION_STACK_SIZE, 64

// local variable stack offsets for BigInt_larger
.equ    VAR_LARGER, 8
.equ    VAR_LENGTH1, 16
.equ    VAR_LENGTH2, 24

// local variable stack offsets for BigInt_add
.equ    VAR_SUM_LENGTH, 8
.equ    VAR_INDEX, 16
.equ    VAR_SUM, 24
.equ    VAR_CARRY, 32

// parameter stack offsets for BigInt_add
.equ    PARAM_SUM, 40
.equ    PARAM_ADDEND2, 48
.equ    PARAM_ADDEND1, 56

.global BigInt_larger
.global BigInt_add

.section .text

//--------------------------------------------------------------
// return the larger of lLength1 and lLength2
// long BigInt_larger(long lLength1, long lLength2)
// parameters:
//   x0: lLength1
//   x1: lLength2
// returns:
//   x0: larger of lLength1 and lLength2
//--------------------------------------------------------------

BigInt_larger:

    // set up the stack frame
    sub     sp, sp, LARGER_STACK_SIZE
    str     x30, [sp]                        // save link register
    str     x0, [sp, VAR_LENGTH1]            // store first parameter
    str     x1, [sp, VAR_LENGTH2]            // store second parameter

    // load lLength1 from stack
    ldr     x0, [sp, VAR_LENGTH1]

    // load lLength2 from stack
    ldr     x1, [sp, VAR_LENGTH2]

    // compare lLength1 and lLength2
    cmp     x0, x1
    ble     select_length_two                 // if lLength1 <= lLength2, select lLength2

    // set lLarger to lLength1
    str     x0, [sp, VAR_LARGER]

    // jump to finish
    b       conclude_larger

select_length_two:
    // set lLarger to lLength2
    str     x1, [sp, VAR_LARGER]

conclude_larger:
    // load lLarger into return register
    ldr     x0, [sp, VAR_LARGER]

    // restore stack frame and return
    ldr     x30, [sp]
    add     sp, sp, LARGER_STACK_SIZE
    ret

.size   BigInt_larger, .-BigInt_larger

//--------------------------------------------------------------
// assign the sum of oAddend1 and oAddend2 to oSum
// oSum should be distinct from oAddend1 and oAddend2
// int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
// parameters:
//   x0: oAddend1
//   x1: oAddend2
//   x2: oSum
// returns:
//   w0: 1 (TRUE_VAL) if successful, 0 (FALSE_VAL) if overflow occurred
//--------------------------------------------------------------

BigInt_add:

    // set up the stack frame
    sub     sp, sp, ADDITION_STACK_SIZE
    str     x30, [sp]                         // save link register
    str     x0, [sp, PARAM_ADDEND1]           // store oAddend1
    str     x1, [sp, PARAM_ADDEND2]           // store oAddend2
    str     x2, [sp, PARAM_SUM]               // store oSum

    // load lLength1 from oAddend1->lLength
    ldr     x0, [sp, PARAM_ADDEND1]           // load oAddend1
    ldr     x0, [x0, LENGTH_OFFSET]           // load lLength1

    // load lLength2 from oAddend2->lLength
    ldr     x1, [sp, PARAM_ADDEND2]           // load oAddend2
    ldr     x1, [x1, LENGTH_OFFSET]           // load lLength2

    // call BigInt_larger to get lSumLength
    bl      BigInt_larger
    str     x0, [sp, VAR_SUM_LENGTH]          // store lSumLength

    // check if oSum->lLength <= lSumLength
    ldr     x0, [sp, PARAM_SUM]               // load oSum
    ldr     x0, [x0, LENGTH_OFFSET]           // load oSum->lLength
    ldr     x1, [sp, VAR_SUM_LENGTH]          // load lSumLength
    cmp     x0, x1
    ble     skip_clear_digits                  // if oSum->lLength <= lSumLength, skip memset

    // perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    ldr     x0, [sp, PARAM_SUM]               // load oSum
    add     x0, x0, DIGITS_OFFSET              // point to aulDigits
    mov     w1, 0                              // set value to 0
    mov     x2, MAX_DIGITS_COUNT              // set size
    lsl     x2, x2, #3                         // multiply by 8 (sizeof(unsigned long))
    bl      memset                             // call memset

skip_clear_digits:
    // initialize ulCarry to 0
    mov     x0, 0
    str     x0, [sp, VAR_CARRY]

    // initialize lIndex to 0
    mov     x0, 0
    str     x0, [sp, VAR_INDEX]

addition_loop:
    // check if lIndex >= lSumLength
    ldr     x0, [sp, VAR_INDEX]               // load lIndex
    ldr     x1, [sp, VAR_SUM_LENGTH]          // load lSumLength
    cmp     x0, x1
    bge     handle_carry                       // if lIndex >= lSumLength, handle carry

    // ulSum = ulCarry
    ldr     x0, [sp, VAR_CARRY]               // load ulCarry
    str     x0, [sp, VAR_SUM]                  // store ulSum

    // ulCarry = 0
    mov     x0, 0
    str     x0, [sp, VAR_CARRY]

    // load oAddend1->aulDigits[lIndex]
    ldr     x1, [sp, PARAM_ADDEND1]           // load oAddend1
    add     x1, x1, DIGITS_OFFSET              // point to aulDigits
    ldr     x2, [sp, VAR_INDEX]               // load lIndex
    lsl     x2, x2, #3                         // lIndex * 8
    add     x1, x1, x2                          // address of aulDigits[lIndex]
    ldr     x3, [x1]                            // load digit from oAddend1

    // load ulSum, add digit, store ulSum
    ldr     x0, [sp, VAR_SUM]                  // load ulSum
    add     x0, x0, x3                          // ulSum += digit
    str     x0, [sp, VAR_SUM]                  // store ulSum

    // check for overflow: if (ulSum < oAddend1->aulDigits[lIndex])
    cmp     x0, x3
    bhs     no_overflow_one                     // if ulSum >= digit, no overflow
    mov     x4, 1
    str     x4, [sp, VAR_CARRY]                // set ulCarry = 1

no_overflow_one:
    // load oAddend2->aulDigits[lIndex]
    ldr     x1, [sp, PARAM_ADDEND2]           // load oAddend2
    add     x1, x1, DIGITS_OFFSET              // point to aulDigits
    ldr     x2, [sp, VAR_INDEX]               // load lIndex
    lsl     x2, x2, #3                         // lIndex * 8
    add     x1, x1, x2                          // address of aulDigits[lIndex]
    ldr     x3, [x1]                            // load digit from oAddend2

    // load ulSum, add digit, store ulSum
    ldr     x0, [sp, VAR_SUM]                  // load ulSum
    add     x0, x0, x3                          // ulSum += digit
    str     x0, [sp, VAR_SUM]                  // store ulSum

    // check for overflow: if (ulSum < oAddend2->aulDigits[lIndex])
    cmp     x0, x3
    bhs     no_overflow_two                     // if ulSum >= digit, no overflow
    mov     x4, 1
    str     x4, [sp, VAR_CARRY]                // set ulCarry = 1

no_overflow_two:
    // store ulSum into oSum->aulDigits[lIndex]
    ldr     x1, [sp, PARAM_SUM]               // load oSum
    add     x1, x1, DIGITS_OFFSET              // point to aulDigits
    ldr     x2, [sp, VAR_INDEX]               // load lIndex
    lsl     x2, x2, #3                         // lIndex * 8
    add     x1, x1, x2                          // address of aulDigits[lIndex]
    ldr     x0, [sp, VAR_SUM]                  // load ulSum
    str     x0, [x1]                            // store ulSum

    // increment lIndex
    ldr     x0, [sp, VAR_INDEX]               // load lIndex
    add     x0, x0, 1                          // lIndex += 1
    str     x0, [sp, VAR_INDEX]                // store lIndex

    // repeat the loop
    b       addition_loop

handle_carry:
    // check if there was a carry out
    ldr     x0, [sp, VAR_CARRY]               // load ulCarry
    cmp     x0, 1
    bne     finalize_sum_length                 // if ulCarry != 1, skip handling

    // check if lSumLength == MAX_DIGITS_COUNT
    ldr     x1, [sp, VAR_SUM_LENGTH]          // load lSumLength
    cmp     x1, MAX_DIGITS_COUNT
    beq     overflow_detected                    // if equal, overflow occurred

    // set oSum->aulDigits[lSumLength] = 1
    ldr     x0, [sp, PARAM_SUM]               // load oSum
    add     x0, x0, DIGITS_OFFSET              // point to aulDigits
    ldr     x2, [sp, VAR_SUM_LENGTH]          // load lSumLength
    lsl     x2, x2, #3                         // lSumLength * 8
    add     x0, x0, x2                          // address of aulDigits[lSumLength]
    mov     x1, 1
    str     x1, [x0]                            // set the carry digit

    // increment lSumLength
    ldr     x0, [sp, VAR_SUM_LENGTH]          // load lSumLength
    add     x0, x0, 1                          // lSumLength += 1
    str     x0, [sp, VAR_SUM_LENGTH]            // store lSumLength

finalize_sum_length:
    // set oSum->lLength = lSumLength
    ldr     x0, [sp, VAR_SUM_LENGTH]          // load lSumLength
    ldr     x1, [sp, PARAM_SUM]               // load oSum
    str     x0, [x1, LENGTH_OFFSET]           // store lSumLength into oSum->lLength

    // return TRUE_VAL
    mov     w0, TRUE_VAL
    ldr     x30, [sp]                          // restore link register
    add     sp, sp, ADDITION_STACK_SIZE
    ret

overflow_detected:
    // return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    ldr     x30, [sp]                          // restore link register
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add