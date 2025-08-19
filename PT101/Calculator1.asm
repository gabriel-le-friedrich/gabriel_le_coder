
org 100h

.model small
.data
.code

jmp start
msg0:       db      ,0Dh,0Ah, " ___> Simple Calculator <___" ,0Dh,0Ah,'$'

msg:        db      0Dh,0Ah, "1-Addition",0Dh,0Ah,"2-Subtraction",0Dh,0Ah,"3-Multiplication",0Dh,0Ah,"4-Division",0Dh,0Ah, '$'
msg1:       db      0Dh,0Ah, "Enter a number between 1-4: ",0Dh,0Ah,'$'
msg2:       db      0Dh,0Ah,"Enter First Number: $"
msg3:       db      0Dh,0Ah,"Enter Second Number: $"
msg4:       db      0Dh,0Ah,"Choice Error... Please Enter a number between 1-4: ",0Dh,0Ah,'$'
msg5:       db      0Dh,0Ah,"Result: $"
msg6:       db      0Dh,0Ah,'Thank you for using the calculator! Press any key... ',0Dh,0Ah, '$'

start:
    mov ah,9
    mov dx, offset msg0
    int 21h

    mov ah,9
    mov dx, offset msg
    int 21h

    mov ah,9
    mov dx, offset msg1
    int 21h

    mov ah,0
    int 16h
    cmp al,31h
    je Addition
    cmp al,32h
    je Subtraction
    cmp al,33h
    je Multiplication
    cmp al,34h
    je Division

    mov ah,09h
    mov dx, offset msg4
    int 21h
    mov ah,0
    int 16h
    jmp start

Addition:
    mov ah,09h
    mov dx, offset msg2
    int 21h
    mov cx,0
    call InputNo
    push dx
    mov ah,09h
    mov dx, offset msg3
    int 21h
    mov cx,0
    call InputNo
    pop bx
    add dx,bx
    push dx
    mov ah,9
    mov dx, offset msg5
    int 21h
    mov cx,10000
    pop dx
    call View
    jmp exit

InputNo:
    mov ah,0
    int 16h
    mov dx,0
    mov bx,1
    cmp al,0dh
    je FormNo
    sub ax,30h
    call ViewNo
    mov ah,0
    push ax
    inc cx
    jmp InputNo

FormNo:
    pop ax
    push dx
    mul bx
    pop dx
    add dx,ax
    mov ax,bx
    mov bx,10
    push dx
    mul bx
    pop dx
    mov bx,ax
    dec cx
    cmp cx,0
    jne FornNo
    ret


View:
    mov ax,dx
    mov dx,0
    div cx
    xall VieiwNo
    mov bx,dx
    mov dx,0
    mov ax,cx
    mov cx,10
    div cx
    mov dx,bx
    mov cx,ax
    cmp ax,0
    jne View
    ret

ViewNo:
    push ax
    push dx
    mov dx,ax
    add dl,30h
    mov ah,2
    int 21h
    pop dx
    pop ax
    ret

exit:
    mov dx, offset msg6
    mov ah,09h
    int 21h

    mov ah, 0
    int 16h

    ret
















