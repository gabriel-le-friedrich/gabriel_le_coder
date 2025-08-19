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
    continue_prompt db "Do you want to perform another calculation? (Y/N): ", 0
    exit_prompt db "Press Enter to exit...", 0
    invalid_op_msg db "Invalid operation. Please try again.", 0
    invalid_choice_msg db "Invalid choice. Please enter Y or N.", 0

.data?
    num1 dd ?
    num2 dd ?
    result dd ?
    operation db ?
    buffer db 100 dup(?)

.code
start:
calculation_loop:
    ; Get first number
    invoke StdOut, addr prompt1
    invoke StdIn, addr buffer, sizeof buffer
    invoke atodw, addr buffer
    mov num1, eax

    ; Get second number
    invoke StdOut, addr prompt2
    invoke StdIn, addr buffer, sizeof buffer
    invoke atodw, addr buffer
    mov num2, eax

get_operation:
    ; Get operation
    invoke StdOut, addr prompt3
    invoke StdIn, addr buffer, sizeof buffer
    mov al, [buffer]
    mov [operation], al

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
    invoke StdOut, addr result_msg
    invoke dwtoa, result, addr buffer
    invoke StdOut, addr buffer
    invoke StdOut, addr newline

ask_continue:
    ; Ask if the user wants to continue
    invoke StdOut, addr continue_prompt
    invoke StdIn, addr buffer, sizeof buffer
    
    mov al, [buffer]
    cmp al, 'Y'
    je calculation_loop
    cmp al, 'y'
    je calculation_loop
    cmp al, 'N'
    je exit_program
    cmp al, 'n'
    je exit_program
    
    ; Invalid choice
    invoke StdOut, addr invalid_choice_msg
    invoke StdOut, addr newline
    jmp ask_continue

exit_program:
    ; Wait for user input before exiting
    invoke StdOut, addr exit_prompt
    invoke StdIn, addr buffer, sizeof buffer

    invoke ExitProcess, 0
end start