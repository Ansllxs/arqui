; ============================================================
; Proyecto 2 - Distancia de Frobenius con AVX
; IC-3101 Arquitectura de Computadores
;
; Este programa calcula la distancia de Frobenius entre dos matrices A y B.
; Ambas matrices son de tamaño 3x3.
;
; La fórmula usada es:
; d(A,B) = ||A - B||_F
;        = sqrt( suma de todos los elementos de (A-B)^2 )
;
; En palabras simples:
; 1. Se lee la matriz A.
; 2. Se lee la matriz B.
; 3. Se calcula la matriz diferencia D = A - B.
; 4. Se eleva cada diferencia al cuadrado.
; 5. Se suman todos esos cuadrados.
; 6. Se calcula la raíz cuadrada de esa suma.
;
; El programa usa AVX, específicamente registros YMM de 256 bits.
; Cada registro YMM puede guardar 4 números double de 64 bits.
; Como cada fila de la matriz tiene solo 3 números, se agrega un cuarto
; valor en cero, llamado padding.
; ============================================================

option casemap:none
; Evita que MASM cambie mayúsculas y minúsculas automáticamente.
; Es decir, "main" y "Main" se tratarían como nombres diferentes.

PUBLIC main
; Hace visible la función main para que el enlazador pueda encontrarla.
; Es el punto de entrada del programa.

; ------------------------------------------------------------
; Librerías de C
; ------------------------------------------------------------

includelib msvcrt.lib
; Incluye la librería estándar de C para poder usar printf y scanf.

includelib legacy_stdio_definitions.lib
; Librería auxiliar que puede ser necesaria en Visual Studio moderno
; para que printf y scanf funcionen correctamente.

printf PROTO C :PTR BYTE, :VARARG
; Declara la función printf.
; printf sirve para imprimir texto en consola.
; :VARARG significa que puede recibir una cantidad variable de argumentos.

scanf  PROTO C :PTR BYTE, :VARARG
; Declara la función scanf.
; scanf sirve para leer datos desde consola.
; También recibe cantidad variable de argumentos.

.data
; Inicio de la sección de datos.
; Aquí se guardan textos, matrices, variables y constantes.

    ; ------------------------------------------------------------
    ; Mensajes y formatos de consola
    ; ------------------------------------------------------------

    tituloA      db 13,10,"Digite los valores de la matriz A (3x3)",13,10,0
    ; Texto que se muestra antes de pedir la matriz A.
    ; 13,10 equivale a salto de línea en Windows.
    ; El 0 final indica fin de cadena para printf.

    tituloB      db 13,10,"Digite los valores de la matriz B (3x3)",13,10,0
    ; Texto que se muestra antes de pedir la matriz B.

    promptA      db "A[%d][%d] = ",0
    ; Formato para pedir cada elemento de A.
    ; %d se reemplaza por el número de fila y columna.

    promptB      db "B[%d][%d] = ",0
    ; Formato para pedir cada elemento de B.

    fmtScan      db "%lf",0
    ; Formato para scanf.
    ; %lf indica que se va a leer un número double.

    tituloDif    db 13,10,"Matriz diferencia A - B:",13,10,0
    ; Texto que se imprime antes de mostrar la matriz diferencia.

    fmtFila      db "[ %10.4lf  %10.4lf  %10.4lf ]",13,10,0
    ; Formato para imprimir una fila de la matriz diferencia.
    ; Cada valor se imprime como double con 4 decimales.

    fmtResultado db 13,10,"Distancia de Frobenius: %.6lf",13,10,0
    ; Formato para imprimir el resultado final con 6 decimales.

    ; ------------------------------------------------------------
    ; Matrices y variables numéricas
    ; ------------------------------------------------------------

    MatrizA   REAL8 12 DUP(0.0)
    ; Matriz A.
    ; REAL8 significa número real de 8 bytes, o sea double de 64 bits.
    ; Aunque A es 3x3, se reservan 12 espacios.
    ; Esto es porque cada fila se guarda con 4 valores:
    ; 3 valores reales + 1 padding en cero.
    ;
    ; Distribución:
    ; fila 1: A11, A12, A13, 0
    ; fila 2: A21, A22, A23, 0
    ; fila 3: A31, A32, A33, 0

    MatrizB   REAL8 12 DUP(0.0)
    ; Matriz B, con la misma estructura que MatrizA.

    MatrizD   REAL8 12 DUP(0.0)
    ; Aquí se guarda la matriz diferencia D = A - B.
    ; También tiene 12 espacios por el padding.

    MatrizAbs REAL8 12 DUP(0.0)
    ; Aquí se guarda el valor absoluto de la diferencia.
    ; Es decir, abs(A-B).
    ; Aunque matemáticamente no es necesario para elevar al cuadrado,
    ; se usa para demostrar el uso de máscara con AVX.

    TempSums  REAL8 4 DUP(0.0)
    ; Guarda temporalmente las sumas parciales del acumulador YMM.
    ; Como un YMM tiene 4 posiciones double, se reservan 4 espacios.

    Resultado REAL8 0.0
    ; Guarda la distancia de Frobenius final.

    AbsMask QWORD 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh
    ; Máscara para calcular valor absoluto en double.
    ; En IEEE 754, el bit más significativo representa el signo.
    ; Esta máscara tiene todos los bits en 1 excepto el bit de signo.
    ; Al aplicar AND con esta máscara, se apaga el signo.
    ; Resultado: si el número era negativo, queda positivo.

.code
; Inicio de la sección de código.

main PROC
; Inicio del procedimiento main.

    ; ------------------------------------------------------------
    ; Prólogo de la función
    ; ------------------------------------------------------------

    push rbx
    ; Guarda RBX en la pila porque RBX es un registro no volátil.
    ; Si se usa, debe restaurarse antes de salir.

    push rdi
    ; Guarda RDI por la misma razón.
    ; Se usará luego como base para direccionar MatrizD.

    push r12
    ; Guarda R12.
    ; Este registro se usará como contador de filas.

    push r13
    ; Guarda R13.
    ; Este registro se usará como contador de columnas.

    sub rsp, 40
    ; Reserva espacio en la pila.
    ; En Windows x64, antes de llamar funciones como printf o scanf,
    ; se necesita reservar shadow space.
    ; También ayuda a mantener la alineación correcta de la pila.

    ; ============================================================
    ; PARTE 1 - Lectura de matriz A
    ; ============================================================

    lea rcx, tituloA
    ; Carga en RCX la dirección del texto tituloA.
    ; En Windows x64, el primer argumento de una función va en RCX.

    call printf
    ; Imprime el mensaje: "Digite los valores de la matriz A".

    xor r12d, r12d
    ; Pone r12 en cero.
    ; r12 será el contador de fila.
    ; Entonces fila = 0.

leerA_fila:
    ; Etiqueta que marca el inicio del ciclo de filas para la matriz A.

    xor r13d, r13d
    ; Pone r13 en cero.
    ; r13 será el contador de columna.
    ; Entonces columna = 0.

leerA_columna:
    ; Etiqueta que marca el inicio del ciclo de columnas para la matriz A.

    lea rcx, promptA
    ; Primer argumento para printf: dirección del texto "A[%d][%d] = ".

    mov edx, r12d
    ; Segundo argumento para printf: número de fila.
    ; Se copia la fila actual en EDX.

    inc edx
    ; Se suma 1 para mostrar filas desde 1 y no desde 0.
    ; Internamente se usa 0, 1, 2.
    ; Al usuario se le muestra 1, 2, 3.

    mov r8d, r13d
    ; Tercer argumento para printf: número de columna.
    ; Se copia la columna actual en R8D.

    inc r8d
    ; Se suma 1 para mostrar columnas desde 1 y no desde 0.

    call printf
    ; Imprime el prompt, por ejemplo:
    ; A[1][1] =

    mov rax, r12
    ; Copia la fila actual en RAX para calcular el offset.

    imul rax, 4
    ; Multiplica la fila por 4.
    ; Esto se hace porque internamente cada fila tiene 4 elementos:
    ; 3 datos reales + 1 padding.

    add rax, r13
    ; Suma la columna.
    ; Ahora RAX contiene el índice interno:
    ; índice = fila * 4 + columna.

    imul rax, 8
    ; Multiplica por 8 porque cada REAL8 ocupa 8 bytes.
    ; Ahora RAX contiene el offset en bytes.

    lea rcx, fmtScan
    ; Primer argumento de scanf: formato "%lf".

    lea rbx, MatrizA
    ; Carga en RBX la dirección base de MatrizA.

    lea rdx, [rbx + rax]
    ; Segundo argumento de scanf: dirección donde se guardará el número leído.
    ; Es decir, &MatrizA[fila][columna].

    call scanf
    ; Lee un double desde consola y lo guarda en MatrizA.

    inc r13
    ; columna = columna + 1.

    cmp r13, 3
    ; Compara la columna con 3.
    ; Como las columnas válidas son 0, 1 y 2,
    ; cuando r13 llega a 3 ya se terminó la fila.

    jl leerA_columna
    ; Si columna < 3, vuelve a pedir otro elemento de la misma fila.

    inc r12
    ; fila = fila + 1.

    cmp r12, 3
    ; Compara la fila con 3.
    ; Las filas válidas son 0, 1 y 2.

    jl leerA_fila
    ; Si fila < 3, vuelve a leer la siguiente fila de A.

    ; ============================================================
    ; PARTE 2 - Lectura de matriz B
    ; ============================================================

    lea rcx, tituloB
    ; Carga la dirección del mensaje para pedir la matriz B.

    call printf
    ; Imprime el mensaje de entrada para la matriz B.

    xor r12d, r12d
    ; Reinicia el contador de filas en cero.

leerB_fila:
    ; Inicio del ciclo de filas para B.

    xor r13d, r13d
    ; Reinicia el contador de columnas en cero.

leerB_columna:
    ; Inicio del ciclo de columnas para B.

    lea rcx, promptB
    ; Primer argumento de printf: texto "B[%d][%d] = ".

    mov edx, r12d
    ; Segundo argumento: fila actual.

    inc edx
    ; Se suma 1 para mostrar la fila desde 1.

    mov r8d, r13d
    ; Tercer argumento: columna actual.

    inc r8d
    ; Se suma 1 para mostrar la columna desde 1.

    call printf
    ; Imprime el prompt de B.

    mov rax, r12
    ; Copia la fila actual en RAX.

    imul rax, 4
    ; Multiplica la fila por 4 porque cada fila interna tiene 4 doubles.

    add rax, r13
    ; Suma la columna actual.

    imul rax, 8
    ; Multiplica por 8 para convertir el índice a bytes.

    lea rcx, fmtScan
    ; Primer argumento de scanf: "%lf".

    lea rbx, MatrizB
    ; Carga en RBX la dirección base de MatrizB.

    lea rdx, [rbx + rax]
    ; Segundo argumento de scanf: dirección donde se guardará B[fila][columna].

    call scanf
    ; Lee un double desde consola y lo guarda en MatrizB.

    inc r13
    ; columna = columna + 1.

    cmp r13, 3
    ; Revisa si ya se leyeron las 3 columnas.

    jl leerB_columna
    ; Si no, sigue leyendo columnas.

    inc r12
    ; fila = fila + 1.

    cmp r12, 3
    ; Revisa si ya se leyeron las 3 filas.

    jl leerB_fila
    ; Si no, sigue leyendo filas.

    ; ============================================================
    ; PARTE 3 - Cálculo de la distancia de Frobenius usando AVX
    ; ============================================================

    vxorpd ymm6, ymm6, ymm6
    ; Limpia YMM6 poniéndolo en cero.
    ; YMM6 será el acumulador de las sumas de cuadrados.
    ;
    ; Queda así:
    ; ymm6 = [0, 0, 0, 0]

    ; ------------------------------------------------------------
    ; Procesar fila 1
    ; ------------------------------------------------------------

    vmovupd ymm0, ymmword ptr [MatrizA]
    ; Carga la primera fila de MatrizA en YMM0.
    ; Carga 4 doubles:
    ; [A11, A12, A13, padding]

    vmovupd ymm1, ymmword ptr [MatrizB]
    ; Carga la primera fila de MatrizB en YMM1:
    ; [B11, B12, B13, padding]

    vsubpd  ymm2, ymm0, ymm1
    ; Resta elemento por elemento:
    ; YMM2 = YMM0 - YMM1
    ; Entonces:
    ; YMM2 = [A11-B11, A12-B12, A13-B13, 0-0]

    vmovupd ymmword ptr [MatrizD], ymm2
    ; Guarda esa diferencia en MatrizD para imprimirla después.

    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    ; Calcula el valor absoluto de cada diferencia.
    ; Esto se hace apagando el bit de signo con la máscara AbsMask.
    ; YMM3 = abs(YMM2)

    vmovupd ymmword ptr [MatrizAbs], ymm3
    ; Guarda los valores absolutos en MatrizAbs.

    vmulpd  ymm3, ymm3, ymm3
    ; Eleva al cuadrado cada elemento:
    ; YMM3 = YMM3 * YMM3
    ; Es decir:
    ; [(A11-B11)^2, (A12-B12)^2, (A13-B13)^2, 0]

    vaddpd  ymm6, ymm6, ymm3
    ; Acumula esos cuadrados en YMM6.
    ; Como YMM6 estaba en cero, ahora contiene los cuadrados de la fila 1.

    ; ------------------------------------------------------------
    ; Procesar fila 2
    ; ------------------------------------------------------------

    vmovupd ymm0, ymmword ptr [MatrizA + 32]
    ; Carga la segunda fila de A.
    ; Se suma 32 porque cada fila ocupa 4 doubles * 8 bytes = 32 bytes.

    vmovupd ymm1, ymmword ptr [MatrizB + 32]
    ; Carga la segunda fila de B.

    vsubpd  ymm2, ymm0, ymm1
    ; Calcula la diferencia de la segunda fila:
    ; [A21-B21, A22-B22, A23-B23, 0]

    vmovupd ymmword ptr [MatrizD + 32], ymm2
    ; Guarda la segunda fila de la matriz diferencia.

    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    ; Calcula el valor absoluto de las diferencias.

    vmovupd ymmword ptr [MatrizAbs + 32], ymm3
    ; Guarda el valor absoluto de la segunda fila.

    vmulpd  ymm3, ymm3, ymm3
    ; Eleva al cuadrado cada diferencia de la segunda fila.

    vaddpd  ymm6, ymm6, ymm3
    ; Suma esos cuadrados al acumulador YMM6.
    ; Ahora YMM6 tiene acumulado fila 1 + fila 2.

    ; ------------------------------------------------------------
    ; Procesar fila 3
    ; ------------------------------------------------------------

    vmovupd ymm0, ymmword ptr [MatrizA + 64]
    ; Carga la tercera fila de A.
    ; Se suma 64 porque hay dos filas antes:
    ; 2 * 32 bytes = 64 bytes.

    vmovupd ymm1, ymmword ptr [MatrizB + 64]
    ; Carga la tercera fila de B.

    vsubpd  ymm2, ymm0, ymm1
    ; Calcula la diferencia de la tercera fila:
    ; [A31-B31, A32-B32, A33-B33, 0]

    vmovupd ymmword ptr [MatrizD + 64], ymm2
    ; Guarda la tercera fila de la matriz diferencia.

    vandpd  ymm3, ymm2, ymmword ptr [AbsMask]
    ; Calcula el valor absoluto de las diferencias de la tercera fila.

    vmovupd ymmword ptr [MatrizAbs + 64], ymm3
    ; Guarda esos valores absolutos.

    vmulpd  ymm3, ymm3, ymm3
    ; Eleva al cuadrado cada elemento.

    vaddpd  ymm6, ymm6, ymm3
    ; Acumula los cuadrados de la tercera fila.
    ;
    ; Al final, YMM6 contiene algo como:
    ; [
    ;   suma de cuadrados de la columna 1,
    ;   suma de cuadrados de la columna 2,
    ;   suma de cuadrados de la columna 3,
    ;   suma del padding
    ; ]
    ;
    ; El padding debe quedar en cero.

    ; ============================================================
    ; PARTE 4 - Reducción final y raíz cuadrada
    ; ============================================================

    vmovupd ymmword ptr [TempSums], ymm6
    ; Guarda el acumulador vectorial YMM6 en memoria.
    ; Esto permite sumar luego sus 4 posiciones de forma escalar.

    vmovsd xmm0, real8 ptr [TempSums]
    ; Carga la primera suma parcial en XMM0.
    ; XMM0 tendrá la suma de cuadrados de la primera columna.

    vaddsd xmm0, xmm0, real8 ptr [TempSums + 8]
    ; Suma la segunda posición de TempSums.
    ; +8 porque cada double ocupa 8 bytes.

    vaddsd xmm0, xmm0, real8 ptr [TempSums + 16]
    ; Suma la tercera posición de TempSums.

    vaddsd xmm0, xmm0, real8 ptr [TempSums + 24]
    ; Suma la cuarta posición de TempSums.
    ; Esta posición corresponde al padding, normalmente es cero.

    vsqrtsd xmm0, xmm0, xmm0
    ; Calcula la raíz cuadrada escalar.
    ; Aquí se obtiene finalmente:
    ; sqrt(suma total de cuadrados)

    vmovsd real8 ptr [Resultado], xmm0
    ; Guarda el resultado final en la variable Resultado.

    ; ============================================================
    ; PARTE 5 - Mostrar matriz diferencia A - B
    ; ============================================================

    lea rcx, tituloDif
    ; Carga el mensaje "Matriz diferencia A - B".

    call printf
    ; Imprime el título de la matriz diferencia.

    xor r12d, r12d
    ; Reinicia el contador de filas en cero.

mostrar_fila:
    ; Inicio del ciclo para imprimir cada fila de la matriz diferencia.

    mov rax, r12
    ; Copia la fila actual en RAX.

    imul rax, 32
    ; Calcula el offset de la fila.
    ; Cada fila ocupa 32 bytes.

    lea rdi, MatrizD
    ; Carga en RDI la dirección base de MatrizD.

    lea rcx, fmtFila
    ; Primer argumento de printf: formato de impresión de fila.

    movsd xmm1, real8 ptr [rdi + rax]
    ; Carga el primer elemento de la fila actual en XMM1.

    movsd xmm2, real8 ptr [rdi + rax + 8]
    ; Carga el segundo elemento de la fila actual en XMM2.

    movsd xmm3, real8 ptr [rdi + rax + 16]
    ; Carga el tercer elemento de la fila actual en XMM3.
    ; No se carga el cuarto elemento porque es padding.

    movq rdx, xmm1
    ; Copia los bits del primer double a RDX.
    ; RDX será el segundo argumento de printf.

    movq r8,  xmm2
    ; Copia los bits del segundo double a R8.
    ; R8 será el tercer argumento de printf.

    movq r9,  xmm3
    ; Copia los bits del tercer double a R9.
    ; R9 será el cuarto argumento de printf.

    call printf
    ; Imprime una fila de la matriz diferencia.

    inc r12
    ; fila = fila + 1.

    cmp r12, 3
    ; Revisa si ya se imprimieron las 3 filas.

    jl mostrar_fila
    ; Si faltan filas, vuelve a imprimir la siguiente.

    ; ============================================================
    ; PARTE 6 - Mostrar resultado final y salir
    ; ============================================================

    lea rcx, fmtResultado
    ; Primer argumento de printf: formato del resultado final.

    movsd xmm1, real8 ptr [Resultado]
    ; Carga el resultado final en XMM1.

    movq rdx, xmm1
    ; Copia los bits del double a RDX para pasarlo a printf.

    call printf
    ; Imprime la distancia de Frobenius.

    vzeroupper
    ; Limpia la parte alta de los registros YMM.
    ; Esto es buena práctica cuando se usa AVX y luego se vuelve a código externo
    ; o librerías que pueden usar registros SSE.

    add rsp, 40
    ; Libera el espacio reservado en la pila.

    pop r13
    ; Restaura el valor original de R13.

    pop r12
    ; Restaura el valor original de R12.

    pop rdi
    ; Restaura el valor original de RDI.

    pop rbx
    ; Restaura el valor original de RBX.

    xor eax, eax
    ; Pone EAX en cero.
    ; En C/C++, retornar 0 significa que el programa terminó correctamente.

    ret
    ; Retorna desde main.

main ENDP
; Fin del procedimiento main.

END
; Fin del archivo ensamblador.
