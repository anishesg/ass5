//---------------------------------------------------------------------
//---------------------------------------------------------------------
        .section .text

        .equ     FALSE, 0
        .equ     TRUE, 1
        .equ     MAX_DIGITS, 32768

       //--------------------------------------------------------------
       // Assign the sum of oAddend1 and oAddend2 to oSum.  
       // Return 0 (FALSE) if an overflow occurred, and 1 (TRUE) 
       // otherwise.
       //--------------------------------------------------------------
       
        .equ     BIGINT_ADD_STACK_BYTECOUNT, 48
        .equ     AULDIGITS, 8

        // Local variable and parameter offsets
        .equ     ULCARRY_OFFSET, 8
        .equ     ULSUM_OFFSET, 16
        .equ     LINDEX_OFFSET, 24
        .equ     LSUMLENGTH_OFFSET, 32

        ulSum           .req x6
        lIndex          .req x7
        lSumLength      .req x22

        oAddend1        .req x23
        oAddend2        .req x24
        oSum            .req x25

        .global BigInt_add

BigInt_add:
        // Prolog 
        sub     sp, sp, BIGINT_ADD_STACK_BYTECOUNT
        str     x30, [sp]
        str     x22, [sp, ULCARRY_OFFSET]
        str     x23, [sp, ULSUM_OFFSET]
        str     x24, [sp, LINDEX_OFFSET]
        str     x25, [sp, LSUMLENGTH_OFFSET]

        // save parameters to callee saved registers
        mov     oAddend1, x0
        mov     oAddend2, x1
        mov     oSum, x2

        // OPTIMIZATION 2F_2: inline the call to BigInt_larger 
        ldr     lSumLength, [oAddend1, 0]
        ldr     x1, [oAddend2, 0]
        cmp     lSumLength, x1 
        bgt     use
        mov     lSumLength, x1 

use: 
        // clear oSum memory if necessary  
        ldr     x0, [oSum, 0]            // Load oSum->lLength
        cmp     x0, lSumLength
        ble     skip_clear

        mov     x0, oSum
        add     x0, x0, AULDIGITS
        mov     w1, 0
        mov     x2, MAX_DIGITS
        lsl     x2, x2, 3
        bl      memset

skip_clear:
        // Initialize ulCarry and lIndex
        mov     lIndex, 0
        adds    x0, x0, xzr

        // OPTIMIZATION 2F_1: guarded loop pattern
        sub     x0, lIndex, lSumLength
        cbz     x0, check_carry_out  // Exit if lIndex >= lSumLength

loop_start: 
        // OPTIMIZATION 2F_3: use adcs, 
        //eliminate ifs for carry checking
    
        // ulSum = ulCarry;
        // ulCarry = 0;
        // ulSum += oAddend1->aulDigits[lIndex];
        add     x0, oAddend1, AULDIGITS
        ldr     x1, [x0, lIndex, lsl 3]

        // ulSum += oAddend2->aulDigits[lIndex];
        add     x0, oAddend2, AULDIGITS
        ldr     x2, [x0, lIndex, lsl 3]

        adcs    ulSum, x1, x2

        // oSum->aulDigits[lIndex] = ulSum;
        add     x0, oSum, AULDIGITS
        str     ulSum, [x0, lIndex, lsl 3]

        // lIndex++; 
        add     lIndex, lIndex, 1 
        sub     x0, lSumLength, lIndex
        cbnz    x0, loop_start // if (lIndex < lSumLength) goto loop_start;

check_carry_out:
        // if ulCarry doesn't equal to 1, go to set_length
        bcc     set_length

        // if (lSumLength == MAX_DIGITS) return FALSE
        cmp     lSumLength, MAX_DIGITS
        beq     return

add_carry:
        // oSum->aulDigits[lSumLength] = 1;
        mov     x0, 1
        add     x1, oSum, AULDIGITS 
        str     x0, [x1, lSumLength, lsl 3]

        // lSumLength++ 
        add     lSumLength, lSumLength, 1 

set_length: 
        // oSum->lLength = lSumLength; 
        str     lSumLength, [oSum, 0] 

        // return TRUE;
        mov     w0, TRUE 
        ldr     x30, [sp]
        ldr     x22, [sp, ULCARRY_OFFSET]
        ldr     x23, [sp, ULSUM_OFFSET]
        ldr     x24, [sp, LINDEX_OFFSET]
        ldr     x25, [sp, LSUMLENGTH_OFFSET]
        add     sp, sp, BIGINT_ADD_STACK_BYTECOUNT
        ret

return:
        // Epilog: Restore stack space
        ldr     x30, [sp]
        ldr     x22, [sp, ULCARRY_OFFSET]
        ldr     x23, [sp, ULSUM_OFFSET]
        ldr     x24, [sp, LINDEX_OFFSET]
        ldr     x25, [sp, LSUMLENGTH_OFFSET]
        add     sp, sp, BIGINT_ADD_STACK_BYTECOUNT
        ret 

        .size   BigInt_add, (. - BigInt_add)