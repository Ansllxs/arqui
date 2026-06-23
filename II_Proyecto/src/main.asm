; ============================================================
; Proyecto 2 - Distancia de Frobenius con AVX
; IC-3101 Arquitectura de Computadores
;
; Calcula la distancia de Frobenius entre dos matrices A y B de 3x3:
;   d(A,B) = ||A - B||_F = sqrt( sum_i sum_j |a_ij - b_ij|^2 )
; donde las matrices serán dadas por el usuario a través de la consola.
;
;
; Integrantes del proyecto:
; - Julio Quirós Vargas
; - Fabiola González Gómez
; - Angie Alpizar Porras
; - José Gabriel Marín Aguilar
; ============================================================

option casemap:none

PUBLIC main

; Biblioteca de C para entrada/salida en consola.
; printf permite mostrar texto y scanf permite leer doubles con %lf.
includelib msvcrt.lib
includelib legacy_stdio_definitions.lib

printf PROTO C :PTR BYTE, :VARARG
scanf  PROTO C :PTR BYTE, :VARARG

.data
    ; ------------------------------------------------------------
    ; Mensajes y formatos de consola
    ; ------------------------------------------------------------
    tituloA      db 13,10,"Digite los valores de la matriz A (3x3)",13,10,0
    tituloB      db 13,10,"Digite los valores de la matriz B (3x3)",13,10,0
    promptA      db "A[%d][%d] = ",0
    promptB      db "B[%d][%d] = ",0
    fmtScan      db "%lf",0
    tituloDif    db 13,10,"Matriz diferencia A - B:",13,10,0
    fmtFila      db "[ %10.4lf  %10.4lf  %10.4lf ]",13,10,0
    fmtResultado db 13,10,"Distancia de Frobenius: %.6lf",13,10,0

    ; ------------------------------------------------------------
    ; Matrices y variables numéricas
    ; ------------------------------------------------------------
    ; Cada fila ocupa 32 bytes: 3 valores reales + 1 cero de padding.
    ;
    ; Distribución de una matriz:
    ;   Fila 1: posiciones 0, 1, 2, padding
    ;   Fila 2: posiciones 4, 5, 6, padding
    ;   Fila 3: posiciones 8, 9, 10, padding
    ;
    ; El padding siempre queda en 0.0. Por tanto, al hacer A - B, el cuarto
    ; campo de cada fila aporta 0.0 a la suma de cuadrados.
    MatrizA   REAL8 12 DUP(0.0)      ; 3 filas x 4 columnas, con padding en la cuarta columna
    MatrizB   REAL8 12 DUP(0.0)
    MatrizD   REAL8 12 DUP(0.0)      ; diferencia con signo: A - B
    MatrizAbs REAL8 12 DUP(0.0)      ; valor absoluto de la diferencia, calculado con vandpd
    TempSums  REAL8 4 DUP(0.0)       ; sumas parciales por lane del acumulador YMM
    Resultado REAL8 0.0

    ; Máscara para valor absoluto en double.
    ; En el double, el bit más significativo es el signo.
    ; 0x7FFFFFFFFFFFFFFF deja todos los bits iguales excepto el signo, que se apaga.
    ; Al aplicar vandpd con esta máscara:
    ;   abs(x) = x AND 0x7FFFFFFFFFFFFFFF
    AbsMask QWORD 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh

.code
main PROC
    ; ------------------------------------------------------------
    ; Push de registros a la pila
    ; ------------------------------------------------------------
    ; RBX y RDI se usan como registros base para direccionar matrices.
    ; R12 y R13 se usan como contadores de fila y columna.
    push rbx
    push rdi
    push r12
    push r13

    ; Las llamadas a printf/scanf usan RCX, RDX, R8 y R9 como primeros argumentos.
    sub rsp, 40

    ; ============================================================
    ; PARTE 1 - Lectura de matriz A
    ; ============================================================
    ; Se piden 9 valores reales. Internamente se guardan en una matriz
    ; de 12 posiciones, saltando el cuarto campo de cada fila porque es padding.
    lea rcx, tituloA
    call printf

    xor r12d, r12d                     ; r12 = fila = 0
leerA_fila:
    xor r13d, r13d                     ; r13 = columna = 0
leerA_columna:
    ; Mostrar prompt A[fila][columna].
    ; Para el usuario se muestran índices desde 1, por eso se incrementan.
    lea rcx, promptA
    mov edx, r12d
    inc edx                            ; índice de fila mostrado: fila + 1
    mov r8d, r13d
    inc r8d                            ; índice de columna mostrado: columna + 1
    call printf

    ; Calcular la dirección donde se guardará A[fila][columna].
    ; Como cada fila real de 3 columnas se guarda como 4 doubles:
    ;   offset = (fila * 4 + columna) * 8
    ; El *4 salta filas internas completas; el *8 convierte índice a bytes.
    mov rax, r12
    imul rax, 4
    add rax, r13
    imul rax, 8

    ; scanf("%lf", &MatrizA[offset])
    ; Se carga primero la dirección base en RBX para evitar direccionamiento
    ; absoluto con índice dinámico, que puede generar errores de reubicación.
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

    ; ============================================================
    ; PARTE 2 - Lectura de matriz B
    ; ============================================================
    ; Mismo procedimiento usado para A, pero guardando en MatrizB.
    lea rcx, tituloB
    call printf

    xor r12d, r12d                     ; r12 = fila = 0
leerB_fila:
    xor r13d, r13d                     ; r13 = columna = 0
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

    ; scanf("%lf", &MatrizB[offset])
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

    ; ============================================================
    ; PARTE 3 - Cálculo de distancia de Frobenius
    ; ============================================================
    ; Se procesa una fila por vez. 
    ; Para cada fila:
    ;   1- Cargar fila de A en YMM0.
    ;   2- Cargar fila de B en YMM1.
    ;   3- Calcular D = A - B con vsubpd.
    ;   4- Obtener abs(D) con vandpd y AbsMask.
    ;   5- Elevar al cuadrado con vmulpd.
    ;   6- Acumular sumas parciales con vaddpd.
    ;
    ; YMM6 será el acumulador vectorial:
    ;   ymm6[0] acumula los cuadrados de la primera columna.
    ;   ymm6[1] acumula los cuadrados de la segunda columna.
    ;   ymm6[2] acumula los cuadrados de la tercera columna.
    ;   ymm6[3] acumula el padding, que debe permanecer en cero.
    vxorpd ymm6, ymm6, ymm6            ; acumulador vectorial de sumas parciales = 0

    ; ------------------------------------------------------------
    ; Procesar fila 1: 4 doubles = 3 valores reales + padding 0.0
    ; ------------------------------------------------------------
    vmovupd ymm0, ymmword ptr [MatrizA] ; YMM0 = fila 1 de A
    vmovupd ymm1, ymmword ptr [MatrizB] ; YMM1 = fila 1 de B
    vsubpd  ymm2, ymm0, ymm1           ; YMM2 = A - B, diferencia empacada
    vmovupd ymmword ptr [MatrizD], ymm2 ; guardar diferencia con signo para mostrarla
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask] ; YMM3 = abs(A - B), AND empacado
    vmovupd ymmword ptr [MatrizAbs], ymm3
    vmulpd  ymm3, ymm3, ymm3           ; YMM3 = abs(A - B)^2, cuadrado por lane
    vaddpd  ymm6, ymm6, ymm3           ; acumular cuadrados

    ; ------------------------------------------------------------
    ; Procesar fila 2
    ; ------------------------------------------------------------
    ; +32 bytes porque cada fila interna ocupa 32 bytes.
    vmovupd ymm0, ymmword ptr [MatrizA + 32]
    vmovupd ymm1, ymmword ptr [MatrizB + 32]
    vsubpd  ymm2, ymm0, ymm1
    vmovupd ymmword ptr [MatrizD + 32], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    vmovupd ymmword ptr [MatrizAbs + 32], ymm3
    vmulpd  ymm3, ymm3, ymm3
    vaddpd  ymm6, ymm6, ymm3

    ; ------------------------------------------------------------
    ; Procesar fila 3
    ; ------------------------------------------------------------
    ; +64 bytes porque es la tercera fila: 2 filas previas * 32 bytes.
    vmovupd ymm0, ymmword ptr [MatrizA + 64]
    vmovupd ymm1, ymmword ptr [MatrizB + 64]
    vsubpd  ymm2, ymm0, ymm1
    vmovupd ymmword ptr [MatrizD + 64], ymm2
    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    vmovupd ymmword ptr [MatrizAbs + 64], ymm3
    vmulpd  ymm3, ymm3, ymm3
    vaddpd  ymm6, ymm6, ymm3

    ; ============================================================
    ; PARTE 4 - Reducción final y raíz cuadrada
    ; ============================================================
    ; Al terminar las tres filas, YMM6 contiene cuatro sumas parciales.
    ; Se guardan en TempSums y luego se suman de forma escalar para obtener:
    ;   sumaTotal = sum_i sum_j (a_ij - b_ij)^2
    ; Finalmente se calcula sqrt(sumaTotal).
    vmovupd ymmword ptr [TempSums], ymm6
    vmovsd xmm0, real8 ptr [TempSums]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 8]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 16]
    vaddsd xmm0, xmm0, real8 ptr [TempSums + 24]
    vsqrtsd xmm0, xmm0, xmm0
    vmovsd real8 ptr [Resultado], xmm0

    ; ============================================================
    ; PARTE 5 - Mostrar matriz diferencia A - B
    ; ============================================================
    ; La matriz diferencia se imprime para facilitar la revisión del resultado.
    ; Solo se muestran las primeras 3 columnas de cada fila; el padding no se imprime.
    lea rcx, tituloDif
    call printf

    xor r12d, r12d                     ; fila = 0
mostrar_fila:
    ; offset = fila * 32 porque cada fila interna ocupa 32 bytes.
    mov rax, r12
    imul rax, 32

    ; Cargar dirección base de MatrizD en RDI para usar [rdi + offset].
    lea rdi, MatrizD

    ; printf(fmtFila, D[fila][0], D[fila][1], D[fila][2])
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

    ; ============================================================
    ; PARTE 6 - Mostrar resultado final y salir
    ; ============================================================
    ; Se imprime la distancia de Frobenius calculada.
    lea rcx, fmtResultado
    movsd xmm1, real8 ptr [Resultado]
    movq rdx, xmm1
    call printf

    ; Limpia la parte alta de los registros YMM antes de retornar.
    vzeroupper

    ; Restaurar pila y registros.
    add rsp, 40
    pop r13
    pop r12
    pop rdi
    pop rbx
    xor eax, eax                       ; return 0
    ret
main ENDP

END