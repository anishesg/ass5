// define constants
.equ    FALSE_VALUE, 0
.equ    TRUE_VALUE, 1
.equ    END_OF_FILE, -1
.equ    MAXIMUM_DIGITS, 32768
//----------------------------------------------------------------------

.section .rodata
///----------------------------------------------------------------------

.section .data
//----------------------------------------------------------------------

.section .bss
//----------------------------------------------------------------------

.section .text

//--------------------------------------------------------------
// this function assigns the sum of addend1 and addend2 to result.
// result should be distinct from addend1 and addend2.
// returns 0 (FALSE_VALUE) if an overflow occurred,
// and 1 (TRUE_VALUE) otherwise.
// int BigInt_add(BigInt_T addend1, BigInt_T addend2, BigInt_T result)
//--------------------------------------------------------------

// stack frame size must be a multiple of 16 bytes
.equ    STACK_FRAME_SIZE, 48

// local variable register aliases
sum_length      .req x23    // holds the length of the sum
index_reg       .req x22    // loop index

// parameter register aliases
result_reg      .req x21    // pointer to result BigInt_T
addend2_reg     .req x20    // pointer to addend2 BigInt_T
addend1_reg     .req x19    // pointer to addend1 BigInt_T

// structure field offsets
.equ    DIGITS_OFFSET, 8    // offset of digits array in BigInt_T structure

.global BigInt_add

BigInt_add:

    // prologue: set up the stack frame and save necessary registers
    sub     sp, sp, STACK_FRAME_SIZE
    str     x30, [sp]          // save return address (link register)
    str     x19, [sp, 8]       // save x19 (addend1_reg)
    str     x20, [sp, 16]      // save x20 (addend2_reg)
    str     x21, [sp, 24]      // save x21 (result_reg)
    str     x22, [sp, 32]      // save x22 (index_reg)
    str     x23, [sp, 40]      // save x23 (sum_length)

    // move parameters into callee-saved registers for use
    mov     addend1_reg, x0
    mov     addend2_reg, x1
    mov     result_reg, x2

    // initialize local variables (carry flag is used by adcs instruction)
    // unsigned long carry;
    // long index;
    // long sum_length;

    // determine the larger length between addend1 and addend2
    ldr     x0, [addend1_reg]      // x0 = addend1->length
    ldr     x1, [addend2_reg]      // x1 = addend2->length
    cmp     x0, x1                 // compare lengths
    ble     use_addend2_length     // if addend1 length <= addend2 length, use addend2 length
    // sum_length = addend1->length;
    mov     sum_length, x0         // sum_length = addend1 length
    b       length_determined      // proceed to length_determined
use_addend2_length:
    // sum_length = addend2->length;
    mov     sum_length, x1         // sum_length = addend2 length
length_determined:
    // check if result's length is sufficient
    ldr     x0, [result_reg]       // x0 = result->length
    cmp     x0, sum_length
    ble     skip_clearing          // if result length <= sum_length, skip clearing

    // clear result's digits array if necessary
    // memset(result->digits, 0, MAXIMUM_DIGITS * sizeof(unsigned long));
    add     x0, result_reg, DIGITS_OFFSET  // x0 = address of result->digits
    mov     w1, #0                      // value to set (zero)
    mov     x2, #MAXIMUM_DIGITS
    lsl     x2, x2, #3                  // x2 = MAXIMUM_DIGITS * 8 (size in bytes)
    bl      memset                      // call memset to clear digits
skip_clearing:

    // initialize index to 0
    mov     index_reg, #0

    // perform the addition loop
addition_loop:
    cmp     index_reg, sum_length
    bge     check_carry     // if index >= sum_length, exit loop

    // load digits from addend1 and addend2
    add     x0, addend1_reg, DIGITS_OFFSET
    ldr     x0, [x0, index_reg, lsl #3]    // x0 = addend1->digits[index]
    add     x1, addend2_reg, DIGITS_OFFSET
    ldr     x1, [x1, index_reg, lsl #3]    // x1 = addend2->digits[index]

    // add the digits with carry
    adcs    x1, x0, x1                 // x1 = x0 + x1 + carry (updates carry flag)

    // store the result digit
    add     x0, result_reg, DIGITS_OFFSET
    str     x1, [x0, index_reg, lsl #3]    // result->digits[index] = x1

    // increment index
    add     index_reg, index_reg, #1
    b       addition_loop

check_carry:
    // check for carry out of the last addition
    bcc     set_result_length          // if no carry (C flag clear), proceed to set_result_length

    // if sum_length == MAXIMUM_DIGITS, overflow occurred
    cmp     sum_length, #MAXIMUM_DIGITS
    beq     return_overflow            // if sum_length equals MAXIMUM_DIGITS, overflow

    // handle the carry by adding an extra digit
    add     x0, result_reg, DIGITS_OFFSET
    mov     x1, #1
    str     x1, [x0, sum_length, lsl #3]  // result->digits[sum_length] = 1

    // increment sum_length
    add     sum_length, sum_length, #1

set_result_length:
    // set the length of the result
    str     sum_length, [result_reg]       // result->length = sum_length

    // return TRUE_VALUE (no overflow)
    mov     w0, #TRUE_VALUE

    // epilogue: restore registers and stack pointer, then return
    ldr     x30, [sp]          // restore return address
    ldr     x19, [sp, 8]       // restore x19 (addend1_reg)
    ldr     x20, [sp, 16]      // restore x20 (addend2_reg)
    ldr     x21, [sp, 24]      // restore x21 (result_reg)
    ldr     x22, [sp, 32]      // restore x22 (index_reg)
    ldr     x23, [sp, 40]      // restore x23 (sum_length)
    add     sp, sp, STACK_FRAME_SIZE
    ret

return_overflow:
    // return FALSE_VALUE due to overflow
    mov     w0, #FALSE_VALUE

    // epilogue: restore registers and stack pointer, then return
    ldr     x30, [sp]          // restore return address
    ldr     x19, [sp, 8]       // restore x19 (addend1_reg)
    ldr     x20, [sp, 16]      // restore x20 (addend2_reg)
    ldr     x21, [sp, 24]      // restore x21 (result_reg)
    ldr     x22, [sp, 32]      // restore x22 (index_reg)
    ldr     x23, [sp, 40]      // restore x23 (sum_length)
    add     sp, sp, STACK_FRAME_SIZE
    ret

.size   BigInt_add, (. - BigInt_add)