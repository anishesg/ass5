//----------------------------------------------------------------------
# // bigintadd.s
# // Author: anish k
# //----------------------------------------------------------------------

# // Enumerated constants to avoid magic numbers
        .equ    FALSE, 0
        .equ    TRUE, 1
        .equ    MAX_DIGITS, 32768

# // Structure field offsets for BigInt_T
        .equ    LLENGTH, 0          # Offset of lLength in BigInt_T
        .equ    AULDIGITS, 8        # Offset of aulDigits in BigInt_T

# // Stack byte counts (must be multiples of 16 for alignment)
        .equ    LARGER_STACK_SIZE, 32
        .equ    ADD_STACK_SIZE, 64

# // Local variable stack offsets for BigInt_larger
        .equ    LLARGER, 8
        .equ    LLENGTH1, 16
        .equ    LLENGTH2, 24

# // Local variable stack offsets for BigInt_add
        .equ    LSUMLENGTH, 8
        .equ    LINDEX, 16
        .equ    ULSUM, 24
        .equ    ULCARRY, 32

# // Parameter stack offsets for BigInt_add
        .equ    OSUM, 40
        .equ    OADDEND2, 48
        .equ    OADDEND1, 56

        .global BigInt_larger
        .global BigInt_add

        .section .text

# //--------------------------------------------------------------
# // Return the larger of lLength1 and lLength2.
# // long BigInt_larger(long lLength1, long lLength2)
# //--------------------------------------------------------------

BigInt_larger:

        # // Prologue: set up stack frame
        sub     sp, sp, LARGER_STACK_SIZE      # Allocate stack space
        str     x30, [sp]                       # Save link register (LR)
        str     x0, [sp, LLENGTH1]              # Store first parameter (lLength1)
        str     x1, [sp, LLENGTH2]              # Store second parameter (lLength2)

        # // Load lLength1 and lLength2 from stack
        ldr     x0, [sp, LLENGTH1]              # Load lLength1 into x0
        ldr     x1, [sp, LLENGTH2]              # Load lLength2 into x1

        # // Compare lLength1 and lLength2
        cmp     x0, x1                          # Compare lLength1 with lLength2
        ble     select_length2                   # If lLength1 <= lLength2, branch to select_length2

        # // lLarger = lLength1
        str     x0, [sp, LLARGER]                # Store lLength1 as lLarger
        b       finish_larger                    # Branch to finish_larger

select_length2:
        # // lLarger = lLength2
        str     x1, [sp, LLARGER]                # Store lLength2 as lLarger

finish_larger:
        # // Load lLarger into return register
        ldr     x0, [sp, LLARGER]                # Load lLarger into x0 for return

        # // Epilogue: restore stack frame and return
        ldr     x30, [sp]                        # Restore link register
        add     sp, sp, LARGER_STACK_SIZE        # Deallocate stack space
        ret                                      # Return to caller

        .size   BigInt_larger, .-BigInt_larger

# //--------------------------------------------------------------
# // Assign the sum of oAddend1 and oAddend2 to oSum.
# // oSum should be distinct from oAddend1 and oAddend2.
# // Return 0 (FALSE) if an overflow occurred, and 1 (TRUE) otherwise.
# // int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
# //--------------------------------------------------------------

BigInt_add:

        # // Prologue: set up stack frame
        sub     sp, sp, ADD_STACK_SIZE           # Allocate stack space
        str     x30, [sp]                         # Save link register (LR)
        str     x0, [sp, OADDEND1]                # Store first parameter (oAddend1)
        str     x1, [sp, OADDEND2]                # Store second parameter (oAddend2)
        str     x2, [sp, OSUM]                    # Store third parameter (oSum)

        # // Determine the larger length: lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength)
        ldr     x0, [sp, OADDEND1]                 # Load oAddend1 pointer into x0
        ldr     x0, [x0, LLENGTH]                  # Load oAddend1->lLength into x0
        ldr     x1, [sp, OADDEND2]                 # Load oAddend2 pointer into x1
        ldr     x1, [x1, LLENGTH]                  # Load oAddend2->lLength into x1
        bl      BigInt_larger                      # Call BigInt_larger
        str     x0, [sp, LSUMLENGTH]               # Store lSumLength

        # // Check if oSum->lLength <= lSumLength; if so, skip memset
        ldr     x0, [sp, OSUM]                     # Load oSum pointer into x0
        ldr     x0, [x0, LLENGTH]                  # Load oSum->lLength into x0
        ldr     x1, [sp, LSUMLENGTH]               # Load lSumLength into x1
        cmp     x0, x1                             # Compare oSum->lLength with lSumLength
        ble     skip_memset                        # If oSum->lLength <= lSumLength, skip memset

        # // Perform memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long))
        ldr     x0, [sp, OSUM]                     # Load oSum pointer into x0
        add     x0, x0, AULDIGITS                  # Point to oSum->aulDigits
        mov     w1, 0                              # Set value to 0
        mov     x2, MAX_DIGITS                     # Load MAX_DIGITS
        lsl     x2, x2, #3                         # Calculate MAX_DIGITS * 8 (size of unsigned long)
        bl      memset                             # Call memset to zero out aulDigits

skip_memset:
        # // Initialize ulCarry to 0
        mov     x0, 0
        str     x0, [sp, ULCARRY]                  # ulCarry = 0

        # // Initialize lIndex to 0
        mov     x0, 0
        str     x0, [sp, LINDEX]                   # lIndex = 0

loop_start:
        # // Check if lIndex >= lSumLength; if so, exit loop
        ldr     x0, [sp, LINDEX]                    # Load lIndex
        ldr     x1, [sp, LSUMLENGTH]                # Load lSumLength
        cmp     x0, x1                               # Compare lIndex with lSumLength
        bge     loop_end                             # If lIndex >= lSumLength, exit loop

        # // ulSum = ulCarry
        ldr     x0, [sp, ULCARRY]                   # Load ulCarry
        str     x0, [sp, ULSUM]                     # Store ulSum = ulCarry

        # // ulCarry = 0
        mov     x0, 0
        str     x0, [sp, ULCARRY]                   # Reset ulCarry to 0

        # // ulSum += oAddend1->aulDigits[lIndex]
        ldr     x1, [sp, OADDEND1]                   # Load oAddend1 pointer
        add     x1, x1, AULDIGITS                    # Point to oAddend1->aulDigits
        ldr     x2, [sp, LINDEX]                     # Load lIndex
        lsl     x2, x2, #3                           # Multiply lIndex by 8 (size of unsigned long)
        add     x1, x1, x2                           # Calculate address of oAddend1->aulDigits[lIndex]
        ldr     x3, [x1]                              # Load oAddend1->aulDigits[lIndex]
        ldr     x0, [sp, ULSUM]                       # Load ulSum
        add     x0, x0, x3                            # ulSum += oAddend1->aulDigits[lIndex]
        str     x0, [sp, ULSUM]                       # Store updated ulSum

        # // Check for overflow: if (ulSum < oAddend1->aulDigits[lIndex]) ulCarry = 1
        cmp     x0, x3                               # Compare ulSum with oAddend1->aulDigits[lIndex]
        bhs     no_overflow1                         # If ulSum >= oAddend1->aulDigits[lIndex], no carry
        mov     x4, 1                                # Set ulCarry = 1
        str     x4, [sp, ULCARRY]                    # Store ulCarry

no_overflow1:
        # // ulSum += oAddend2->aulDigits[lIndex]
        ldr     x1, [sp, OADDEND2]                   # Load oAddend2 pointer
        add     x1, x1, AULDIGITS                    # Point to oAddend2->aulDigits
        ldr     x2, [sp, LINDEX]                     # Load lIndex
        lsl     x2, x2, #3                           # Multiply lIndex by 8
        add     x1, x1, x2                           # Calculate address of oAddend2->aulDigits[lIndex]
        ldr     x3, [x1]                              # Load oAddend2->aulDigits[lIndex]
        ldr     x0, [sp, ULSUM]                       # Load ulSum
        add     x0, x0, x3                            # ulSum += oAddend2->aulDigits[lIndex]
        str     x0, [sp, ULSUM]                       # Store updated ulSum

        # // Check for overflow: if (ulSum < oAddend2->aulDigits[lIndex]) ulCarry = 1
        cmp     x0, x3                               # Compare ulSum with oAddend2->aulDigits[lIndex]
        bhs     no_overflow2                         # If ulSum >= oAddend2->aulDigits[lIndex], no carry
        mov     x4, 1                                # Set ulCarry = 1
        str     x4, [sp, ULCARRY]                    # Store ulCarry

no_overflow2:
        # // oSum->aulDigits[lIndex] = ulSum
        ldr     x1, [sp, OSUM]                        # Load oSum pointer
        add     x1, x1, AULDIGITS                     # Point to oSum->aulDigits
        ldr     x2, [sp, LINDEX]                      # Load lIndex
        lsl     x2, x2, #3                            # Multiply lIndex by 8
        add     x1, x1, x2                            # Calculate address of oSum->aulDigits[lIndex]
        ldr     x0, [sp, ULSUM]                        # Load ulSum
        str     x0, [x1]                               # Store ulSum into oSum->aulDigits[lIndex]

        # // Increment lIndex
        ldr     x0, [sp, LINDEX]                       # Load lIndex
        add     x0, x0, 1                              # lIndex++
        str     x0, [sp, LINDEX]                       # Store updated lIndex

        # // Repeat the loop
        b       loop_start                             # Branch back to loop_start

loop_end:
        # // Check if there was a carry out of the last addition
        ldr     x0, [sp, ULCARRY]                      # Load ulCarry
        cmp     x0, 1                                 # Compare ulCarry with 1
        bne     skip_carry_out                         # If ulCarry != 1, skip carry out handling

        # // Check if lSumLength == MAX_DIGITS
        ldr     x1, [sp, LSUMLENGTH]                   # Load lSumLength
        cmp     x1, MAX_DIGITS                         # Compare lSumLength with MAX_DIGITS
        beq     return_false                            # If equal, overflow occurred

        # // oSum->aulDigits[lSumLength] = 1
        ldr     x0, [sp, OSUM]                          # Load oSum pointer
        add     x0, x0, AULDIGITS                       # Point to oSum->aulDigits
        ldr     x2, [sp, LSUMLENGTH]                    # Load lSumLength
        lsl     x2, x2, #3                               # Multiply lSumLength by 8
        add     x0, x0, x2                               # Calculate address of oSum->aulDigits[lSumLength]
        mov     x1, 1                                    # Set value to 1
        str     x1, [x0]                                 # Store 1 into oSum->aulDigits[lSumLength]

        # // Increment lSumLength
        ldr     x0, [sp, LSUMLENGTH]                    # Load lSumLength
        add     x0, x0, 1                               # lSumLength++
        str     x0, [sp, LSUMLENGTH]                    # Store updated lSumLength

skip_carry_out:
        # // Set the length of the sum: oSum->lLength = lSumLength
        ldr     x0, [sp, LSUMLENGTH]                    # Load lSumLength
        ldr     x1, [sp, OSUM]                          # Load oSum pointer
        str     x0, [x1, LLENGTH]                       # Set oSum->lLength = lSumLength

        # // Epilogue: restore stack frame and return TRUE
        mov     w0, TRUE                                 # Set return value to TRUE
        ldr     x30, [sp]                                # Restore link register
        add     sp, sp, ADD_STACK_SIZE                   # Deallocate stack space
        ret                                            # Return to caller

return_false:
        # // Epilogue: restore stack frame and return FALSE due to overflow
        mov     w0, FALSE                                # Set return value to FALSE
        ldr     x30, [sp]                                # Restore link register
        add     sp, sp, ADD_STACK_SIZE                   # Deallocate stack space
        ret                                            # Return to caller

        .size   BigInt_add, .-BigInt_add