include \masm32\include\masm32rt.inc

.data
    result REAL8 ?
    name1 db "Result is: ", 0

.code
    start:
    
        mov eax,a2r8(input("Enter First Number: "))
        fld REAL8 ptr[eax]
        
        mov eax,a2r8(input("Enter Second Number: "))
        fld REAL8 ptr[eax]
        
        fadd
        
        push offset name1
        call StdOut
        
        fstp result
        inKey real8$(result)
        
    end start