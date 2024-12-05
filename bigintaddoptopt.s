// defining constants
        .equ    FALSE, 0
        .equ    TRUE, 1
        .equ    EOF, -1
        .equ    MAX_DIGITS, 32768
//----------------------------------------------------------------------

        .section .rodata

//----------------------------------------------------------------------

        .section .data

//----------------------------------------------------------------------

        .section .bss

//----------------------------------------------------------------------

        .section .text

//--------------------------------------------------------------
// calculates the sum of addend1 and addend2, storing the result in sum.
// sum must be different from addend1 and addend2.
// returns 0 (FALSE) if an overflow occurred,
// and 1 (TRUE) otherwise.
// int BigInt_add(BigInt_T addend1, BigInt_T addend2, BigInt_T sum)
//--------------------------------------------------------------

// stack size must be a multiple of 16
        .equ    STACK_SIZE, 48

// local variable registers
SUM_LENGTH      .req x23       // holds the length of the sum
INDEX           .req x22       // index for looping

// parameter registers
SUM_PTR         .req x21       // pointer to sum
ADDEND2_PTR     .req x20       // pointer to addend2
ADDEND1_PTR     .req x19       // pointer to addend1

// structure field offsets
        .equ    DIGITS_OFFSET, 8   // offset for digits array in BigInt_T

        .global BigInt_add

BigInt_add:

        // prologue: set up the stack frame
        sub     sp, sp, STACK_SIZE
        str     x30, [sp]
        str     x19, [sp, 8]
        str     x20, [sp, 16]
        str     x21, [sp, 24]
        str     x22, [sp, 32]
        str     x23, [sp, 40]

        // move parameters into our registers
        mov     ADDEND1_PTR, x0
        mov     ADDEND2_PTR, x1
        mov     SUM_PTR, x2

        // declare local variables:
        // unsigned long ulSum;
        // long lIndex;
        // long lSumLength;

        // determine the larger length (inlined BigInt_larger)
        // if (addend1->lLength <= addend2->lLength) goto elseIfLess;
        ldr     x0, [ADDEND1_PTR]
        ldr     x1, [ADDEND2_PTR]
        cmp     x0, x1
        ble     elseIfLess
        // sumLength = addend1->lLength;
        mov     SUM_LENGTH, x0
        b       endIfGreater
elseIfLess:
        // sumLength = addend2->lLength;
        mov     SUM_LENGTH, x1
        // continue to endIfGreater
endIfGreater:
        // check if sum's array needs to be cleared

        // if (sum->lLength <= sumLength) goto endIfLength;
        ldr     x0, [SUM_PTR]
        cmp     x0, SUM_LENGTH
        ble     endIfLength

    // use memset to clear sum->digits to zero
    // memset(sum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long));
        add     x0, SUM_PTR, DIGITS_OFFSET
        mov     w1, 0
        mov     x2, MAX_DIGITS
        lsl     x2, x2, 3    // x2 = MAX_DIGITS * sizeof(unsigned long)
        bl      memset

endIfLength:

        // initialize index to 0
        mov     INDEX, 0

// perform the addition

        // start of guarded loop
        // if (index >= sumLength) goto endIfCarry;
        cmp     INDEX, SUM_LENGTH
        bge     endIfCarry
sumLoop:
        // load digits from addend1 and addend2
        add     x0, ADDEND1_PTR, DIGITS_OFFSET
        ldr     x0, [x0, INDEX, lsl 3]
        add     x1, ADDEND2_PTR, DIGITS_OFFSET
        ldr     x1, [x1, INDEX, lsl 3]
        // perform addition with carry
        adcs    x1, x0, x1
        // store result in sum->digits[index]
        add     x0, SUM_PTR, DIGITS_OFFSET
        str     x1, [x0, INDEX, lsl 3]

        // increment index
        add     INDEX, INDEX, 1

        // check if we need to continue the loop without affecting the carry flag
        // if (index < sumLength) goto sumLoop;
        sub     x0, SUM_LENGTH, INDEX
        CBNZ    x0, sumLoop

endSumLoop:
        // check for a carry out from the last addition

        // if carry flag is clear, skip to endIfCarry
        bcc     endIfCarry

        // check if sumLength is not equal to MAX_DIGITS
        // if (sumLength != MAX_DIGITS) goto endIfMax;
        cmp     SUM_LENGTH, MAX_DIGITS
        bne     endIfMax

        // overflow occurred, return FALSE
        mov     w0, FALSE
        // epilogue: restore registers and stack pointer
        ldr     x30, [sp]
        ldr     x19, [sp, 8]
        ldr     x20, [sp, 16]
        ldr     x21, [sp, 24]
        ldr     x22, [sp, 32]
        ldr     x23, [sp, 40]
        add     sp, sp, STACK_SIZE
        ret

endIfMax:
        // set sum->digits[sumLength] = 1
        add     x0, SUM_PTR, DIGITS_OFFSET
        mov     x2, 1
        str     x2, [x0, SUM_LENGTH, lsl 3]

        // increment sumLength
        add     SUM_LENGTH, SUM_LENGTH, 1

endIfCarry:
        // set the length of the sum
        // sum->lLength = sumLength;
        str     SUM_LENGTH, [SUM_PTR]

        // epilogue: restore registers and return TRUE
        mov     w0, TRUE
        ldr     x30, [sp]
        ldr     x19, [sp, 8]
        ldr     x20, [sp, 16]
        ldr     x21, [sp, 24]
        ldr     x22, [sp, 32]
        ldr     x23, [sp, 40]
        add     sp, sp, STACK_SIZE
        ret
.size   BigInt_add, (. -BigInt_add)