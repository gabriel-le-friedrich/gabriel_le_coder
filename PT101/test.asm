include \masm32\include\masm32rt.inc

.data
    hello db "Hello World!", 0Dh, 0Ah, 0

.code
    start:
        push offset hello
        call StdOut
    end start