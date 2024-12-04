
// defining constants
.equ    FALSE_VAL, 0
.equ    TRUE_VAL, 1
.equ    EOF_VAL, -1
.equ    MAX_DIGITS_COUNT, 32768
//-----------------------------------------------------------------------

.section .rodata

//-----------------------------------------------------------------------

.section .data

//-----------------------------------------------------------------------

.section .bss

//-----------------------------------------------------------------------

.section .text

//--------------------------------------------------------------
// return the larger of lLength1 and lLength2
// long BigInt_larger(long lLength1, long lLength2)
//--------------------------------------------------------------

// must be a multiple of 16
.equ    LARGER_STACK_SIZE, 32

// local variable stack offsets
.equ    VAR_LARGER, 8

// parameter stack offsets
.equ    PARAM_LENGTH2, 16
.equ    PARAM_LENGTH1, 24

BigInt_larger:

    // prologue: set up stack frame
    sub     sp, sp, LARGER_STACK_SIZE
    str     x30, [sp]                        // save link register
    str     x0, [sp, PARAM_LENGTH1]          // store lLength1
    str     x1, [sp, PARAM_LENGTH2]          // store lLength2

    // load lLength1 and lLength2 from stack
    ldr     x2, [sp, PARAM_LENGTH1]          // load lLength1 into x2
    ldr     x3, [sp, PARAM_LENGTH2]          // load lLength2 into x3

    // compare lLength1 and lLength2
    cmp     x2, x3
    ble     choose_length2                    // if lLength1 <= lLength2, choose lLength2

    // lLarger = lLength1
    str     x2, [sp, VAR_LARGER]
    b       finish_larger                     // jump to end

choose_length2:
    // lLarger = lLength2
    str     x3, [sp, VAR_LARGER]

finish_larger:
    // load lLarger into return register
    ldr     x0, [sp, VAR_LARGER]

    // epilogue: restore stack frame and return
    ldr     x30, [sp]
    add     sp, sp, LARGER_STACK_SIZE
    ret

.size   BigInt_larger, .-BigInt_larger

//--------------------------------------------------------------
// assign the sum of oAddend1 and oAddend2 to oSum
// oSum should be distinct from oAddend1 and oAddend2
// return 0 (FALSE_VAL) if an overflow occurred, and 1 (TRUE_VAL) otherwise
// int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
//--------------------------------------------------------------

// must be a multiple of 16
.equ    ADDITION_STACK_SIZE, 64

// local variables stack offsets
.equ    VAR_SUM_LENGTH, 8
.equ    VAR_INDEX, 16
.equ    VAR_SUM, 24
.equ    VAR_CARRY, 32

// parameter stack offsets
.equ    PARAM_SUM, 40
.equ    PARAM_ADDEND2, 48
.equ    PARAM_ADDEND1, 56

// structure field offsets
.equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
.equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T

.global BigInt_add

BigInt_add:

    // prologue: set up stack frame
    sub     sp, sp, ADDITION_STACK_SIZE
    str     x30, [sp]                         // save link register
    str     x0, [sp, PARAM_ADDEND1]           // store oAddend1
    str     x1, [sp, PARAM_ADDEND2]           // store oAddend2
    str     x2, [sp, PARAM_SUM]               // store oSum

    // load lLength1 from oAddend1->lLength
    ldr     x2, [sp, PARAM_ADDEND1]           // load oAddend1
    ldr     x2, [x2, LENGTH_OFFSET]           // load oAddend1->lLength

    // load lLength2 from oAddend2->lLength
    ldr     x3, [sp, PARAM_ADDEND2]           // load oAddend2
    ldr     x3, [x3, LENGTH_OFFSET]           // load oAddend2->lLength

    // call BigInt_larger to get lSumLength
    bl      BigInt_larger
    str     x0, [sp, VAR_SUM_LENGTH]          // store lSumLength

    // check if oSum->lLength <= lSumLength
    ldr     x4, [sp, PARAM_SUM]               // load oSum
    ldr     x4, [x4, LENGTH_OFFSET]           // load oSum->lLength
    ldr     x5, [sp, VAR_SUM_LENGTH]          // load lSumLength
    cmp     x4, x5
    ble     skip_clear_digits                  // if true, skip memset

    // perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
    ldr     x0, [sp, PARAM_SUM]               // load oSum
    add     x0, x0, DIGITS_OFFSET              // point to aulDigits
    mov     w1, 0                              // value to set
    mov     x2, MAX_DIGITS_COUNT
    lsl     x2, x2, #3                         // MAX_DIGITS_COUNT * 8
    bl      memset                             // call memset

skip_clear_digits:
    // initialize ulCarry to 0
    mov     x6, 0
    str     x6, [sp, VAR_CARRY]

    // initialize lIndex to 0
    mov     x6, 0
    str     x6, [sp, VAR_INDEX]

addition_loop_start:
    // check if lIndex >= lSumLength
    ldr     x6, [sp, VAR_INDEX]
    ldr     x7, [sp, VAR_SUM_LENGTH]
    cmp     x6, x7
    bge     end_addition_loop                  // if true, exit loop

    // ulSum = ulCarry
    ldr     x8, [sp, VAR_CARRY]
    str     x8, [sp, VAR_SUM]

    // ulCarry = 0
    mov     x8, 0
    str     x8, [sp, VAR_CARRY]

    // ulSum += oAddend1->aulDigits[lIndex]
    ldr     x9, [sp, PARAM_ADDEND1]
    add     x9, x9, DIGITS_OFFSET              // point to aulDigits
    ldr     x10, [sp, VAR_INDEX]
    lsl     x10, x10, #3                        // lIndex * 8
    add     x9, x9, x10
    ldr     x11, [x9]                            // load oAddend1->aulDigits[lIndex]
    ldr     x12, [sp, VAR_SUM]
    add     x12, x12, x11
    str     x12, [sp, VAR_SUM]

    // check for overflow: if (ulSum >= oAddend1->aulDigits[lIndex])
    cmp     x12, x11
    bhi     no_overflow_first_check             // if ulSum >= digit, no overflow
    mov     x13, 1
    str     x13, [sp, VAR_CARRY]               // set ulCarry = 1

no_overflow_first_check:
    // ulSum += oAddend2->aulDigits[lIndex]
    ldr     x14, [sp, PARAM_ADDEND2]
    add     x14, x14, DIGITS_OFFSET             // point to aulDigits
    ldr     x15, [sp, VAR_INDEX]
    lsl     x15, x15, #3                        // lIndex * 8
    add     x14, x14, x15
    ldr     x16, [x14]                           // load oAddend2->aulDigits[lIndex]
    ldr     x17, [sp, VAR_SUM]
    add     x17, x17, x16
    str     x17, [sp, VAR_SUM]

    // check for overflow: if (ulSum >= oAddend2->aulDigits[lIndex])
    cmp     x17, x16
    bhi     no_overflow_second_check            // if ulSum >= digit, no overflow
    mov     x13, 1
    str     x13, [sp, VAR_CARRY]               // set ulCarry = 1

no_overflow_second_check:
    // oSum->aulDigits[lIndex] = ulSum
    ldr     x18, [sp, PARAM_SUM]
    add     x18, x18, DIGITS_OFFSET              // point to aulDigits
    ldr     x19, [sp, VAR_INDEX]
    lsl     x19, x19, #3                        // lIndex * 8
    add     x18, x18, x19
    ldr     x20, [sp, VAR_SUM]
    str     x20, [x18]                            // store ulSum

    // increment lIndex using add immediate
    add     x6, x6, #1
    str     x6, [sp, VAR_INDEX]

    // repeat the loop
    b       addition_loop_start

end_addition_loop:
    // check if there was a carry out
    ldr     x13, [sp, VAR_CARRY]
    cmp     x13, 1
    bne     skip_carry_handling                  // if no carry, skip handling

    // check if lSumLength == MAX_DIGITS_COUNT
    ldr     x7, [sp, VAR_SUM_LENGTH]
    cmp     x7, MAX_DIGITS_COUNT
    beq     overflow_occurred                    // if equal, overflow occurred

    // set oSum->aulDigits[lSumLength] = 1
    ldr     x21, [sp, PARAM_SUM]
    add     x21, x21, DIGITS_OFFSET              // point to aulDigits
    ldr     x22, [sp, VAR_SUM_LENGTH]
    lsl     x22, x22, #3                        // lSumLength * 8
    add     x21, x21, x22
    mov     x23, 1
    str     x23, [x21]                            // set the carry digit

    // increment lSumLength
    ldr     x24, [sp, VAR_SUM_LENGTH]
    add     x24, x24, 1
    str     x24, [sp, VAR_SUM_LENGTH]

    // set oSum->lLength = lSumLength
    ldr     x25, [sp, VAR_SUM_LENGTH]
    ldr     x26, [sp, PARAM_SUM]
    str     x25, [x26, LENGTH_OFFSET]

    // return TRUE_VAL
    mov     w0, TRUE_VAL
    ldr     x30, [sp]
    add     sp, sp, ADDITION_STACK_SIZE
    ret

overflow_occurred:
    // return FALSE_VAL due to overflow
    mov     w0, FALSE_VAL
    ldr     x30, [sp]
    add     sp, sp, ADDITION_STACK_SIZE
    ret

skip_carry_handling:
    // set oSum->lLength = lSumLength
    ldr     x0, [sp, VAR_SUM_LENGTH]
    ldr     x1, [sp, PARAM_SUM]
    str     x0, [x1, LENGTH_OFFSET]

    // epilogue: return TRUE_VAL
    mov     w0, TRUE_VAL
    ldr     x30, [sp]
    add     sp, sp, ADDITION_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add