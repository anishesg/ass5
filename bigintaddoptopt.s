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
        str     x19, [sp, 8]       // Change 1: rearranged saving order
        str     x20, [sp, 16]
        str     x21, [sp, 24]
        str     x22, [sp, 32]
        str     x23, [sp, 40]
        str     x30, [sp]           // Change 1: saved x30 last
        
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
        ble     handle_less          // Change 3: renamed label else_less to handle_less
        mov     lsumlen, x0          // sumlen = length of oaddend1
        b       finish_comparison    // Change 3: renamed label end_larger to finish_comparison
handle_less:
        mov     lsumlen, x1          // sumlen = length of oaddend2
finish_comparison:
        
        // clear osum array if needed
        ldr     x0, [osum]
        cmp     x0, lsumlen
        ble     end_clear
        
        // clear memory (memset)
        add     x0, osum, digits_offset
        mov     w1, 0
        mov     x2, max_digits
        lsl     x2, x2, 3            // max_digits * 8
        bl      memset
        
end_clear:
        
        // guarded loop check before initializing lindex
        cmp     lindex, lsumlen
        bge     end_add              // skip if index >= sumlen
        
        // initialize index
        mov     lindex, 0
        
loop_add:
        // Change 6: introduce temp_reg by using x0 as temp_reg
        mov     x0, oaddend1         // Move oaddend1 to x0
        add     x0, x0, digits_offset // Add digits_offset to x0
        ldr     x0, [x0, lindex, lsl 3] // Load oaddend1->aulDigits[lindex] into x0
        
        add     x1, oaddend2, digits_offset // Calculate address of oaddend2->aulDigits[lindex]
        ldr     x1, [x1, lindex, lsl 3]      // Load oaddend2->aulDigits[lindex] into x1
        adcs    x1, x0, x1           // Add with carry: x1 = x0 + x1 + carry
        add     x0, osum, digits_offset // Calculate address of osum->aulDigits[lindex]
        str     x1, [x0, lindex, lsl 3] // Store the sum into osum->aulDigits[lindex]
        
        add     lindex, lindex, 1    // lindex++
        sub     x0, lsumlen, lindex  // x0 = lsumlen - lindex
        cbnz    x0, loop_add         // continue if index < sumlen
        
end_add:
        // check for carry first
        bcc     end_carry            // skip if no carry
        
        // now check for overflow
        cmp     lsumlen, max_digits
        bne     end_max
        
        // return false if overflow
        mov     w0, false
        b       cleanup
        
end_max:
        add     x0, osum, digits_offset // Calculate address of osum->aulDigits[lsumlen]
        mov     x2, 1
        str     x2, [x0, lsumlen, lsl 3] // Set osum->aulDigits[lsumlen] = 1
        add     lsumlen, lsumlen, 1     // lsumlen++
        
end_carry:
        str     lsumlen, [osum]      // set osum->lLength = lsumlen
        
        // return true
        mov     w0, true
        
cleanup:
        // epilogue: restore stack in reverse order
        ldr     x23, [sp, 40]
        ldr     x22, [sp, 32]
        ldr     x21, [sp, 24]
        ldr     x20, [sp, 16]
        ldr     x19, [sp, 8]
        ldr     x30, [sp]           // Change 1: restored x30 last
        add     sp, sp, add_stack_bytes
        ret
.size   BigInt_add, (. - BigInt_add)