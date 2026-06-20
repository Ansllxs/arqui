; Proyecto 2 - Distancia de Frobenius con AVX
; IC-3101 Arquitectura de Computadores
;
; Calcula la distancia de Frobenius entre dos matrices A y B de 3x3:
;   d(A,B) = ||A - B||_F = sqrt( sum_i sum_j |a_ij - b_ij|^2 )
;
; Decisiones de implementación:
; - Se usa precisión doble (REAL8 / double).
; - Cada fila real de 3 elementos se guarda como 4 doubles, agregando un 0.0 de padding.
; - La diferencia A-B se calcula con AVX empacado: vsubpd.
; - El valor absoluto se calcula con AND empacado: vandpd usando una máscara que apaga el bit de signo.
; - La suma final de los cuadrados se reduce de forma escalar después de acumular las filas vectorialmente.
;
; Configuración recomendada en Visual Studio:
; - Crear un proyecto C++ vacío de consola en x64.
; - Activar MASM: Build Customizations -> masm.
; - Agregar este archivo .asm como archivo fuente.
; - Como se usa printf/scanf del CRT, dejar el Entry Point por defecto del proyecto.
;   No configurar Linker > Advanced > Entry Point = main para esta versión.

option casemap:none

includelib msvcrt.lib

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

    ALIGN 32
    MatrizA   REAL8 12 DUP(0.0)      ; 3 filas x 4 columnas, con padding en la cuarta columna
    MatrizB   REAL8 12 DUP(0.0)
    MatrizD   REAL8 12 DUP(0.0)      ; diferencia con signo: A - B
    MatrizAbs REAL8 12 DUP(0.0)      ; valor absoluto de la diferencia, calculado con vandpd
    TempSums  REAL8 4 DUP(0.0)       ; sumas parciales por lane
    Resultado REAL8 0.0

    ALIGN 32
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
    lea rdx, MatrizA[rax*8]
    lea rcx, fmtScan
    call scanf

    inc r13d
    cmp r13d, 3
    jl leerA_columna

    inc r12d
    cmp r12d, 3
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
    lea rdx, MatrizB[rax*8]
    lea rcx, fmtScan
    call scanf

    inc r13d
    cmp r13d, 3
    jl leerB_columna

    inc r12d
    cmp r12d, 3
    jl leerB_fila

    ; -------------------------------------------------------------------------
    ; Cálculo vectorial: diferencia, valor absoluto y cuadrados
    ; Cada fila se procesa como un vector de 4 doubles:
    ; [x1, x2, x3, 0.0]
    ; -------------------------------------------------------------------------
    vxorpd ymm6, ymm6, ymm6            ; acumulador vectorial de cuadrados

    ; Fila 1
    vmovupd ymm0, ymmword ptr [MatrizA]
    vmovupd ymm1, ymmword ptr [MatrizB]
    vsubpd  ymm2, ymm0, ymm1           ; diferencia empacada: A - B
    vmovupd ymmword ptr [MatrizD], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask] ; abs empacado apagando bit de signo
    vmovupd ymmword ptr [MatrizAbs], ymm3
    vmulpd  ymm3, ymm3, ymm3           ; cuadrados por lane
    vaddpd  ymm6, ymm6, ymm3

    ; Fila 2
    vmovupd ymm0, ymmword ptr [MatrizA + 32]
    vmovupd ymm1, ymmword ptr [MatrizB + 32]
    vsubpd  ymm2, ymm0, ymm1
    vmovupd ymmword ptr [MatrizD + 32], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    vmovupd ymmword ptr [MatrizAbs + 32], ymm3
    vmulpd  ymm3, ymm3, ymm3
    vaddpd  ymm6, ymm6, ymm3

    ; Fila 3
    vmovupd ymm0, ymmword ptr [MatrizA + 64]
    vmovupd ymm1, ymmword ptr [MatrizB + 64]
    vsubpd  ymm2, ymm0, ymm1
    vmovupd ymmword ptr [MatrizD + 64], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    vmovupd ymmword ptr [MatrizAbs + 64], ymm3
    vmulpd  ymm3, ymm3, ymm3
    vaddpd  ymm6, ymm6, ymm3

    ; Reducir las 4 lanes del acumulador. La cuarta lane es 0 por padding.
    vmovupd ymmword ptr [TempSums], ymm6
    vmovsd xmm0, real8 ptr [TempSums]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 8]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 16]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 24]
    vsqrtsd xmm0, xmm0, xmm0
    vmovsd real8 ptr [Resultado], xmm0

    ; Evita penalización al volver de AVX a llamadas externas SSE/CRT.
    vzeroupper

    ; -------------------------------------------------------------------------
    ; Mostrar matriz diferencia A-B
    ; -------------------------------------------------------------------------
    lea rcx, tituloDif
    call printf

    ; Fila 1
    lea rcx, fmtFila
    mov rdx, qword ptr [MatrizD]
    movq xmm1, rdx
    mov r8, qword ptr [MatrizD + 8]
    movq xmm2, r8
    mov r9, qword ptr [MatrizD + 16]
    movq xmm3, r9
    call printf

    ; Fila 2
    lea rcx, fmtFila
    mov rdx, qword ptr [MatrizD + 32]
    movq xmm1, rdx
    mov r8, qword ptr [MatrizD + 40]
    movq xmm2, r8
    mov r9, qword ptr [MatrizD + 48]
    movq xmm3, r9
    call printf

    ; Fila 3
    lea rcx, fmtFila
    mov rdx, qword ptr [MatrizD + 64]
    movq xmm1, rdx
    mov r8, qword ptr [MatrizD + 72]
    movq xmm2, r8
    mov r9, qword ptr [MatrizD + 80]
    movq xmm3, r9
    call printf

    ; Resultado final. En llamadas variádicas x64, el double se pasa en XMM1
    ; y se duplica en el registro general correspondiente (RDX).
    lea rcx, fmtResultado
    mov rdx, qword ptr [Resultado]
    movq xmm1, rdx
    call printf

    add rsp, 40
    pop r13
    pop r12
    pop rdi
    pop rbx

    xor eax, eax
    ret
main ENDP

END