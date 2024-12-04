//-----------------------------------------------------------------------
    // bigintaddopt.s
    // Author: anish k
    // description: optimized assembly implementation of BigInt_add and BigInt_larger
    //-----------------------------------------------------------------------
    
    // defining constants
    .equ    FALSE_VAL, 0
    .equ    TRUE_VAL, 1
    .equ    MAX_DIGITS_COUNT, 32768
    
    // structure field offsets for BigInt_T
    .equ    LENGTH_OFFSET, 0          // offset of lLength in BigInt_T
    .equ    DIGITS_OFFSET, 8          // offset of aulDigits in BigInt_T
    
    .section .text
    
    // define callee-saved registers for variables
    OADDEND1        .req x19    // oAddend1
    OADDEND2        .req x20    // oAddend2
    OSUM            .req x21    // oSum
    LSUMLENGTH      .req x22    // lSumLength
    LINDEX          .req x23    // lIndex
    ULSUM           .req x24    // ulSum
    ULCARRY         .req x25    // ulCarry
    LLARGER         .req x26    // lLarger
    LLENGTH1        .req x27    // lLength1
    LLENGTH2        .req x28    // lLength2
    
    .global BigInt_larger
    .global BigInt_add
    
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
    
        // prologue: save link register
        sub     sp, sp, 16              // allocate minimal stack space
        str     x30, [sp]                // save link register
    
        // move parameters to callee-saved registers
        mov     LLENGTH1, x0             // lLength1 = x0
        mov     LLENGTH2, x1             // lLength2 = x1
    
        // compare lLength1 and lLength2
        cmp     LLENGTH1, LLENGTH2
        ble     select_length_two         // if lLength1 <= lLength2, select lLength2
    
        // set lLarger to lLength1
        mov     LLARGER, LLENGTH1
    
        // jump to conclude
        b       conclude_larger
    
    select_length_two:
        // set lLarger to lLength2
        mov     LLARGER, LLENGTH2
    
    conclude_larger:
        // move lLarger to return register
        mov     x0, LLARGER
    
        // epilog: restore link register and return
        ldr     x30, [sp]
        add     sp, sp, 16
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
    
        // prologue: save link register
        sub     sp, sp, 16              // allocate minimal stack space
        str     x30, [sp]                // save link register
    
        // move parameters to callee-saved registers
        mov     OADDEND1, x0             // oAddend1 = x0
        mov     OADDEND2, x1             // oAddend2 = x1
        mov     OSUM, x2                 // oSum = x2
    
        // determine the larger length
        ldr     x0, [OADDEND1, LENGTH_OFFSET]   // load oAddend1->lLength
        ldr     x1, [OADDEND2, LENGTH_OFFSET]   // load oAddend2->lLength
        bl      BigInt_larger                   // call BigInt_larger
        mov     LSUMLENGTH, x0                   // lSumLength = result
    
        // check if oSum->lLength <= lSumLength
        ldr     x0, [OSUM, LENGTH_OFFSET]       // load oSum->lLength
        cmp     x0, LSUMLENGTH
        ble     skip_clear_digits               // if oSum->lLength <= lSumLength, skip memset
    
        // perform memset(oSum->aulDigits, 0, MAX_DIGITS_COUNT * sizeof(unsigned long))
        add     x0, OSUM, DIGITS_OFFSET        // pointer to aulDigits
        mov     w1, 0                          // value to set
        mov     x2, MAX_DIGITS_COUNT           // size
        lsl     x2, x2, #3                     // multiply by 8 (size of unsigned long)
        bl      memset                          // call memset
    
    skip_clear_digits:
        // initialize ulCarry to 0
        mov     ULCARRY, 0
    
        // initialize lIndex to 0
        mov     LINDEX, 0
    
    addition_loop:
        // check if lIndex >= lSumLength
        cmp     LINDEX, LSUMLENGTH
        bge     handle_carry                    // if lIndex >= lSumLength, handle carry
    
        // ulSum = ulCarry
        mov     ULSUM, ULCARRY
    
        // ulCarry = 0
        mov     ULCARRY, 0
    
        // ulSum += oAddend1->aulDigits[lIndex]
        add     x1, OADDEND1, DIGITS_OFFSET        // pointer to oAddend1->aulDigits
        add     x1, x1, LINDEX, lsl #3             // pointer to oAddend1->aulDigits[lIndex]
        ldr     x2, [x1]                            // load oAddend1->aulDigits[lIndex]
        add     ULSUM, ULSUM, x2                    // ulSum += oAddend1->aulDigits[lIndex]
    
        // check for overflow: if (ulSum < oAddend1->aulDigits[lIndex])
        cmp     ULSUM, x2
        bhs     no_overflow_one                      // if ulSum >= digit, no overflow
        mov     ULCARRY, 1                            // set ulCarry = 1
    
    no_overflow_one:
        // ulSum += oAddend2->aulDigits[lIndex]
        add     x1, OADDEND2, DIGITS_OFFSET        // pointer to oAddend2->aulDigits
        add     x1, x1, LINDEX, lsl #3             // pointer to oAddend2->aulDigits[lIndex]
        ldr     x2, [x1]                            // load oAddend2->aulDigits[lIndex]
        add     ULSUM, ULSUM, x2                    // ulSum += oAddend2->aulDigits[lIndex]
    
        // check for overflow: if (ulSum < oAddend2->aulDigits[lIndex])
        cmp     ULSUM, x2
        bhs     no_overflow_two                      // if ulSum >= digit, no overflow
        mov     ULCARRY, 1                            // set ulCarry = 1
    
    no_overflow_two:
        // store ulSum into oSum->aulDigits[lIndex]
        add     x1, OSUM, DIGITS_OFFSET          // pointer to oSum->aulDigits
        add     x1, x1, LINDEX, lsl #3            // pointer to oSum->aulDigits[lIndex]
        str     ULSUM, [x1]                        // store ulSum
    
        // increment lIndex
        add     LINDEX, LINDEX, 1
    
        // repeat the loop
        b       addition_loop
    
    handle_carry:
        // check if ulCarry == 1
        cmp     ULCARRY, 1
        bne     finalize_sum_length                // if ulCarry != 1, skip handling
    
        // check if lSumLength == MAX_DIGITS_COUNT
        cmp     LSUMLENGTH, MAX_DIGITS_COUNT
        beq     overflow_detected                   // if equal, overflow occurred
    
        // set oSum->aulDigits[lSumLength] = 1
        add     x0, OSUM, DIGITS_OFFSET          // pointer to aulDigits
        add     x0, x0, LSUMLENGTH, lsl #3        // pointer to aulDigits[lSumLength]
        mov     x1, 1
        str     x1, [x0]                            // set the carry digit
    
        // increment lSumLength
        add     LSUMLENGTH, LSUMLENGTH, 1
    
    finalize_sum_length:
        // set oSum->lLength = lSumLength
        str     LSUMLENGTH, [OSUM, LENGTH_OFFSET] // store lSumLength into oSum->lLength
    
        // return TRUE_VAL
        mov     w0, TRUE_VAL
        ldr     x30, [sp]                          // restore link register
        add     sp, sp, 16
        ret
    
    overflow_detected:
        // return FALSE_VAL due to overflow
        mov     w0, FALSE_VAL
        ldr     x30, [sp]                          // restore link register
        add     sp, sp, 16
        ret
    
    .size   BigInt_add, .-BigInt_add