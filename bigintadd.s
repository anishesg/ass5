//---------------------------------------------------------------------
// bigintadd.s
// Author: anish k
//---------------------------------------------------------------------

    .section .text

    // enumerated constants
    .equ    FALSE, 0
    .equ    TRUE, 1
    .equ    MAX_DIGITS, 32768        // as defined in bigintprivate.h

    // structure field offsets
    .equ    OFFSET_L_LENGTH, 0       // offset of lLength in BigInt_T
    .equ    OFFSET_AUL_DIGITS, 8     // offset of aulDigits in BigInt_T

    // stack frame sizes (must be multiples of 16 for alignment)
    .equ    BIGINT_LARGER_FRAME_SIZE, 32
    .equ    BIGINT_ADD_FRAME_SIZE, 64

    // BigInt_larger stack offsets
    .equ    OFFSET_LARGER_RESULT, 8      // local variable lResult
    // parameters will be stored starting at offset 16
    .equ    OFFSET_LARGER_L1, 16         // parameter lLength1
    .equ    OFFSET_LARGER_L2, 24         // parameter lLength2

    // BigInt_add stack offsets
    .equ    OFFSET_UL_CARRY, 8           // unsigned long ulCarry
    .equ    OFFSET_UL_SUM, 16            // unsigned long ulSum
    .equ    OFFSET_L_INDEX, 24           // long lIndex
    .equ    OFFSET_L_SUM_LENGTH, 32      // long lSumLength
    // parameters will be stored starting at offset 40
    .equ    OFFSET_O_SUM, 40             // BigInt_T oSum
    .equ    OFFSET_O_ADDEND2, 48         // BigInt_T oAddend2
    .equ    OFFSET_O_ADDEND1, 56         // BigInt_T oAddend1

//---------------------------------------------------------------------
// long BigInt_larger(long lLength1, long lLength2)
// parameters:
//   lLength1 - first length
//   lLength2 - second length
// returns:
//   the larger of lLength1 and lLength2
//---------------------------------------------------------------------

    .global BigInt_larger

BigInt_larger:
    // function prologue
    sub     sp, sp, BIGINT_LARGER_FRAME_SIZE    // allocate stack frame
    str     x30, [sp, 24]                       // save return address
    str     x0, [sp, OFFSET_LARGER_L1]          // store lLength1
    str     x1, [sp, OFFSET_LARGER_L2]          // store lLength2

    // load parameters into registers for ease of use
    ldr     x2, [sp, OFFSET_LARGER_L1]          // x2 = lLength1
    ldr     x3, [sp, OFFSET_LARGER_L2]          // x3 = lLength2

    // compare lLength1 and lLength2
    cmp     x2, x3
    ble     larger_use_second                   // if lLength1 <= lLength2, use second

    // lResult = lLength1
    str     x2, [sp, OFFSET_LARGER_RESULT]
    b       larger_done                         // skip to the end

larger_use_second:
    // lResult = lLength2
    str     x3, [sp, OFFSET_LARGER_RESULT]

larger_done:
    // prepare return value
    ldr     x0, [sp, OFFSET_LARGER_RESULT]

    // function epilogue
    ldr     x30, [sp, 24]                       // restore return address
    add     sp, sp, BIGINT_LARGER_FRAME_SIZE    // deallocate stack frame
    ret

    .size   BigInt_larger, . - BigInt_larger

//---------------------------------------------------------------------
// int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
// parameters:
//   oAddend1 - first BigInt operand
//   oAddend2 - second BigInt operand
//   oSum     - BigInt to store the result
// returns:
//   TRUE if addition succeeds, FALSE if overflow occurs
//---------------------------------------------------------------------

    .global BigInt_add

BigInt_add:
    // function prologue
    sub     sp, sp, BIGINT_ADD_FRAME_SIZE       // allocate stack frame
    str     x30, [sp, 56]                       // save return address
    // store parameters on the stack
    str     x0, [sp, OFFSET_O_ADDEND1]          // oAddend1
    str     x1, [sp, OFFSET_O_ADDEND2]          // oAddend2
    str     x2, [sp, OFFSET_O_SUM]              // oSum

    // load parameters into registers for easier access
    ldr     x9, [sp, OFFSET_O_ADDEND1]          // x9 = oAddend1
    ldr     x10, [sp, OFFSET_O_ADDEND2]         // x10 = oAddend2
    ldr     x11, [sp, OFFSET_O_SUM]             // x11 = oSum

    // get lengths of oAddend1 and oAddend2
    ldr     x0, [x9, OFFSET_L_LENGTH]           // x0 = oAddend1->lLength
    ldr     x1, [x10, OFFSET_L_LENGTH]          // x1 = oAddend2->lLength

    // call BigInt_larger to find lSumLength
    bl      BigInt_larger
    str     x0, [sp, OFFSET_L_SUM_LENGTH]       // store lSumLength

    // check if oSum's array needs clearing
    ldr     x1, [x11, OFFSET_L_LENGTH]          // x1 = oSum->lLength
    ldr     x2, [sp, OFFSET_L_SUM_LENGTH]       // x2 = lSumLength
    cmp     x1, x2
    ble     add_memset_skip                     // skip memset if oSum->lLength <= lSumLength

    // clear oSum's aulDigits array using memset
    add     x0, x11, OFFSET_AUL_DIGITS          // x0 = oSum->aulDigits
    mov     w1, #0                              // w1 = 0 (value to set)
    mov     x2, #MAX_DIGITS
    lsl     x2, x2, #3                          // x2 = MAX_DIGITS * sizeof(unsigned long)
    bl      memset

add_memset_skip:
    // initialize ulCarry to zero
    mov     x3, #0
    str     x3, [sp, OFFSET_UL_CARRY]

    // initialize lIndex to zero
    str     x3, [sp, OFFSET_L_INDEX]

add_loop_start:
    // check if lIndex >= lSumLength
    ldr     x4, [sp, OFFSET_L_INDEX]            // x4 = lIndex
    ldr     x5, [sp, OFFSET_L_SUM_LENGTH]       // x5 = lSumLength
    cmp     x4, x5
    bge     add_loop_end                        // exit loop if lIndex >= lSumLength

    // ulSum = ulCarry
    ldr     x6, [sp, OFFSET_UL_CARRY]
    str     x6, [sp, OFFSET_UL_SUM]

    // reset ulCarry to zero
    mov     x6, #0
    str     x6, [sp, OFFSET_UL_CARRY]

    // ulSum += oAddend1->aulDigits[lIndex]
    add     x7, x9, OFFSET_AUL_DIGITS           // x7 = oAddend1->aulDigits
    ldr     x8, [sp, OFFSET_L_INDEX]            // x8 = lIndex
    lsl     x8, x8, #3                          // x8 *= sizeof(unsigned long)
    add     x7, x7, x8                          // x7 = &oAddend1->aulDigits[lIndex]
    ldr     x12, [x7]                           // x12 = oAddend1->aulDigits[lIndex]

    ldr     x6, [sp, OFFSET_UL_SUM]             // x6 = ulSum
    adds    x6, x6, x12                         // perform addition, set flags
    str     x6, [sp, OFFSET_UL_SUM]

    // check for carry after first addition
    bcc     add_no_carry_first
    // ulCarry = 1
    mov     x13, #1
    str     x13, [sp, OFFSET_UL_CARRY]
add_no_carry_first:

    // ulSum += oAddend2->aulDigits[lIndex]
    add     x7, x10, OFFSET_AUL_DIGITS          // x7 = oAddend2->aulDigits
    ldr     x8, [sp, OFFSET_L_INDEX]            // x8 = lIndex
    lsl     x8, x8, #3                          // x8 *= sizeof(unsigned long)
    add     x7, x7, x8                          // x7 = &oAddend2->aulDigits[lIndex]
    ldr     x12, [x7]                           // x12 = oAddend2->aulDigits[lIndex]

    ldr     x6, [sp, OFFSET_UL_SUM]             // x6 = ulSum
    adds    x6, x6, x12                         // perform addition, set flags
    str     x6, [sp, OFFSET_UL_SUM]

    // check for carry after second addition
    bcc     add_no_carry_second
    // ulCarry = 1
    mov     x13, #1
    str     x13, [sp, OFFSET_UL_CARRY]
add_no_carry_second:

    // store ulSum into oSum->aulDigits[lIndex]
    add     x7, x11, OFFSET_AUL_DIGITS          // x7 = oSum->aulDigits
    ldr     x8, [sp, OFFSET_L_INDEX]            // x8 = lIndex
    lsl     x8, x8, #3                          // x8 *= sizeof(unsigned long)
    add     x7, x7, x8                          // x7 = &oSum->aulDigits[lIndex]
    ldr     x6, [sp, OFFSET_UL_SUM]             // x6 = ulSum
    str     x6, [x7]

    // increment lIndex
    ldr     x4, [sp, OFFSET_L_INDEX]
    add     x4, x4, #1
    str     x4, [sp, OFFSET_L_INDEX]

    // repeat the loop
    b       add_loop_start

add_loop_end:
    // check if there is a remaining carry
    ldr     x6, [sp, OFFSET_UL_CARRY]
    cbz     x6, add_set_length                  // if ulCarry == 0, skip carry handling

    // check for overflow: if lSumLength == MAX_DIGITS
    ldr     x5, [sp, OFFSET_L_SUM_LENGTH]       // x5 = lSumLength
    mov     x14, #MAX_DIGITS
    cmp     x5, x14
    beq     add_return_false                    // if equal, return FALSE due to overflow

    // handle carry out
    // oSum->aulDigits[lSumLength] = 1
    add     x7, x11, OFFSET_AUL_DIGITS          // x7 = oSum->aulDigits
    lsl     x8, x5, #3                          // x8 = lSumLength * sizeof(unsigned long)
    add     x7, x7, x8                          // x7 = &oSum->aulDigits[lSumLength]
    mov     x6, #1
    str     x6, [x7]

    // increment lSumLength
    add     x5, x5, #1
    str     x5, [sp, OFFSET_L_SUM_LENGTH]

add_set_length:
    // set oSum->lLength to lSumLength
    ldr     x5, [sp, OFFSET_L_SUM_LENGTH]       // x5 = lSumLength
    str     x5, [x11, OFFSET_L_LENGTH]          // oSum->lLength = lSumLength

    // return TRUE
    mov     w0, #TRUE
    b       add_epilogue

add_return_false:
    // return FALSE due to overflow
    mov     w0, #FALSE

add_epilogue:
    // function epilogue
    ldr     x30, [sp, 56]                       // restore return address
    add     sp, sp, BIGINT_ADD_FRAME_SIZE       // deallocate stack frame
    ret

    .size   BigInt_add, . - BigInt_add