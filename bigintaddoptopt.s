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
        .equ    add_stack_bytes, 48

        lsumlen      .req x23
        lindex       .req x22

        osum         .req x21
        oaddend2     .req x20
        oaddend1     .req x19

        .equ    digits_offset,  8
        
        .global BigInt_add

BigInt_add:

        sub     sp, sp, add_stack_bytes
        str     x30, [sp]
        str     x19, [sp, 8]
        str     x20, [sp, 16]
        str     x21, [sp, 24]
        str     x22, [sp, 32]
        str     x23, [sp, 40]

        mov     oaddend1, x0
        mov     oaddend2, x1
        mov     osum, x2

        ldr     x0, [oaddend1]
        ldr     x1, [oaddend2]
        cmp     x0, x1
        bgt     else_less
        mov     lsumlen, x0
        b       end_larger
else_less:
        mov     lsumlen, x1
end_larger:

        ldr     x0, [osum]
        cmp     x0, lsumlen
        ble     end_clear

        add     x0, osum, digits_offset
        movk    x1, #0
        mov     x2, max_digits
        lsl     x2, x2, 3
        bl      memset

end_clear:

        mov     lindex, xzr

        cmp     lindex, lsumlen
        bge     end_add
loop_add:
        ldr     x0, [oaddend1, digits_offset, lsl 0]
        ldr     x1, [oaddend2, digits_offset, lsl 0]
        adcs    x1, x0, x1
        add     x0, osum, digits_offset
        str     x1, [x0, lindex, lsl 3]

        add     lindex, lindex, 1
        cmp     lindex, lsumlen
        blt     loop_add

end_add:
        bcc     end_carry

        cmp     lsumlen, max_digits
        bgt     end_max_check

        mov     w0, false
        b       cleanup

end_max_check:
        add     x0, osum, digits_offset
        mov     x2, 1
        str     x2, [x0, lsumlen, lsl 3]
        add     lsumlen, lsumlen, 1

end_carry:
        str     lsumlen, [osum]

        mov     w0, true

cleanup:
        add     sp, sp, add_stack_bytes
        ldr     x30, [sp]
        ldr     x19, [sp, 8]
        ldr     x20, [sp, 16]
        ldr     x21, [sp, 24]
        ldr     x22, [sp, 32]
        ldr     x23, [sp, 40]
        ret
.size   BigInt_add, (. -BigInt_add)