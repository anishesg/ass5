// enums for clarity
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
        // add two big integers (oaddend1 and oaddend2), store in osum
        // return false (0) if overflow, true (1) otherwise
        //--------------------------------------------------------------
    
        // stack space for locals (multiple of 16 for alignment)
        .equ    add_stack_bytes, 48
    
        // local vars in registers
        lsumlen      .req x23
        lindex       .req x22
    
        // params in registers
        osum         .req x21
        oaddend2     .req x20
        oaddend1     .req x19
    
        // offsets in the structure
        .equ    digits_offset,  8
        
        .global BigInt_add
    
BigInt_add:

        // prologue: save stack space and registers
        sub     sp, sp, add_stack_bytes
        str     x30, [sp]
        str     x19, [sp, 8]
        str     x20, [sp, 16]
        str     x21, [sp, 24]
        str     x22, [sp, 32]
        str     x23, [sp, 40]

        // move params to registers
        mov     oaddend1, x0
        mov     oaddend2, x1
        mov     osum, x2

        // local vars
        // unsigned long sum; long index, sumlen;

        // figure out the bigger length
        // inline BigInt_larger
        ldr     x0, [oaddend1]       // length of oaddend1
        ldr     x1, [oaddend2]       // length of oaddend2
        cmp     x0, x1
        bgt     else_less            // if oaddend1 > oaddend2 (Adjustment 1)
        mov     lsumlen, x0          // sumlen = length of oaddend1
        b       end_larger
else_less:
        mov     lsumlen, x1          // sumlen = length of oaddend2
end_larger:

        // clear osum array if needed
        ldr     x0, [osum]
        cmp     x0, lsumlen
        ble     end_clear

        // clear memory (memset)
        add     x0, osum, #digits_offset
        mov     w1, 0
        mov     x2, max_digits
        lsl     x2, x2, 3            // max_digits * 8
        bl      memset

end_clear:

        // initialize index (Adjustment 8)
        mov     lindex, xzr

        // guarded loop for addition
        cmp     lindex, lsumlen
        bge     end_add              // skip if index >= sumlen
loop_add:
        // Calculate address for oaddend1->aulDigits[lindex]
        add     x0, oaddend1, #digits_offset
        ldr     x0, [x0, x22, LSL #3]   // ldr x0, [oaddend1 + digits_offset + (lindex << 3)]

        // Calculate address for oaddend2->aulDigits[lindex]
        add     x1, oaddend2, #digits_offset
        ldr     x1, [x1, x22, LSL #3]   // ldr x1, [oaddend2 + digits_offset + (lindex << 3)]

        // Add with carry
        adcs    x1, x0, x1               // x1 = x0 + x1 + carry

        // Store result in osum->aulDigits[lindex]
        add     x0, osum, #digits_offset
        str     x1, [x0, x22, LSL #3]   // str x1, [osum + digits_offset + (lindex << 3)]

        // lindex++
        add     lindex, lindex, #1

        // Perform compare without triggering C flag (Adjustment 3)
        cmp     lindex, lsumlen
        blt     loop_add         // continue if index < sumlen

end_add:
        // check for carry out
        bcc     end_carry            // skip if no carry

        // Compare sumlen with max_digits (Adjustment 10)
        cmp     lsumlen, max_digits
        bne     end_max

        // Redundant comparison added for Adjustment 10
        cmp     lsumlen, max_digits
        bgt     end_max

        // return false if overflow
        mov     w0, false
        b       cleanup

end_max:
        // Set osum->aulDigits[lsumlen] = 1
        add     x0, osum, #digits_offset
        mov     x2, 1
        str     x2, [x0, lsumlen, LSL #3]   // str x2, [osum + digits_offset + (lsumlen << 3)]

        // lsumlen++
        add     lsumlen, lsumlen, #1

end_carry:
        // Set the length of the sum.
        str     lsumlen, [osum]

        // return true
        mov     w0, true

cleanup:
        // epilogue: restore stack and registers
        ldr     x30, [sp]
        ldr     x19, [sp, 8]
        ldr     x20, [sp, 16]
        ldr     x21, [sp, 24]
        ldr     x22, [sp, 32]
        ldr     x23, [sp, 40]
        add     sp, sp, add_stack_bytes
        ret
.size   BigInt_add, (. - BigInt_add)