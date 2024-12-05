// define constants
        .equ    FALSE_VALUE, 0
        .equ    TRUE_VALUE, 1
        .equ    END_OF_FILE, -1
        .equ    MAXIMUM_DIGITS, 32768
//----------------------------------------------------------------------

        .section .rodata

//----------------------------------------------------------------------

        .section .data

//----------------------------------------------------------------------

        .section .bss

//----------------------------------------------------------------------

        .section .text

//--------------------------------------------------------------
// assign the sum of addend1 and addend2 to sum.
// sum should be distinct from addend1 and addend2.
// return 0 (FALSE_VALUE) if an overflow occurred,
// and 1 (TRUE_VALUE) otherwise.
// int BigInt_add(BigInt_T addend1, BigInt_T addend2, BigInt_T sum)
//--------------------------------------------------------------

// stack frame size must be a multiple of 16 bytes
        .equ    STACK_FRAME_SIZE, 48

// local variable register aliases
        sum_length      .req x23    // holds the length of the sum
        index           .req x22    // loop index

// parameter register aliases
        sum_ptr         .req x21    // pointer to sum BigInt_T
        addend2_ptr     .req x20    // pointer to addend2 BigInt_T
        addend1_ptr     .req x19    // pointer to addend1 BigInt_T

// structure field offsets
        .equ    DIGITS_OFFSET, 8    // offset of digits array in BigInt_T structure

        .global BigInt_add

BigInt_add:

        // prologue: set up stack frame and save necessary registers
        sub     sp, sp, STACK_FRAME_SIZE
        str     x30, [sp]          // save return address
        str     x19, [sp, 8]       // save x19 (addend1_ptr)
        str     x20, [sp, 16]      // save x20 (addend2_ptr)
        str     x21, [sp, 24]      // save x21 (sum_ptr)
        str     x22, [sp, 32]      // save x22 (index)
        str     x23, [sp, 40]      // save x23 (sum_length)

        // move parameters into callee-saved registers
        mov     addend1_ptr, x0
        mov     addend2_ptr, x1
        mov     sum_ptr, x2

        // variables: unsigned long carry; long index; long sum_length;

        // determine the larger length between addend1 and addend2
        ldr     x0, [addend1_ptr]      // x0 = addend1->length
        ldr     x1, [addend2_ptr]      // x1 = addend2->length
        cmp     x0, x1
        ble     use_addend2_length
        // sum_length = addend1->length;
        mov     sum_length, x0
        b       length_determined
use_addend2_length:
        // sum_length = addend2->length;
        mov     sum_length, x1
length_determined:
        // check if sum's length is sufficient
        ldr     x0, [sum_ptr]          // x0 = sum->length
        cmp     x0, sum_length
        ble     skip_clearing

        // clear sum's digits array if necessary
        // memset(sum->digits, 0, MAXIMUM_DIGITS * sizeof(unsigned long));
        add     x0, sum_ptr, DIGITS_OFFSET  // x0 = address of sum->digits
        mov     w1, #0                      // value to set (zero)
        mov     x2, #MAXIMUM_DIGITS
        lsl     x2, x2, #3                  // x2 = MAXIMUM_DIGITS * 8 (size in bytes)
        bl      memset                      // call memset to clear digits
skip_clearing:

        // initialize index to 0
        mov     index, #0

// perform the addition loop
addition_loop:
        cmp     index, sum_length
        bge     check_carry     // if index >= sum_length, exit loop

        // load digits from addend1 and addend2
        add     x0, addend1_ptr, DIGITS_OFFSET
        ldr     x0, [x0, index, lsl #3]    // x0 = addend1->digits[index]
        add     x1, addend2_ptr, DIGITS_OFFSET
        ldr     x1, [x1, index, lsl #3]    // x1 = addend2->digits[index]

        // add the digits with carry
        adcs    x1, x0, x1                 // x1 = x0 + x1 + carry

        // store the result digit
        add     x0, sum_ptr, DIGITS_OFFSET
        str     x1, [x0, index, lsl #3]    // sum->digits[index] = x1

        // increment index
        add     index, index, #1
        b       addition_loop

check_carry:
        // check for carry out of the last addition
        bcc     set_sum_length          // if no carry (C flag clear), proceed

        // if sum_length == MAXIMUM_DIGITS, overflow occurred
        cmp     sum_length, #MAXIMUM_DIGITS
        beq     return_overflow            // if sum_length equals MAXIMUM_DIGITS, overflow

        // handle the carry by adding an extra digit
        add     x0, sum_ptr, DIGITS_OFFSET
        mov     x1, #1
        str     x1, [x0, sum_length, lsl #3]  // sum->digits[sum_length] = 1

        // increment sum_length
        add     sum_length, sum_length, #1

set_sum_length:
        // set the length of the sum
        str     sum_length, [sum_ptr]       // sum->length = sum_length

        // return TRUE_VALUE (no overflow)
        mov     w0, #TRUE_VALUE

        // epilogue: restore registers and stack pointer, then return
        ldr     x30, [sp]          // restore return address
        ldr     x19, [sp, 8]       // restore x19 (addend1_ptr)
        ldr     x20, [sp, 16]      // restore x20 (addend2_ptr)
        ldr     x21, [sp, 24]      // restore x21 (sum_ptr)
        ldr     x22, [sp, 32]      // restore x22 (index)
        ldr     x23, [sp, 40]      // restore x23 (sum_length)
        add     sp, sp, STACK_FRAME_SIZE
        ret

return_overflow:
        // return FALSE_VALUE due to overflow
        mov     w0, #FALSE_VALUE

        // epilogue: restore registers and stack pointer, then return
        ldr     x30, [sp]          // restore return address
        ldr     x19, [sp, 8]       // restore x19 (addend1_ptr)
        ldr     x20, [sp, 16]      // restore x20 (addend2_ptr)
        ldr     x21, [sp, 24]      // restore x21 (sum_ptr)
        ldr     x22, [sp, 32]      // restore x22 (index)
        ldr     x23, [sp, 40]      // restore x23 (sum_length)
        add     sp, sp, STACK_FRAME_SIZE
        ret

.size   BigInt_add, (. - BigInt_add)