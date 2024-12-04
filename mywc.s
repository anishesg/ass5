//---------------------------------------------------------------------
// mywc.s
// author: anish k
//---------------------------------------------------------------------

        .equ    FALSE, 0
        .equ    TRUE, 1
        .equ    EOF, -1

//---------------------------------------------------------------------
// read-only data section for format strings

        .section .rodata

printfFormatStr:
        .string "%7ld %7ld %7ld\n"

//---------------------------------------------------------------------
// data section for initialized global variables

        .section .data

lLineCount:
        .quad   0       // long lLineCount = 0

lWordCount:
        .quad   0       // long lWordCount = 0

lCharCount:
        .quad   0       // long lCharCount = 0

iInWord:
        .word   FALSE   // int iInWord = FALSE

//---------------------------------------------------------------------
// bss section for uninitialized global variables

        .section .bss

iChar:
        .skip   4       // int iChar

//---------------------------------------------------------------------
// text section for code

        .section .text

        .equ    MAIN_STACK_BYTECOUNT, 16

        .global main

//---------------------------------------------------------------------
// int main(void)
// writes to stdout counts of lines, words, and characters read from stdin.
// returns 0.
//
// parameters:
//     none
//
// return value:
//     0 on successful execution.
//---------------------------------------------------------------------

main:
        // prologue: adjust stack and save return address
        sub     sp, sp, MAIN_STACK_BYTECOUNT
        str     x30, [sp]

        // start of the main loop
loop_start:
        // call getchar to read a character
        bl      getchar
        // store the character in w3 for later use
        mov     w3, w0          // w3 = iChar
        // save iChar to memory
        adr     x1, iChar
        str     w0, [x1]
        // check if iChar == EOF
        cmp     w0, EOF
        beq     loop_end        // if end of file, exit loop

        // increment lCharCount
        adr     x1, lCharCount
        ldr     x2, [x1]
        add     x2, x2, 1
        str     x2, [x1]

        // prepare to call isspace with iChar
        mov     w0, w3          // w0 = iChar
        bl      isspace
        // if isspace(iChar) != 0, character is whitespace
        cbnz    w0, is_space
        // else, character is not whitespace
        b       not_space

is_space:
        // check if we were in a word
        adr     x1, iInWord
        ldr     w2, [x1]
        cbz     w2, check_newline   // if iInWord == FALSE, skip increment

        // increment lWordCount
        adr     x1, lWordCount
        ldr     x2, [x1]
        add     x2, x2, 1
        str     x2, [x1]

        // set iInWord to FALSE
        adr     x1, iInWord    // Re-point x1 to iInWord
        mov     w2, FALSE
        str     w2, [x1]        // x1 now points to iInWord

        // proceed to check for newline
        b       check_newline

not_space:
        // check if we are not already in a word
        adr     x1, iInWord
        ldr     w2, [x1]
        cbnz    w2, check_newline   // if iInWord == TRUE, skip setting

        // set iInWord to TRUE
        mov     w2, TRUE
        str     w2, [x1]        // x1 still points to iInWord

check_newline:
        // check if iChar is a newline character
        cmp     w3, '\n'
        bne     loop_start      // if not newline, continue loop

        // increment lLineCount
        adr     x1, lLineCount
        ldr     x2, [x1]
        add     x2, x2, 1
        str     x2, [x1]

        // loop back to start
        b       loop_start

loop_end:
        // after loop ends, check if we are still in a word
        adr     x1, iInWord
        ldr     w2, [x1]
        cbz     w2, print_counts    // if iInWord == FALSE, skip increment

        // increment lWordCount one last time
        adr     x1, lWordCount
        ldr     x2, [x1]
        add     x2, x2, 1
        str     x2, [x1]

        // set iInWord to FALSE (optional)
        adr     x1, iInWord
        mov     w2, FALSE
        str     w2, [x1]

print_counts:
        // prepare arguments for printf
        adr     x0, printfFormatStr     // x0 = format string
        adr     x1, lLineCount
        ldr     x1, [x1]                // x1 = lLineCount
        adr     x2, lWordCount
        ldr     x2, [x2]                // x2 = lWordCount
        adr     x3, lCharCount
        ldr     x3, [x3]                // x3 = lCharCount

        // call printf to display counts
        bl      printf

        // set return value to 0
        mov     w0, 0

        // epilogue: restore return address and adjust stack
        ldr     x30, [sp]
        add     sp, sp, MAIN_STACK_BYTECOUNT
        ret

        .size   main, . - main
        