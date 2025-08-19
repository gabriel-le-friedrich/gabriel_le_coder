.386
.model flat, stdcall
option casemap :none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\masm32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\masm32.lib

.data
    prompt1 db "Enter first number: ", 0
    prompt2 db "Enter second number: ", 0
    prompt3 db "Enter operation (+, -, *, /): ", 0
    result_msg db "Result: ", 0
    format db "%d", 0
    newline db 13, 10, 0
    exit_prompt db "Press Enter to exit...", 0
    debug_msg1 db "Debug: First number entered: ", 0
    debug_msg2 db "Debug: Second number entered: ", 0
    debug_msg3 db "Debug: Operation entered: ", 0
    debug_msg4 db "Debug: Calculation complete. Result: ", 0
    invalid_op_msg db "Invalid operation. Please try again.", 0

.data?
    num1 dd ?
    num2 dd ?
    result dd ?
    operation db ?
    buffer db 100 dup(?)

.code
start:
    ; Get first number
    invoke StdOut, addr prompt1
    invoke StdIn, addr buffer, sizeof buffer
    invoke atodw, addr buffer
    mov num1, eax
    
    ; Debug output
    invoke StdOut, addr debug_msg1
    invoke dwtoa, num1, addr buffer
    invoke StdOut, addr buffer
    invoke StdOut, addr newline

    ; Get second number
    invoke StdOut, addr prompt2
    invoke StdIn, addr buffer, sizeof buffer
    invoke atodw, addr buffer
    mov num2, eax
    
    ; Debug output
    invoke StdOut, addr debug_msg2
    invoke dwtoa, num2, addr buffer
    invoke StdOut, addr buffer
    invoke StdOut, addr newline

get_operation:
    ; Get operation
    invoke StdOut, addr prompt3
    invoke StdIn, addr buffer, sizeof buffer
    mov al, [buffer]
    mov [operation], al
    
    ; Debug output
    invoke StdOut, addr debug_msg3
    invoke StdOut, addr operation
    invoke StdOut, addr newline

    ; Perform calculation based on operation
    mov al, [operation]
    cmp al, '+'
    je addition
    cmp al, '-'
    je subtraction
    cmp al, '*'
    je multiplication
    cmp al, '/'
    je division
    
    ; Invalid operation
    invoke StdOut, addr invalid_op_msg
    invoke StdOut, addr newline
    jmp get_operation

addition:
    mov eax, num1
    add eax, num2
    mov result, eax
    jmp print_result

subtraction:
    mov eax, num1
    sub eax, num2
    mov result, eax
    jmp print_result

multiplication:
    mov eax, num1
    imul num2
    mov result, eax
    jmp print_result

division:
    mov edx, 0
    mov eax, num1
    idiv num2
    mov result, eax

print_result:
    ; Debug output
    invoke StdOut, addr debug_msg4
    invoke dwtoa, result, addr buffer
    invoke StdOut, addr buffer
    invoke StdOut, addr newline

    invoke StdOut, addr result_msg
    invoke dwtoa, result, addr buffer
    invoke StdOut, addr buffer
    invoke StdOut, addr newline

    ; Wait for user input before exiting
    invoke StdOut, addr exit_prompt
    invoke StdIn, addr buffer, sizeof buffer

    invoke ExitProcess, 0
end start