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

// stack size must be a multiple of 16
        .equ    STACK_BYTECOUNT, 48

// local variable registers
        sum_length_reg      .req x23
        index_reg           .req x22

// parameter registers
        sum_reg             .req x21
        addend2_reg         .req x20
        addend1_reg         .req x19

// structure field offsets
        .equ    DIGITS_OFFSET,  8
        
        .global BigInt_add

BigInt_add:

        // prologue: set up the stack frame and save registers
        sub     sp, sp, STACK_BYTECOUNT
        str     x30, [sp]          // save return address
        str     x19, [sp, 8]       // save x19 (addend1_reg)
        str     x20, [sp, 16]      // save x20 (addend2_reg)
        str     x21, [sp, 24]      // save x21 (sum_reg)
        str     x22, [sp, 32]      // save x22 (index_reg)
        str     x23, [sp, 40]      // save x23 (sum_length_reg)

        // move parameters into registers
        mov     addend1_reg, x0
        mov     addend2_reg, x1
        mov     sum_reg, x2

        // initialize local variables
        // unsigned long ulSum;
        // long index;
        // long sum_length;
        
        // determine the larger length (inlined BigInt_larger)
        // if (addend1->lLength <= addend2->lLength) goto else_if_less;
        ldr     x0, [addend1_reg]
        ldr     x1, [addend2_reg]
        cmp     x0, x1
        ble     else_if_less
        // sum_length = addend1->lLength;
        mov     sum_length_reg, x0
        // goto end_if_greater;
        b       end_if_greater
else_if_less:
        // sum_length = addend2->lLength;
        mov     sum_length_reg,  x1
        // proceed to end_if_greater;
end_if_greater:
        // clear sum's array if necessary.

        // if (sum->lLength <= sum_length) goto end_if_length;
        ldr     x0, [sum_reg]
        cmp     x0, sum_length_reg
        ble     end_if_length

        // memset(sum->aulDigits, 0, MAXIMUM_DIGITS * sizeof(unsigned long));
        add     x0, sum_reg, DIGITS_OFFSET
        mov     w1, 0
        mov     x2, MAXIMUM_DIGITS
        lsl     x2, x2, 3           // multiply by sizeof(unsigned long)
        bl      memset
        
end_if_length:

        // index = 0;
        mov     index_reg, 0
        
// perform the addition.

// guarded loop: if index >= sum_length, skip to end_if_carry
// if (index >= sum_length) goto end_if_carry;
        cmp     index_reg, sum_length_reg
        bge     end_if_carry
sum_loop:
        // sum->aulDigits[index] = addend1->aulDigits[index] + addend2->aulDigits[index]
        add     x0, addend1_reg, DIGITS_OFFSET
        ldr     x0, [x0, index_reg, lsl 3]
        add     x1, addend2_reg, DIGITS_OFFSET
        ldr     x1, [x1, index_reg, lsl 3]
        // add with carry
        adcs    x1, x0, x1
        // store result in sum
        add     x0, sum_reg, DIGITS_OFFSET
        str     x1, [x0, index_reg, lsl 3]
        
        // index++;
        add     index_reg, index_reg, 1

        // compare index and sum_length without affecting flags
        // if (index < sum_length) goto sum_loop;
        sub     x0, sum_length_reg, index_reg
        cbnz    x0, sum_loop

end_sum_loop:
        // check for a carry out of the last addition.

        // if carry flag is clear, skip to end_if_carry;
        bcc     end_if_carry

        // if (sum_length != MAXIMUM_DIGITS) goto end_if_max;
        cmp     sum_length_reg, MAXIMUM_DIGITS
        bne     end_if_max

        // return FALSE_VALUE due to overflow
        mov     w0, FALSE_VALUE
        // epilogue: restore registers and stack pointer
        ldr     x30, [sp]          // restore return address
        ldr     x19, [sp, 8]       // restore x19
        ldr     x20, [sp, 16]      // restore x20
        ldr     x21, [sp, 24]      // restore x21
        ldr     x22, [sp, 32]      // restore x22
        ldr     x23, [sp, 40]      // restore x23
        add     sp, sp, STACK_BYTECOUNT
        ret

end_if_max:
        // sum->aulDigits[sum_length] = 1;
        add     x0, sum_reg, DIGITS_OFFSET
        mov     x2, 1
        str     x2, [x0, sum_length_reg, lsl 3]

        // sum_length++;
        add     sum_length_reg, sum_length_reg, 1

end_if_carry:
        // set the length of the sum.
        // sum->lLength = sum_length;
        str     sum_length_reg, [sum_reg]

        // epilogue: restore registers and return TRUE_VALUE
        mov     w0, TRUE_VALUE
        ldr     x30, [sp]          // restore return address
        ldr     x19, [sp, 8]       // restore x19
        ldr     x20, [sp, 16]      // restore x20
        ldr     x21, [sp, 24]      // restore x21
        ldr     x22, [sp, 32]      // restore x22
        ldr     x23, [sp, 40]      // restore x23
        add     sp, sp, STACK_BYTECOUNT
        ret
.size   BigInt_add, (. -BigInt_add)