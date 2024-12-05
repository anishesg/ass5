// define constants
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
// assigns the sum of addend1 and addend2 to result.
// result should be distinct from addend1 and addend2.
// returns 0 (FALSE) if an overflow occurred,
// and 1 (TRUE) otherwise.
// int big_int_add(BigInt_T addend1, BigInt_T addend2, BigInt_T result)
//--------------------------------------------------------------

// stack size must be a multiple of 16
.equ    STACK_FRAME_SIZE, 48

// local variable registers
sum_length      .req x23
index           .req x22

// parameter registers
result          .req x21
addend2         .req x20
addend1         .req x19

// structure field offsets
.equ    DIGITS_OFFSET, 8

.global big_int_add

big_int_add:

    // prologue: set up the stack frame and save registers
    sub     sp, sp, STACK_FRAME_SIZE
    str     x30, [sp]          // save return address
    str     x19, [sp, 8]       // save x19 (addend1)
    str     x20, [sp, 16]      // save x20 (addend2)
    str     x21, [sp, 24]      // save x21 (result)
    str     x22, [sp, 32]      // save x22 (index)
    str     x23, [sp, 40]      // save x23 (sum_length)

    // move parameters into callee-saved registers
    mov     addend1, x0
    mov     addend2, x1
    mov     result, x2

    // initialize local variables
    // unsigned long carry;
    // long index;
    // long sum_length;

    // determine the larger length between addend1 and addend2
    ldr     x0, [addend1]      // x0 = addend1->length
    ldr     x1, [addend2]      // x1 = addend2->length
    cmp     x0, x1
    ble     use_addend2_length
    // sum_length = addend1->length;
    mov     sum_length, x0
    b       length_determined
use_addend2_length:
    // sum_length = addend2->length;
    mov     sum_length, x1
length_determined:
    // check if result's length is sufficient
    ldr     x0, [result]       // x0 = result->length
    cmp     x0, sum_length
    ble     skip_clearing

    // clear result's digits array if necessary
    // memset(result->digits, 0, MAX_DIGITS * sizeof(unsigned long));
    add     x0, result, DIGITS_OFFSET  // x0 = result->digits
    mov     w1, 0                      // value to set
    mov     x2, MAX_DIGITS
    lsl     x2, x2, 3                  // x2 = MAX_DIGITS * 8
    bl      memset                     // call memset
skip_clearing:

    // initialize index to 0
    mov     index, 0

    // perform the addition loop
addition_loop:
    cmp     index, sum_length
    bge     check_carry

    // load digits from addend1 and addend2
    add     x0, addend1, DIGITS_OFFSET
    ldr     x0, [x0, index, lsl #3]    // x0 = addend1->digits[index]
    add     x1, addend2, DIGITS_OFFSET
    ldr     x1, [x1, index, lsl #3]    // x1 = addend2->digits[index]

    // add the digits with carry
    adcs    x1, x0, x1                 // x1 = x0 + x1 + carry

    // store the result digit
    add     x0, result, DIGITS_OFFSET
    str     x1, [x0, index, lsl #3]    // result->digits[index] = x1

    // increment index
    add     index, index, 1
    b       addition_loop

check_carry:
    // check for carry out of the last addition
    bcc     set_result_length          // if no carry, skip to setting length

    // if sum_length == MAX_DIGITS, overflow occurred
    cmp     sum_length, MAX_DIGITS
    beq     return_overflow

    // handle the carry by adding an extra digit
    add     x0, result, DIGITS_OFFSET
    mov     x1, 1
    str     x1, [x0, sum_length, lsl #3]  // result->digits[sum_length] = 1

    // increment sum_length
    add     sum_length, sum_length, 1

set_result_length:
    // set the length of the result
    str     sum_length, [result]       // result->length = sum_length

    // return TRUE (no overflow)
    mov     w0, TRUE

    // epilogue: restore registers and stack pointer, then return
    ldr     x30, [sp]
    ldr     x19, [sp, 8]
    ldr     x20, [sp, 16]
    ldr     x21, [sp, 24]
    ldr     x22, [sp, 32]
    ldr     x23, [sp, 40]
    add     sp, sp, STACK_FRAME_SIZE
    ret

return_overflow:
    // return FALSE due to overflow
    mov     w0, FALSE

    // epilogue: restore registers and stack pointer, then return
    ldr     x30, [sp]
    ldr     x19, [sp, 8]
    ldr     x20, [sp, 16]
    ldr     x21, [sp, 24]
    ldr     x22, [sp, 32]
    ldr     x23, [sp, 40]
    add     sp, sp, STACK_FRAME_SIZE
    ret

.size   big_int_add, (. - big_int_add)