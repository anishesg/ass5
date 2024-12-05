// making some constants
        .equ    false, 0
        .equ    true, 1
        .equ    eof, -1
        .equ    max_digits, 32768
//----------------------------------------------------------------------
        
        .section .rodata

//----------------------------------------------------------------------

        .section .data

//----------------------------------------------------------------------

        .section .bss

//----------------------------------------------------------------------

        .section .text
        
        //--------------------------------------------------------------
        // Add addend1 and addend2, store the result in sum.
        // Sum should be different from addend1 and addend2.
        // Return 0 (false) if an overflow occurred,
        // and 1 (true) otherwise.
        // int BigInt_add(BigInt_T addend1, BigInt_T addend2, BigInt_T sum)
        //--------------------------------------------------------------

        // Must be a multiple of 16
        .equ    stack_bytecount, 48

        // Local variable registers
        sum_length      .req x23
        index           .req x22

        // Parameter registers
        sum_reg         .req x21
        addend2_reg     .req x20
        addend1_reg     .req x19

        // Structure field offsets
        .equ    digits_offset, 8
        
        .global BigInt_add

BigInt_add:

        // Prologue: save registers on the stack
        sub     sp, sp, stack_bytecount
        str     x30, [sp]
        str     x19, [sp, 8]
        str     x20, [sp, 16]
        str     x21, [sp, 24]
        str     x22, [sp, 32]
        str     x23, [sp, 40]

        // Move parameters into our registers
        mov     addend1_reg, x0
        mov     addend2_reg, x1
        mov     sum_reg, x2

        // Determine the larger length (inlined BigInt_larger)
        ldr     x0, [addend1_reg]
        ldr     x1, [addend2_reg]
        cmp     x0, x1
        ble     else_if_less
        // sum_length = addend1->lLength;
        mov     sum_length, x0
        b       end_if_greater
else_if_less:
        // sum_length = addend2->lLength;
        mov     sum_length, x1
end_if_greater:
        // Clear sum's array if necessary

        // if (sum->lLength <= sum_length) goto end_if_length;
        ldr     x0, [sum_reg]
        cmp     x0, sum_length
        ble     end_if_length

        // memset(sum->digits, 0, max_digits * sizeof(unsigned long));
        add     x0, sum_reg, digits_offset
        mov     w1, 0
        mov     x2, max_digits
        lsl     x2, x2, 3      // x2 = max_digits * 8
        bl      memset
    
end_if_length:

        // index = 0;
        mov     index, 0
        
// Perform the addition.

sum_loop:
        // Guarded loop: if index >= sum_length, exit loop
        cmp     index, sum_length
        bge     end_if_carry

        // sum->digits[index] = addend1->digits[index] + addend2->digits[index] + carry
        add     x0, addend1_reg, digits_offset
        ldr     x0, [x0, index, lsl #3]
        add     x1, addend2_reg, digits_offset
        ldr     x1, [x1, index, lsl #3]
        // Add with carry
        adcs    x1, x0, x1
        // Store result in sum
        add     x0, sum_reg, digits_offset
        str     x1, [x0, index, lsl #3]
        
        // index++;
        add     index, index, 1

        // Loop back to continue addition
        b       sum_loop

end_if_carry:
        // Check for a carry out of the last addition

        // If no carry occurred, skip to setting sum length
        bcc     end_sum

        // If sum_length == max_digits, overflow occurred
        cmp     sum_length, max_digits
        bne     not_max

        // Return false due to overflow
        mov     w0, false
        // Epilogue: restore registers and return
        ldr     x30, [sp]
        ldr     x19, [sp, 8]
        ldr     x20, [sp, 16]
        ldr     x21, [sp, 24]
        ldr     x22, [sp, 32]
        ldr     x23, [sp, 40]
        add     sp, sp, stack_bytecount
        ret

not_max:
        // sum->digits[sum_length] = 1;
        add     x0, sum_reg, digits_offset
        mov     x2, 1
        str     x2, [x0, sum_length, lsl #3]

        // sum_length++;
        add     sum_length, sum_length, 1

end_sum:
        // Set the length of the sum
        str     sum_length, [sum_reg]

        // Epilogue: restore registers and return true
        mov     w0, true
        ldr     x30, [sp]
        ldr     x19, [sp, 8]
        ldr     x20, [sp, 16]
        ldr     x21, [sp, 24]
        ldr     x22, [sp, 32]
        ldr     x23, [sp, 40]
        add     sp, sp, stack_bytecount
        ret
.size   BigInt_add, (. - BigInt_add)