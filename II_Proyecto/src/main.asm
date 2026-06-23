; ============================================================
; Proyecto 2 - Distancia de Frobenius con AVX
; IC-3101 Arquitectura de Computadores
;
; Calcula la distancia de Frobenius entre dos matrices A y B de 3x3:
;   d(A,B) = ||A - B||_F = sqrt( sum_i sum_j |a_ij - b_ij|^2 )
; donde las matrices serán dadas por el usuario a través de la consola.
;
; Integrantes del proyecto:
; - Julio Quirós Vargas
; - Fabiola González Gómez
; - Angie Alpizar Porras
; - José Gabriel Marín Aguilar
; ============================================================

option casemap:none

PUBLIC main

includelib msvcrt.lib
; En Visual Studio moderno, printf/scanf pueden requerir esta librería auxiliar.
includelib legacy_stdio_definitions.lib

printf PROTO C :PTR BYTE, :VARARG
scanf  PROTO C :PTR BYTE, :VARARG

.data
    tituloA      db 13,10,"Digite los valores de la matriz A (3x3)",13,10,0
    tituloB      db 13,10,"Digite los valores de la matriz B (3x3)",13,10,0
    promptA      db "A[%d][%d] = ",0
    promptB      db "B[%d][%d] = ",0
    fmtScan      db "%lf",0
    tituloDif    db 13,10,"Matriz diferencia A - B:",13,10,0
    fmtFila      db "[ %10.4lf  %10.4lf  %10.4lf ]",13,10,0
    fmtResultado db 13,10,"Distancia de Frobenius: %.6lf",13,10,0

    ; Se usan movimientos no alineados vmovupd, por eso no se exige ALIGN 32.
    ; Cada fila ocupa 4 REAL8 = 32 bytes: 3 valores reales + 1 cero de padding.
    MatrizA   REAL8 12 DUP(0.0)      ; 3 filas x 4 columnas, con padding en la cuarta columna
    MatrizB   REAL8 12 DUP(0.0)
    MatrizD   REAL8 12 DUP(0.0)      ; diferencia con signo: A - B
    MatrizAbs REAL8 12 DUP(0.0)      ; valor absoluto de la diferencia, calculado con vandpd
    TempSums  REAL8 4 DUP(0.0)       ; sumas parciales por lane
    Resultado REAL8 0.0

    AbsMask QWORD 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh

.code
main PROC
    ; Se preservan registros no volátiles usados como contadores/bases.
    push rbx
    push rdi
    push r12
    push r13

    ; Shadow space + alineación para llamadas del ABI Windows x64.
    sub rsp, 40

    ; -------------------------------------------------------------------------
    ; Lectura de matriz A
    ; -------------------------------------------------------------------------
    lea rcx, tituloA
    call printf

    xor r12d, r12d                     ; fila = 0
leerA_fila:
    xor r13d, r13d                     ; columna = 0
leerA_columna:
    lea rcx, promptA
    mov edx, r12d
    inc edx                            ; mostrar índice desde 1
    mov r8d, r13d
    inc r8d
    call printf

    ; offset = (fila * 4 + columna) * 8
    mov rax, r12
    imul rax, 4
    add rax, r13
    imul rax, 8

    lea rcx, fmtScan
    lea rbx, MatrizA
    lea rdx, [rbx + rax]
    call scanf

    inc r13
    cmp r13, 3
    jl leerA_columna

    inc r12
    cmp r12, 3
    jl leerA_fila

    ; -------------------------------------------------------------------------
    ; Lectura de matriz B
    ; -------------------------------------------------------------------------
    lea rcx, tituloB
    call printf

    xor r12d, r12d                     ; fila = 0
leerB_fila:
    xor r13d, r13d                     ; columna = 0
leerB_columna:
    lea rcx, promptB
    mov edx, r12d
    inc edx
    mov r8d, r13d
    inc r8d
    call printf

    ; offset = (fila * 4 + columna) * 8
    mov rax, r12
    imul rax, 4
    add rax, r13
    imul rax, 8

    lea rcx, fmtScan
    lea rbx, MatrizB
    lea rdx, [rbx + rax]
    call scanf

    inc r13
    cmp r13, 3
    jl leerB_columna

    inc r12
    cmp r12, 3
    jl leerB_fila

    ; -------------------------------------------------------------------------
    ; Cálculo de distancia de Frobenius
    ; -------------------------------------------------------------------------
    vxorpd ymm6, ymm6, ymm6            ; acumulador vectorial de sumas parciales

    ; Procesar fila 1: 4 doubles = 3 valores reales + padding 0.0
    vmovupd ymm0, ymmword ptr [MatrizA]
    vmovupd ymm1, ymmword ptr [MatrizB]
    vsubpd  ymm2, ymm0, ymm1           ; D = A - B, empacado
    vmovupd ymmword ptr [MatrizD], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask] ; abs(D), empacado con AND
    vmovupd ymmword ptr [MatrizAbs], ymm3
    vmulpd  ymm3, ymm3, ymm3           ; abs(D)^2
    vaddpd  ymm6, ymm6, ymm3

    ; Procesar fila 2
    vmovupd ymm0, ymmword ptr [MatrizA + 32]
    vmovupd ymm1, ymmword ptr [MatrizB + 32]
    vsubpd  ymm2, ymm0, ymm1
    vmovupd ymmword ptr [MatrizD + 32], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    vmovupd ymmword ptr [MatrizAbs + 32], ymm3
    vmulpd  ymm3, ymm3, ymm3
    vaddpd  ymm6, ymm6, ymm3

    ; Procesar fila 3
    vmovupd ymm0, ymmword ptr [MatrizA + 64]
    vmovupd ymm1, ymmword ptr [MatrizB + 64]
    vsubpd  ymm2, ymm0, ymm1
    vmovupd ymmword ptr [MatrizD + 64], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    vmovupd ymmword ptr [MatrizAbs + 64], ymm3
    vmulpd  ymm3, ymm3, ymm3
    vaddpd  ymm6, ymm6, ymm3

    ; Reducir las 4 sumas parciales a un escalar y calcular sqrt.
    vmovupd ymmword ptr [TempSums], ymm6
    vmovsd xmm0, real8 ptr [TempSums]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 8]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 16]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 24]
    vsqrtsd xmm0, xmm0, xmm0
    vmovsd real8 ptr [Resultado], xmm0

    ; -------------------------------------------------------------------------
    ; Mostrar matriz diferencia
    ; -------------------------------------------------------------------------
    lea rcx, tituloDif
    call printf

    xor r12d, r12d
mostrar_fila:
    mov rax, r12
    imul rax, 32                       ; cada fila ocupa 32 bytes

    lea rdi, MatrizD

    lea rcx, fmtFila
    movsd xmm1, real8 ptr [rdi + rax]
    movsd xmm2, real8 ptr [rdi + rax + 8]
    movsd xmm3, real8 ptr [rdi + rax + 16]
    movq rdx, xmm1
    movq r8,  xmm2
    movq r9,  xmm3
    call printf

    inc r12
    cmp r12, 3
    jl mostrar_fila

    ; Mostrar resultado final.
    lea rcx, fmtResultado
    movsd xmm1, real8 ptr [Resultado]
    movq rdx, xmm1
    call printf

    vzeroupper

    add rsp, 40
    pop r13
    pop r12
    pop rdi
    pop rbx
    xor eax, eax
    ret
main ENDP

END
