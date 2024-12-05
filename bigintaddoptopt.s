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
        str     x19, [sp, 8]
        str     x20, [sp, 16]
        str     x21, [sp, 24]
        str     x22, [sp, 32]
        str     x23, [sp, 40]
        str     x30, [sp]
        
        // move params to registers (reordered)
        mov     osum, x2
        mov     oaddend1, x0
        mov     oaddend2, x1
        
        // local vars
        // unsigned long sum; long index, sumlen;
        
        // figure out the bigger length
        // inline BigInt_larger
        ldr     x0, [oaddend1]           // length of oaddend1
        ldr     x1, [oaddend2]           // length of oaddend2
        cmp     x0, x1
        ble     handle_less              // if oaddend1 <= oaddend2
        mov     lsumlen, x0             // sumlen = length of oaddend1
        b.ne    finish_comparison        // branch if not equal
handle_less:
        mov     lsumlen, x1             // sumlen = length of oaddend2
finish_comparison:
        
        // clear osum array if needed
        ldr     x0, [osum]
        cmp     x0, lsumlen
        ble     end_clear
        
        // clear memory (memset)
        add     x0, osum, digits_offset
        movz    w1, #0                  // changed from mov w1, 0
        movz    x2, #0x8000             // changed from mov x2, max_digits
        lsl     x2, x2, 3               // max_digits * 8
        bl      memset
        
end_clear:
        
        // guarded loop check before initializing lindex
        cmp     lindex, lsumlen
        bge     end_add                  // skip if index >= sumlen
        
        // initialize index
        movz    lindex, #0               // changed from mov lindex, 0
        
loop_add:
        // Corrected addressing: include digits_offset
        add     x0, oaddend1, digits_offset
        ldr     x0, [x0, lindex, lsl #3] // Access oaddend1->aulDigits[lindex]
        add     x1, oaddend2, digits_offset
        ldr     x1, [x1, lindex, lsl #3] // Access oaddend2->aulDigits[lindex]
        adcs    x1, x0, x1               // add with carry
        add     x0, osum, digits_offset
        str     x1, [x0, lindex, lsl #3] // Store sum in osum->aulDigits[lindex]
        
        add     lindex, lindex, 1
        sub     x0, lsumlen, lindex
        cbnz    x0, loop_add             // continue if index < sumlen
        
end_add:
        // check for carry first
        bcc     end_carry                // skip if no carry
        
        // now check for overflow
        cmp     lsumlen, max_digits
        bne     handle_no_overflow        // changed from bne end_max
        
        // return false if overflow
        mov     w0, false
        b       cleanup
        
handle_no_overflow:
        add     x0, osum, digits_offset
        movz    x2, #1                   // changed from mov x2, 1
        str     x2, [x0, lsumlen, lsl #3]// Store 1 in osum->aulDigits[lsumlen]
        add     lsumlen, lsumlen, 1
        
end_carry:
        str     lsumlen, [osum]          // set length in osum
        
        // return true
        mov     w0, true
        
cleanup:
        // epilogue: restore stack in reverse order
        ldr     x23, [sp, 40]
        ldr     x22, [sp, 32]
        ldr     x21, [sp, 24]
        ldr     x20, [sp, 16]
        ldr     x19, [sp, 8]
        ldr     x30, [sp]
        add     sp, sp, add_stack_bytes
        ret
.size   BigInt_add, (. - BigInt_add)