
// defining constants
.equ    FALSE, 0
.equ    TRUE, 1
.equ    MAX_DIGITS, 32768

// structure field offsets for BigInt_T
.equ    LLENGTH, 0          // offset of lLength in BigInt_T
.equ    AULDIGITS, 8        // offset of aulDigits in BigInt_T

// stack byte counts (should be multiples of 16 for alignment)
.equ    LARGER_STACK_SIZE, 32
.equ    ADD_STACK_SIZE, 64

// local variable stack offsets for BigInt_larger
.equ    LLARGER, 8
.equ    LLENGTH1, 16
.equ    LLENGTH2, 24

// local variable stack offsets for BigInt_add
.equ    LSUMLENGTH, 8
.equ    LINDEX, 16
.equ    ULSUM, 24
.equ    ULCARRY, 32

// parameter stack offsets for BigInt_add
.equ    OSUM, 40
.equ    OADDEND2, 48
.equ    OADDEND1, 56

.global BigInt_larger
.global BigInt_add

.section .text

//--------------------------------------------------------------
// return the larger of lLength1 and lLength2
// long BigInt_larger(long lLength1, long lLength2)
//--------------------------------------------------------------

BigInt_larger:

    // set up the stack frame
    sub     sp, sp, LARGER_STACK_SIZE
    str     x30, [sp]                        // save link register
    str     x0, [sp, LLENGTH1]               // store first parameter
    str     x1, [sp, LLENGTH2]               // store second parameter

    // load lLength1 and lLength2 from stack
    ldr     x0, [sp, LLENGTH1]
    ldr     x1, [sp, LLENGTH2]

    // compare lLength1 and lLength2
    cmp     x0, x1
    ble     choose_length2                    // if lLength1 <= lLength2, choose lLength2

    // lLarger = lLength1
    str     x0, [sp, LLARGER]
    b       finish_larger                     // jump to end

choose_length2:
    // lLarger = lLength2
    str     x1, [sp, LLARGER]

finish_larger:
    // load lLarger into return register
    ldr     x0, [sp, LLARGER]

    // restore stack frame and return
    ldr     x30, [sp]
    add     sp, sp, LARGER_STACK_SIZE
    ret

.size   BigInt_larger, .-BigInt_larger

//--------------------------------------------------------------
// assign the sum of oAddend1 and oAddend2 to oSum
// oSum should be distinct from oAddend1 and oAddend2
// return 0 (FALSE) if an overflow occurred, and 1 (TRUE) otherwise
// int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
//--------------------------------------------------------------

BigInt_add:

    // set up the stack frame
    sub     sp, sp, ADD_STACK_SIZE
    str     x30, [sp]                         // save link register
    str     x0, [sp, OADDEND1]                // store oAddend1
    str     x1, [sp, OADDEND2]                // store oAddend2
    str     x2, [sp, OSUM]                    // store oSum

    // load lLength1 from oAddend1->lLength
    ldr     x0, [sp, OADDEND1]
    ldr     x0, [x0, LLENGTH]

    // load lLength2 from oAddend2->lLength
    ldr     x1, [sp, OADDEND2]
    ldr     x1, [x1, LLENGTH]

    // call BigInt_larger to get lSumLength
    bl      BigInt_larger
    str     x0, [sp, LSUMLENGTH]               // store lSumLength

    // check if oSum->lLength <= lSumLength
    ldr     x0, [sp, OSUM]
    ldr     x0, [x0, LLENGTH]
    ldr     x1, [sp, LSUMLENGTH]
    cmp     x0, x1
    ble     skip_memset                        // if true, skip memset

    // perform memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long))
    ldr     x0, [sp, OSUM]
    add     x0, x0, AULDIGITS                  // point to aulDigits
    mov     w1, 0                              // value to set
    mov     x2, MAX_DIGITS
    lsl     x2, x2, #3                         // MAX_DIGITS * 8
    bl      memset                             // call memset

skip_memset:
    // initialize ulCarry to 0
    mov     x0, 0
    str     x0, [sp, ULCARRY]

    // initialize lIndex to 0
    mov     x0, 0
    str     x0, [sp, LINDEX]

loop_start:
    // check if lIndex >= lSumLength
    ldr     x0, [sp, LINDEX]
    ldr     x1, [sp, LSUMLENGTH]
    cmp     x0, x1
    bge     loop_end                           // if true, exit loop

    // ulSum = ulCarry
    ldr     x0, [sp, ULCARRY]
    str     x0, [sp, ULSUM]

    // ulCarry = 0
    mov     x0, 0
    str     x0, [sp, ULCARRY]

    // ulSum += oAddend1->aulDigits[lIndex]
    ldr     x1, [sp, OADDEND1]
    add     x1, x1, AULDIGITS                  // point to aulDigits
    ldr     x2, [sp, LINDEX]
    lsl     x2, x2, #3                         // lIndex * 8
    add     x1, x1, x2
    ldr     x3, [x1]                            // load oAddend1->aulDigits[lIndex]
    ldr     x0, [sp, ULSUM]
    add     x0, x0, x3
    str     x0, [sp, ULSUM]

    // check for overflow: if (ulSum < oAddend1->aulDigits[lIndex])
    cmp     x0, x3
    bhs     no_overflow1                        // if ulSum >= digit, no overflow
    mov     x4, 1
    str     x4, [sp, ULCARRY]                  // set ulCarry = 1

no_overflow1:
    // ulSum += oAddend2->aulDigits[lIndex]
    ldr     x1, [sp, OADDEND2]
    add     x1, x1, AULDIGITS                  // point to aulDigits
    ldr     x2, [sp, LINDEX]
    lsl     x2, x2, #3                         // lIndex * 8
    add     x1, x1, x2
    ldr     x3, [x1]                            // load oAddend2->aulDigits[lIndex]
    ldr     x0, [sp, ULSUM]
    add     x0, x0, x3
    str     x0, [sp, ULSUM]

    // check for overflow: if (ulSum < oAddend2->aulDigits[lIndex])
    cmp     x0, x3
    bhs     no_overflow2                        // if ulSum >= digit, no overflow
    mov     x4, 1
    str     x4, [sp, ULCARRY]                  // set ulCarry = 1

no_overflow2:
    // oSum->aulDigits[lIndex] = ulSum
    ldr     x1, [sp, OSUM]
    add     x1, x1, AULDIGITS                  // point to aulDigits
    ldr     x2, [sp, LINDEX]
    lsl     x2, x2, #3                         // lIndex * 8
    add     x1, x1, x2
    ldr     x0, [sp, ULSUM]
    str     x0, [x1]                            // store ulSum

    // increment lIndex
    ldr     x0, [sp, LINDEX]
    add     x0, x0, 1
    str     x0, [sp, LINDEX]

    // repeat the loop
    b       loop_start

loop_end:
    // check if there was a carry out
    ldr     x0, [sp, ULCARRY]
    cmp     x0, 1
    bne     set_sum_length                      // if no carry, skip handling

    // check if lSumLength == MAX_DIGITS
    ldr     x1, [sp, LSUMLENGTH]
    cmp     x1, MAX_DIGITS
    beq     return_false                         // if equal, overflow occurred

    // set oSum->aulDigits[lSumLength] = 1
    ldr     x0, [sp, OSUM]
    add     x0, x0, AULDIGITS                  // point to aulDigits
    ldr     x2, [sp, LSUMLENGTH]
    lsl     x2, x2, #3                         // lSumLength * 8
    add     x0, x0, x2
    mov     x1, 1
    str     x1, [x0]                            // set the carry digit

    // increment lSumLength
    ldr     x0, [sp, LSUMLENGTH]
    add     x0, x0, 1
    str     x0, [sp, LSUMLENGTH]

set_sum_length:
    // set oSum->lLength = lSumLength
    ldr     x0, [sp, LSUMLENGTH]
    ldr     x1, [sp, OSUM]
    str     x0, [x1, LLENGTH]

    // return TRUE
    mov     w0, TRUE
    ldr     x30, [sp]
    add     sp, sp, ADD_STACK_SIZE
    ret

return_false:
    // return FALSE due to overflow
    mov     w0, FALSE
    ldr     x30, [sp]
    add     sp, sp, ADD_STACK_SIZE
    ret

.size   BigInt_add, .-BigInt_add
