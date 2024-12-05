// define constants
        .equ    FALSE_VALUE, 0
        .equ    TRUE_VALUE, 1
        .equ    END_OF_FILE, -1
        .equ    MAXIMUM_DIGITS, 0x8000    // Changed to hexadecimal (32768 -> 0x8000)
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
        .equ    STACK_BYTECOUNT, 0x30     // Changed to hexadecimal (48 -> 0x30)

// local variable registers
        sum_length_reg      .req x23
        index_reg           .req x22

// parameter registers
        sum_reg             .req x21
        addend2_reg         .req x20
        addend1_reg         .req x19

// structure field offsets
        .equ    DIGITS_OFFSET,  8

        // Macros for saving and restoring registers (Change 12)
        .macro SAVE_REGISTERS
            stp     x30, x19, [sp, #0]      // save return address and x19
            stp     x20, x21, [sp, #16]     // save x20 and x21
            stp     x22, x23, [sp, #32]     // save x22 and x23
        .endm

        .macro RESTORE_REGISTERS
            ldp     x22, x23, [sp, #32]     // restore x22 and x23
            ldp     x20, x21, [sp, #16]     // restore x20 and x21
            ldp     x30, x19, [sp, #0]      // restore return address and x19
        .endm

        .global BigInt_add

BigInt_add:

        // prologue: set up the stack frame and save registers
        sub     sp, sp, STACK_BYTECOUNT
        SAVE_REGISTERS                     // Using macro to save registers (Change 12)

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
        b.le    else_if_less               // Changed 'ble' to 'b.le' (Change 13)
        // sum_length = addend1->lLength;
        mov     sum_length_reg, x0
        // goto end_if_greater;
        b       end_if_greater
else_if_less:
        // sum_length = addend2->lLength;
        mov     sum_length_reg, x1
        // proceed to end_if_greater;
end_if_greater:
        // clear sum's array if necessary.

        // if (sum->lLength <= sum_length) goto end_if_length;
        ldr     x0, [sum_reg]
        cmp     x0, sum_length_reg
        b.le    end_if_length              // Changed 'ble' to 'b.le' (Change 13)

        // memset(sum->aulDigits, 0, MAXIMUM_DIGITS * sizeof(unsigned long));
        add     x0, sum_reg, DIGITS_OFFSET
        mov     w1, #0                     // Added '#' to immediate value (Change 7)
        mov     x2, MAXIMUM_DIGITS
        lsl     x2, x2, #3                 // Added '#' to immediate value (Change 7)
        bl      memset

end_if_length:

        // index = 0;
        mov     index_reg, #0              // Added '#' to immediate value (Change 7)

    // perform the addition.

    // guarded loop: if index >= sum_length, skip to end_if_carry
    // if (index >= sum_length) goto end_if_carry;
        cmp     index_reg, sum_length_reg
        b.ge    end_if_carry               // Changed 'bge' to 'b.ge' (Change 13)
sum_loop:
        // sum->aulDigits[index] = addend1->aulDigits[index] + addend2->aulDigits[index]
        add     x0, addend1_reg, DIGITS_OFFSET
        ldr     x0, [x0, index_reg, lsl #3]
        add     x1, addend2_reg, DIGITS_OFFSET
        ldr     x1, [x1, index_reg, lsl #3]
        // add with carry
        adcs    x1, x0, x1
        // store result in sum
        add     x0, sum_reg, DIGITS_OFFSET
        str     x1, [x0, index_reg, lsl #3]

        // index++;
        add     index_reg, index_reg, #1   // Added '#' to immediate value (Change 7)

        // compare index and sum_length without affecting flags
        // if (index < sum_length) goto sum_loop;
        sub     x0, sum_length_reg, index_reg
        cbnz    x0, sum_loop

end_sum_loop:
        // check for a carry out of the last addition.

        // if carry flag is clear, skip to end_if_carry;
        b.cc    end_if_carry               // Changed 'bcc' to 'b.cc' (Change 13)

        // if (sum_length != MAXIMUM_DIGITS) goto end_if_max;
        cmp     sum_length_reg, MAXIMUM_DIGITS
        b.ne    end_if_max                 // Changed 'bne' to 'b.ne' (Change 13)

        // return FALSE_VALUE due to overflow
        mov     w0, #FALSE_VALUE           // Added '#' to immediate value (Change 7)
        // epilogue: restore registers and stack pointer
        RESTORE_REGISTERS                  // Using macro to restore registers (Change 12)
        add     sp, sp, STACK_BYTECOUNT
        ret

end_if_max:
        // sum->aulDigits[sum_length] = 1;
        add     x0, sum_reg, DIGITS_OFFSET
        mov     x2, #1                     // Added '#' to immediate value (Change 7)
        str     x2, [x0, sum_length_reg, lsl #3]

        // sum_length++;
        add     sum_length_reg, sum_length_reg, #1  // Added '#' to immediate value (Change 7)

end_if_carry:
        // set the length of the sum.
        // sum->lLength = sum_length;
        str     sum_length_reg, [sum_reg]

        // epilogue: restore registers and return TRUE_VALUE
        mov     w0, #TRUE_VALUE            // Added '#' to immediate value (Change 7)
        RESTORE_REGISTERS                  // Using macro to restore registers (Change 12)
        add     sp, sp, STACK_BYTECOUNT
        ret
.size   BigInt_add, (. -BigInt_add)