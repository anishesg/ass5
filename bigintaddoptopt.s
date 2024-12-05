
// enums for clarity
    .EQU    FALSE, 0
    .EQU    TRUE, 1
    .EQU    EOF, -1
    .EQU    MAX_DIGITS, 32768
//----------------------------------------------------------------------
        
    .section .rodata

//----------------------------------------------------------------------
        
    .section .data

//----------------------------------------------------------------------
        
    .section .bss

//----------------------------------------------------------------------
        
    .section .text
        
        //--------------------------------------------------------------
        // big_int_add: adds two high-precision integers.
        // parameters:
        //     x0 - pointer to first operand (operand1)
        //     x1 - pointer to second operand (operand2)
        //     x2 - pointer to result operand (result)
        // returns:
        //     FALSE (0) if overflow occurs,
        //     TRUE (1) otherwise.
        //--------------------------------------------------------------

        // stack space for local variables and saved registers (aligned to 16 bytes)
        .EQU    ADD_STACK_BYTES, 48

        // local variables mapped to registers
        lsumlen      .req x23      // sum length
        lindex       .req x22      // current index

        // function parameters mapped to registers
        osum         .req x21      // pointer to result BigInt
        oaddend2     .req x20      // pointer to second operand
        oaddend1     .req x19      // pointer to first operand

        // offsets within the BigInt structure
        .EQU    DIGITS_OFFSET,  8
            
        .global BigInt_add

BigInt_add:

        // prologue: allocate stack space and save caller-saved registers
        sub     sp, sp, ADD_STACK_BYTES
        str     x19, [sp, 8]          // save oaddend1
        str     x20, [sp, 16]         // save oaddend2
        str     x21, [sp, 24]         // save osum
        str     x22, [sp, 32]         // save lindex
        str     x23, [sp, 40]         // save lsumlen
        str     x30, [sp]             // save return address

        // move function arguments to designated registers
        mov     oaddend1, x0           // operand1
        mov     oaddend2, x1           // operand2
        mov     osum, x2               // result

        // determine the larger length between operand1 and operand2
        // equivalent to: if (operand1->length <= operand2->length) handle_less
        ldr     x0, [oaddend1]           // load length of operand1
        ldr     x1, [oaddend2]           // load length of operand2
        cmp     x0, x1
        ble     handle_less               // branch if operand1 <= operand2
        mov     lsumlen, x0              // sumlen = length of operand1
        b       finish_comparison
handle_less:
        mov     lsumlen, x1              // sumlen = length of operand2
finish_comparison:

        // clear the result array if its current length is insufficient
        ldr     x0, [osum]               // load current length of result
        cmp     x0, lsumlen
        ble     end_clear                // branch if current length <= sumlen

        // perform memory zeroing: memset(result->digits, 0, MAX_DIGITS * sizeof(unsigned long))
        add     x0, osum, DIGITS_OFFSET  // calculate address of digits array in result
        mov     w1, 0                    // value to set (zero)
        mov     x2, MAX_DIGITS           // number of digits
        lsl     x2, x2, 3                // convert to byte count (MAX_DIGITS * 8)
        bl      memset                   // call memset to clear digits array

end_clear:

        // initialize loop index
        mov     lindex, 0                // lindex = 0

        // guarded loop condition: if (lindex >= lsumlen) skip addition loop
        cmp     lindex, lsumlen
        bge     end_add                   // branch if index >= sumlen

loop_add:
        // introduce temporary registers for operand1 and operand2 digit access
        mov     x9, oaddend1             // temp register for operand1
        add     x9, x9, DIGITS_OFFSET    // address of operand1 digits
        ldr     x0, [x9, lindex, lsl 3]  // load operand1 digit at lindex

        mov     x10, oaddend2            // temp register for operand2
        add     x10, x10, DIGITS_OFFSET  // address of operand2 digits
        ldr     x1, [x10, lindex, lsl 3] // load operand2 digit at lindex

        adcs    x1, x0, x1               // add with carry: sum = operand1 + operand2 + carry
        add     x0, osum, DIGITS_OFFSET  // address of result digits
        str     x1, [x0, lindex, lsl 3]  // store sum in result digits

        // increment loop index
        add     lindex, lindex, 1         // lindex++

        // update remaining digits to process
        sub     x0, lsumlen, lindex       // remaining = sumlen - lindex
        cbnz    x0, loop_add              // continue loop if remaining digits exist

end_add:
        // check if there is a carry out after the final addition
        bcc     end_carry                 // branch if carry flag is not set

        // check if the sum length has reached maximum capacity
        cmp     lsumlen, MAX_DIGITS
        bne     end_max                   // branch if sumlen != MAX_DIGITS

        // overflow occurred: return FALSE
        mov     w0, FALSE
        b       cleanup

end_max:
        // set the next digit to 1 to account for the carry
        add     x0, osum, DIGITS_OFFSET  // address of result digits
        mov     x2, 1                    // value to set (1)
        str     x2, [x0, lsumlen, lsl 3] // set digit at lsumlen to 1
        add     lsumlen, lsumlen, 1      // increment sumlen

end_carry:
        // update the length of the result BigInt
        str     lsumlen, [osum]          // result->length = lsumlen

        // return TRUE indicating successful addition
        mov     w0, TRUE

cleanup:
        // epilogue: restore stack space and saved registers
        ldr     x30, [sp]                 // restore return address
        ldr     x19, [sp, 8]              // restore oaddend1
        ldr     x20, [sp, 16]             // restore oaddend2
        ldr     x21, [sp, 24]             // restore osum
        ldr     x22, [sp, 32]             // restore lindex
        ldr     x23, [sp, 40]             // restore lsumlen
        add     sp, sp, ADD_STACK_BYTES   // deallocate stack space
        ret
.size   BigInt_add, (. - BigInt_add)