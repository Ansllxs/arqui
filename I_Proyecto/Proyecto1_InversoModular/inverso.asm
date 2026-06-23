; ============================================================
; Proyecto 1 - Inverso Multiplicativo Modular
; Arquitectura de Computadores
;
; Este programa calcula el inverso multiplicativo modular.
;
; El usuario ingresa dos enteros:
;   a = número al que se le quiere calcular el inverso
;   p = módulo
;
; El programa busca un número x tal que:
;
;   a*x ≡ 1 mod p
;
; Por ejemplo:
;   Si a = 3 y p = 11,
;   el inverso es 4 porque:
;   3*4 = 12
;   12 mod 11 = 1
;
; Para saber si existe inverso se revisa:
;
;   mcd(a,p) = 1
;
; Si el máximo común divisor es 1, sí existe inverso.
; Si el máximo común divisor no es 1, no existe inverso.
;
; El programa usa el algoritmo extendido de Euclides, que encuentra:
;
;   a*x + p*y = mcd(a,p)
;
; Cuando mcd(a,p) = 1:
;
;   a*x + p*y = 1
;
; Entonces x es el inverso modular de a módulo p.
;
; Los parámetros entre procedimientos se pasan por la pila.
; ============================================================

option casemap:none
; Evita que MASM cambie automáticamente mayúsculas y minúsculas.
; Así, "main" y "Main" serían considerados nombres diferentes.

includelib ucrt.lib
; Incluye la librería Universal C Runtime.
; Sirve para funciones estándar de C.

includelib vcruntime.lib
; Incluye la librería de runtime de Visual C++.

includelib legacy_stdio_definitions.lib
; Librería auxiliar necesaria en algunos proyectos de Visual Studio
; para usar printf y scanf correctamente.

includelib kernel32.lib
; Incluye funciones de Windows.
; En este programa se usa ExitProcess para finalizar.

EXTERN printf:PROC
; Declara que printf existe externamente.
; printf se usa para imprimir texto en consola.

EXTERN scanf:PROC
; Declara que scanf existe externamente.
; scanf se usa para leer datos desde consola.

EXTERN ExitProcess:PROC
; Declara la función ExitProcess.
; Esta función termina el programa.

PUBLIC main
; Hace visible main como punto de entrada del programa.

.data
; Inicio de la sección de datos.
; Aquí se guardan textos y formatos.

msg_pedir_a    db "Ingrese el numero a: ", 0
; Mensaje que se muestra para pedir el valor de a.
; El 0 final indica fin de cadena.

msg_pedir_p    db "Ingrese el modulo p: ", 0
; Mensaje que se muestra para pedir el módulo p.

formato_num    db "%lld", 0
; Formato usado por scanf para leer enteros de 64 bits.
; %lld significa long long int.

msg_resultado  db "El inverso de %lld modulo %lld es: %lld", 13, 10, 0
; Mensaje para imprimir el resultado.
; Tiene tres %lld:
;   primero: a
;   segundo: p
;   tercero: resultado
; 13,10 genera salto de línea en Windows.

msg_error      db "El numero no tiene inverso multiplicativo modular", 13, 10, 0
; Mensaje que se imprime cuando no existe inverso.


.code
; Inicio de la sección de código.

; ============================================================
; PARTE 1 - Entrada, salida y control general
; ============================================================

; ------------------------------------------------------------
; main
;
; Función principal del programa.
;
; Variables locales:
;   [rbp-8]  = a
;   [rbp-16] = p
;   [rbp-24] = x
;   [rbp-32] = mcd
;   [rbp-40] = resultado
; ------------------------------------------------------------

main PROC
; Inicio del procedimiento main.

    push rbp
    ; Guarda el valor anterior de RBP en la pila.
    ; RBP se usa como base para acceder a variables locales.

    mov  rbp, rsp
    ; Copia RSP en RBP.
    ; A partir de aquí, RBP será la referencia fija del marco de pila.

    sub  rsp, 80
    ; Reserva 80 bytes en la pila para variables locales y espacio extra.
    ; Aquí se guardarán a, p, x, mcd y resultado.

    ; ------------------------------------------------------------
    ; leerDatos(&a, &p)
    ; ------------------------------------------------------------
    ; Se llama al procedimiento leerDatos para pedir a y p al usuario.
    ; Se pasan las direcciones de memoria donde se guardarán esos valores.

    lea rax, [rbp-8]
    ; Carga en RAX la dirección de la variable local a.

    push rax
    ; Pasa por pila la dirección de a.
    ; Es decir, se pasa &a.

    lea rax, [rbp-16]
    ; Carga en RAX la dirección de la variable local p.

    push rax
    ; Pasa por pila la dirección de p.
    ; Es decir, se pasa &p.

    call leerDatos
    ; Llama al procedimiento que pide y lee los datos del usuario.

    add  rsp, 16
    ; Limpia de la pila los dos parámetros enviados.
    ; Cada parámetro ocupa 8 bytes.
    ; 2 parámetros * 8 bytes = 16 bytes.

    ; ------------------------------------------------------------
    ; inversoModular(a, p, &x, &mcd)
    ; ------------------------------------------------------------
    ; Se llama a inversoModular para calcular el coeficiente x
    ; y el máximo común divisor mcd.

    push QWORD PTR [rbp-8]
    ; Pasa el valor de a por pila.

    push QWORD PTR [rbp-16]
    ; Pasa el valor de p por pila.

    lea rax, [rbp-24]
    ; Carga la dirección de la variable x.

    push rax
    ; Pasa &x por pila.
    ; Aquí se guardará el posible inverso.

    lea rax, [rbp-32]
    ; Carga la dirección de la variable mcd.

    push rax
    ; Pasa &mcd por pila.
    ; Aquí se guardará el máximo común divisor.

    call inversoModular
    ; Llama al procedimiento que valida datos y calcula el inverso.

    add  rsp, 32
    ; Limpia los 4 parámetros de la pila.
    ; 4 parámetros * 8 bytes = 32 bytes.

    ; ------------------------------------------------------------
    ; Revisar si existe inverso
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp-32]
    ; Carga el mcd calculado en RAX.

    cmp rax, 1
    ; Compara mcd con 1.

    jne main_no_existe
    ; Si mcd no es igual a 1, salta a main_no_existe.
    ; Eso significa que no existe inverso modular.

    ; ------------------------------------------------------------
    ; ajustarPositivo(x, p, &resultado)
    ; ------------------------------------------------------------
    ; Si sí existe inverso, se ajusta para que quede positivo
    ; y dentro del rango 0 hasta p-1.

    push QWORD PTR [rbp-24]
    ; Pasa el valor de x.
    ; x puede venir negativo desde Euclides extendido.

    push QWORD PTR [rbp-16]
    ; Pasa el valor de p.

    lea rax, [rbp-40]
    ; Carga la dirección de resultado.

    push rax
    ; Pasa &resultado.
    ; Aquí se guardará el inverso ya ajustado.

    call ajustarPositivo
    ; Llama al procedimiento que convierte x a un residuo positivo.

    add  rsp, 24
    ; Limpia los 3 parámetros enviados.
    ; 3 parámetros * 8 bytes = 24 bytes.

    ; ------------------------------------------------------------
    ; imprimirResultado(a, p, resultado)
    ; ------------------------------------------------------------

    push QWORD PTR [rbp-8]
    ; Pasa a.

    push QWORD PTR [rbp-16]
    ; Pasa p.

    push QWORD PTR [rbp-40]
    ; Pasa el resultado final.

    call imprimirResultado
    ; Imprime el inverso modular encontrado.

    add  rsp, 24
    ; Limpia los 3 parámetros de la pila.

    jmp main_fin
    ; Salta al final del programa.

main_no_existe:
    ; Etiqueta a la que se llega cuando mcd(a,p) no es 1.

    call imprimirError
    ; Imprime mensaje indicando que no existe inverso.

main_fin:
    ; Finalización del programa.

    xor ecx, ecx
    ; Pone ECX en cero.
    ; En Windows x64, el primer argumento de ExitProcess va en RCX.
    ; Código de salida = 0.

    call ExitProcess
    ; Termina el programa.

main ENDP
; Fin del procedimiento main.


; ------------------------------------------------------------
; leerDatos
;
; Función encargada de pedir y leer a y p.
;
; Recibe por pila:
;   [rbp+24] = dirección donde se guarda a
;   [rbp+16] = dirección donde se guarda p
; ------------------------------------------------------------

leerDatos PROC
; Inicio del procedimiento leerDatos.

    push rbp
    ; Guarda el RBP anterior.

    mov  rbp, rsp
    ; Crea un nuevo marco de pila para este procedimiento.

    and  rsp, -16
    ; Alinea la pila a 16 bytes.
    ; Esto es importante antes de llamar funciones externas como printf y scanf.

    ; ------------------------------------------------------------
    ; Mostrar mensaje para a
    ; ------------------------------------------------------------

    mov rcx, OFFSET msg_pedir_a
    ; Carga en RCX la dirección del mensaje "Ingrese el numero a:".
    ; RCX es el primer argumento en Windows x64.

    sub rsp, 32
    ; Reserva shadow space requerido por la convención de llamadas de Windows x64.

    call printf
    ; Imprime el mensaje para pedir a.

    add rsp, 32
    ; Libera el shadow space reservado.

    ; ------------------------------------------------------------
    ; Leer a
    ; ------------------------------------------------------------

    mov rcx, OFFSET formato_num
    ; Primer argumento de scanf: formato "%lld".

    mov rdx, QWORD PTR [rbp+24]
    ; Segundo argumento de scanf: dirección donde se guardará a.
    ; [rbp+24] contiene &a.

    sub rsp, 32
    ; Reserva shadow space antes de llamar scanf.

    call scanf
    ; Lee el número ingresado por el usuario y lo guarda en a.

    add rsp, 32
    ; Libera el espacio reservado.

    ; ------------------------------------------------------------
    ; Mostrar mensaje para p
    ; ------------------------------------------------------------

    mov rcx, OFFSET msg_pedir_p
    ; Primer argumento de printf: mensaje "Ingrese el modulo p:".

    sub rsp, 32
    ; Reserva shadow space.

    call printf
    ; Imprime el mensaje para pedir p.

    add rsp, 32
    ; Libera shadow space.

    ; ------------------------------------------------------------
    ; Leer p
    ; ------------------------------------------------------------

    mov rcx, OFFSET formato_num
    ; Primer argumento de scanf: "%lld".

    mov rdx, QWORD PTR [rbp+16]
    ; Segundo argumento de scanf: dirección donde se guardará p.
    ; [rbp+16] contiene &p.

    sub rsp, 32
    ; Reserva shadow space.

    call scanf
    ; Lee el módulo p.

    add rsp, 32
    ; Libera shadow space.

    leave
    ; Equivale a:
    ; mov rsp, rbp
    ; pop rbp
    ; Restaura el marco de pila anterior.

    ret
    ; Retorna al procedimiento que llamó a leerDatos.

leerDatos ENDP
; Fin del procedimiento leerDatos.


; ------------------------------------------------------------
; imprimirResultado
;
; Imprime el resultado final.
;
; Recibe por pila:
;   [rbp+32] = a
;   [rbp+24] = p
;   [rbp+16] = resultado
; ------------------------------------------------------------

imprimirResultado PROC
; Inicio del procedimiento imprimirResultado.

    push rbp
    ; Guarda el RBP anterior.

    mov  rbp, rsp
    ; Crea el marco de pila del procedimiento.

    and  rsp, -16
    ; Alinea la pila a 16 bytes antes de usar printf.

    mov rcx, OFFSET msg_resultado
    ; Primer argumento de printf: formato del mensaje de resultado.

    mov rdx, QWORD PTR [rbp+32]
    ; Segundo argumento de printf: valor de a.

    mov r8,  QWORD PTR [rbp+24]
    ; Tercer argumento de printf: valor de p.

    mov r9,  QWORD PTR [rbp+16]
    ; Cuarto argumento de printf: resultado o inverso modular.

    sub rsp, 32
    ; Reserva shadow space.

    call printf
    ; Imprime:
    ; "El inverso de a modulo p es: resultado"

    add rsp, 32
    ; Libera shadow space.

    leave
    ; Restaura RSP y RBP.

    ret
    ; Regresa al main.

imprimirResultado ENDP
; Fin del procedimiento imprimirResultado.


; ------------------------------------------------------------
; imprimirError
;
; Imprime el mensaje cuando no hay inverso.
; ------------------------------------------------------------

imprimirError PROC
; Inicio del procedimiento imprimirError.

    push rbp
    ; Guarda el RBP anterior.

    mov  rbp, rsp
    ; Crea un nuevo marco de pila.

    and  rsp, -16
    ; Alinea la pila a 16 bytes.

    mov rcx, OFFSET msg_error
    ; Primer argumento de printf: mensaje de error.

    sub rsp, 32
    ; Reserva shadow space.

    call printf
    ; Imprime que el número no tiene inverso multiplicativo modular.

    add rsp, 32
    ; Libera shadow space.

    leave
    ; Restaura el marco de pila anterior.

    ret
    ; Retorna al main.

imprimirError ENDP
; Fin del procedimiento imprimirError.


; ------------------------------------------------------------
; ajustarPositivo
;
; Este procedimiento toma el valor x que sale del algoritmo extendido
; de Euclides y lo ajusta para que quede positivo.
;
; Recibe por pila:
;   [rbp+32] = x
;   [rbp+24] = p
;   [rbp+16] = dirección donde se guarda el resultado
;
; Objetivo:
;   resultado = x mod p
;
; Si x mod p da negativo, se le suma p.
;
; Esto deja el resultado en el rango:
;
;   0 <= resultado <= p-1
; ------------------------------------------------------------

ajustarPositivo PROC
; Inicio del procedimiento ajustarPositivo.

    push rbp
    ; Guarda RBP anterior.

    mov  rbp, rsp
    ; Crea el marco de pila.

    ; ------------------------------------------------------------
    ; Calcular rdx = x mod p
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp+32]
    ; Carga x en RAX.
    ; En división con signo, el dividendo se coloca en RDX:RAX.

    cqo
    ; Extiende el signo de RAX hacia RDX.
    ; Esto prepara RDX:RAX para una división con signo de 64 bits.

    idiv QWORD PTR [rbp+24]
    ; Divide RDX:RAX entre p.
    ; Cociente queda en RAX.
    ; Residuo queda en RDX.
    ; Es decir:
    ;   RDX = x mod p

    mov rcx, rdx
    ; Copia el residuo a RCX.

    ; ------------------------------------------------------------
    ; Si el residuo es negativo, sumarle p
    ; ------------------------------------------------------------

    cmp rcx, 0
    ; Compara el residuo con cero.

    jge ajustar_fin
    ; Si el residuo es mayor o igual que cero, ya está positivo.
    ; Entonces salta al final.

    add rcx, QWORD PTR [rbp+24]
    ; Si el residuo era negativo, se le suma p.
    ; Ejemplo:
    ;   -3 mod 11 puede salir como -3 en ensamblador.
    ;   Entonces:
    ;   -3 + 11 = 8

ajustar_fin:
    ; Aquí RCX ya contiene el resultado positivo.

    mov rax, QWORD PTR [rbp+16]
    ; Carga en RAX la dirección donde se debe guardar el resultado.

    mov QWORD PTR [rax], rcx
    ; Guarda el resultado positivo en memoria.

    leave
    ; Restaura el marco de pila.

    ret
    ; Retorna al main.

ajustarPositivo ENDP
; Fin del procedimiento ajustarPositivo.


; ============================================================
; PARTE 2 - Cálculo del inverso modular
; ============================================================

; ------------------------------------------------------------
; validarDatos
;
; Revisa si los datos permiten intentar calcular el inverso.
;
; Recibe por pila:
;   [rbp+32] = a
;   [rbp+24] = p
;   [rbp+16] = dirección donde se guarda valido
;
; Salida:
;   valido = 1 si se puede intentar calcular
;   valido = 0 si los datos no sirven
;
; Condiciones:
;   1. p debe ser mayor que 1.
;   2. a no debe ser múltiplo de p.
; ------------------------------------------------------------

validarDatos PROC
; Inicio del procedimiento validarDatos.

    push rbp
    ; Guarda RBP anterior.

    mov  rbp, rsp
    ; Crea el marco de pila.

    ; ------------------------------------------------------------
    ; valido = 0
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp+16]
    ; Carga la dirección de la variable valido.

    mov QWORD PTR [rax], 0
    ; Inicializa valido en 0.
    ; Se asume inválido hasta demostrar lo contrario.

    ; ------------------------------------------------------------
    ; Verificar que p > 1
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp+24]
    ; Carga p en RAX.

    cmp rax, 1
    ; Compara p con 1.

    jle validar_fin
    ; Si p <= 1, no sirve como módulo.
    ; Entonces termina dejando valido = 0.

    ; ------------------------------------------------------------
    ; Verificar si a es múltiplo de p
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp+32]
    ; Carga a en RAX.

    cqo
    ; Extiende el signo de RAX a RDX.
    ; Prepara la división con signo.

    idiv QWORD PTR [rbp+24]
    ; Divide a entre p.
    ; El residuo queda en RDX.

    cmp rdx, 0
    ; Compara el residuo con 0.

    je validar_fin
    ; Si el residuo es 0, entonces a es múltiplo de p.
    ; En ese caso no hay inverso modular.
    ; Se termina dejando valido = 0.

    ; ------------------------------------------------------------
    ; Si pasó las pruebas anteriores, valido = 1
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp+16]
    ; Carga la dirección de valido.

    mov QWORD PTR [rax], 1
    ; Guarda valido = 1.

validar_fin:
    ; Fin de la validación.

    leave
    ; Restaura RSP y RBP.

    ret
    ; Retorna al procedimiento que llamó.

validarDatos ENDP
; Fin del procedimiento validarDatos.


; ------------------------------------------------------------
; euclidesExtendido
;
; Este procedimiento implementa el algoritmo extendido de Euclides.
;
; Calcula x, y y mcd tales que:
;
;   a*x + p*y = mcd(a,p)
;
; Recibe por pila:
;   [rbp+48] = a
;   [rbp+40] = p
;   [rbp+32] = dirección de x
;   [rbp+24] = dirección de y
;   [rbp+16] = dirección de mcd
;
; Variables locales:
;   [rbp-8]  = old_r
;   [rbp-16] = r
;   [rbp-24] = old_s
;   [rbp-32] = s
;   [rbp-40] = old_t
;   [rbp-48] = t
;   [rbp-56] = q
;   [rbp-64] = residuo
;
; Significado de las variables:
;
;   old_r y r:
;       guardan los residuos del algoritmo de Euclides.
;
;   old_s y s:
;       guardan los coeficientes asociados con a.
;       Al final, old_s es x.
;
;   old_t y t:
;       guardan los coeficientes asociados con p.
;       Al final, old_t es y.
;
;   q:
;       cociente de la división old_r / r.
;
;   residuo:
;       residuo de la división old_r mod r.
; ------------------------------------------------------------

euclidesExtendido PROC
; Inicio del procedimiento euclidesExtendido.

    push rbp
    ; Guarda RBP anterior.

    mov  rbp, rsp
    ; Crea el marco de pila.

    sub  rsp, 64
    ; Reserva 64 bytes para variables locales.

    ; ------------------------------------------------------------
    ; Inicialización del algoritmo extendido
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp+48]
    ; Carga a en RAX.

    mov QWORD PTR [rbp-8], rax
    ; old_r = a.

    mov rax, QWORD PTR [rbp+40]
    ; Carga p en RAX.

    mov QWORD PTR [rbp-16], rax
    ; r = p.

    mov QWORD PTR [rbp-24], 1
    ; old_s = 1.
    ; Este coeficiente acompaña inicialmente a a.

    mov QWORD PTR [rbp-32], 0
    ; s = 0.

    mov QWORD PTR [rbp-40], 0
    ; old_t = 0.

    mov QWORD PTR [rbp-48], 1
    ; t = 1.
    ; Este coeficiente acompaña inicialmente a p.

ciclo_euclides:
    ; Inicio del ciclo principal de Euclides extendido.

    cmp QWORD PTR [rbp-16], 0
    ; Compara r con 0.

    je  fin_euclides
    ; Si r == 0, el algoritmo termina.
    ; En ese momento old_r contiene el mcd.

    ; ------------------------------------------------------------
    ; q = old_r / r
    ; residuo = old_r mod r
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp-8]
    ; Carga old_r en RAX.

    cqo
    ; Extiende el signo de RAX hacia RDX.
    ; Prepara RDX:RAX para división con signo.

    idiv QWORD PTR [rbp-16]
    ; Divide old_r entre r.
    ; Cociente queda en RAX.
    ; Residuo queda en RDX.

    mov QWORD PTR [rbp-56], rax
    ; q = cociente.

    mov QWORD PTR [rbp-64], rdx
    ; residuo = residuo de la división.

    ; ------------------------------------------------------------
    ; Actualizar residuos:
    ; (old_r, r) = (r, residuo)
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp-16]
    ; Carga r actual.

    mov QWORD PTR [rbp-8], rax
    ; old_r = r.

    mov rax, QWORD PTR [rbp-64]
    ; Carga residuo.

    mov QWORD PTR [rbp-16], rax
    ; r = residuo.

    ; ------------------------------------------------------------
    ; Actualizar coeficientes s:
    ; nuevo_s = old_s - q*s
    ;
    ; Luego:
    ; old_s = s
    ; s = nuevo_s
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp-56]
    ; Carga q en RAX.

    imul rax, QWORD PTR [rbp-32]
    ; RAX = q * s.

    mov rcx, QWORD PTR [rbp-24]
    ; RCX = old_s.

    sub rcx, rax
    ; RCX = old_s - q*s.
    ; Este es el nuevo valor de s.

    mov rax, QWORD PTR [rbp-32]
    ; Carga s actual en RAX.

    mov QWORD PTR [rbp-24], rax
    ; old_s = s.

    mov QWORD PTR [rbp-32], rcx
    ; s = nuevo_s.

    ; ------------------------------------------------------------
    ; Actualizar coeficientes t:
    ; nuevo_t = old_t - q*t
    ;
    ; Luego:
    ; old_t = t
    ; t = nuevo_t
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp-56]
    ; Carga q en RAX.

    imul rax, QWORD PTR [rbp-48]
    ; RAX = q * t.

    mov rcx, QWORD PTR [rbp-40]
    ; RCX = old_t.

    sub rcx, rax
    ; RCX = old_t - q*t.
    ; Este es el nuevo valor de t.

    mov rax, QWORD PTR [rbp-48]
    ; Carga t actual.

    mov QWORD PTR [rbp-40], rax
    ; old_t = t.

    mov QWORD PTR [rbp-48], rcx
    ; t = nuevo_t.

    jmp ciclo_euclides
    ; Vuelve al inicio del ciclo.

fin_euclides:
    ; El ciclo terminó.
    ; Aquí old_r contiene el mcd.
    ; old_s contiene x.
    ; old_t contiene y.

    ; ------------------------------------------------------------
    ; Ajuste de signo si el mcd sale negativo
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp-8]
    ; Carga old_r, que corresponde al mcd.

    cmp rax, 0
    ; Compara mcd con cero.

    jge guardar_euclides
    ; Si mcd >= 0, no hay que ajustar signo.

    neg rax
    ; Si mcd era negativo, se cambia a positivo.

    mov QWORD PTR [rbp-8], rax
    ; Guarda el mcd positivo.

    neg QWORD PTR [rbp-24]
    ; Cambia el signo de old_s.
    ; Esto mantiene correcta la identidad de Bezout.

    neg QWORD PTR [rbp-40]
    ; Cambia el signo de old_t.

guardar_euclides:
    ; Guarda los resultados finales en las direcciones recibidas.

    mov rax, QWORD PTR [rbp+16]
    ; Carga la dirección donde se debe guardar mcd.

    mov rcx, QWORD PTR [rbp-8]
    ; Carga el mcd calculado.

    mov QWORD PTR [rax], rcx
    ; Guarda mcd en memoria.

    mov rax, QWORD PTR [rbp+32]
    ; Carga la dirección donde se debe guardar x.

    mov rcx, QWORD PTR [rbp-24]
    ; Carga old_s.
    ; old_s es x.

    mov QWORD PTR [rax], rcx
    ; Guarda x en memoria.

    mov rax, QWORD PTR [rbp+24]
    ; Carga la dirección donde se debe guardar y.

    mov rcx, QWORD PTR [rbp-40]
    ; Carga old_t.
    ; old_t es y.

    mov QWORD PTR [rax], rcx
    ; Guarda y en memoria.

    leave
    ; Libera variables locales y restaura RBP.

    ret
    ; Retorna al procedimiento inversoModular.

euclidesExtendido ENDP
; Fin del procedimiento euclidesExtendido.


; ------------------------------------------------------------
; inversoModular
;
; Este procedimiento coordina el cálculo del inverso.
;
; Recibe por pila:
;   [rbp+40] = a
;   [rbp+32] = p
;   [rbp+24] = dirección de x
;   [rbp+16] = dirección de mcd
;
; Variables locales:
;   [rbp-8]  = valido
;   [rbp-16] = y
;
; Funcionamiento:
;   1. Valida los datos.
;   2. Si no son válidos, deja x = 0 y mcd = 0.
;   3. Si son válidos, llama a Euclides extendido.
;   4. Euclides extendido calcula x, y y mcd.
; ------------------------------------------------------------

inversoModular PROC
; Inicio del procedimiento inversoModular.

    push rbp
    ; Guarda RBP anterior.

    mov  rbp, rsp
    ; Crea el marco de pila.

    sub  rsp, 16
    ; Reserva espacio para dos variables locales:
    ; valido y y.

    ; ------------------------------------------------------------
    ; validarDatos(a, p, &valido)
    ; ------------------------------------------------------------

    push QWORD PTR [rbp+40]
    ; Pasa a.

    push QWORD PTR [rbp+32]
    ; Pasa p.

    lea rax, [rbp-8]
    ; Carga la dirección de valido.

    push rax
    ; Pasa &valido.

    call validarDatos
    ; Llama al procedimiento que revisa si los datos sirven.

    add  rsp, 24
    ; Limpia 3 parámetros de la pila.
    ; 3 * 8 = 24 bytes.

    cmp QWORD PTR [rbp-8], 1
    ; Compara valido con 1.

    je  calcular_inverso
    ; Si valido == 1, se puede calcular el inverso.
    ; Salta a calcular_inverso.

    ; ------------------------------------------------------------
    ; Caso inválido
    ; ------------------------------------------------------------

    mov rax, QWORD PTR [rbp+24]
    ; Carga la dirección de x.

    mov QWORD PTR [rax], 0
    ; x = 0.

    mov rax, QWORD PTR [rbp+16]
    ; Carga la dirección de mcd.

    mov QWORD PTR [rax], 0
    ; mcd = 0.
    ; Esto hará que main detecte que no existe inverso.

    jmp fin_inverso
    ; Salta al final del procedimiento.

calcular_inverso:
    ; ------------------------------------------------------------
    ; euclidesExtendido(a, p, &x, &y, &mcd)
    ; ------------------------------------------------------------

    push QWORD PTR [rbp+40]
    ; Pasa a.

    push QWORD PTR [rbp+32]
    ; Pasa p.

    mov rax, QWORD PTR [rbp+24]
    ; Carga la dirección de x.

    push rax
    ; Pasa &x.

    lea rax, [rbp-16]
    ; Carga la dirección de la variable local y.

    push rax
    ; Pasa &y.
    ; y se calcula pero no se imprime.

    mov rax, QWORD PTR [rbp+16]
    ; Carga la dirección de mcd.

    push rax
    ; Pasa &mcd.

    call euclidesExtendido
    ; Ejecuta el algoritmo extendido de Euclides.

    add  rsp, 40
    ; Limpia 5 parámetros de la pila.
    ; 5 * 8 = 40 bytes.

fin_inverso:
    ; Final del procedimiento inversoModular.

    leave
    ; Libera las variables locales y restaura RBP.

    ret
    ; Retorna al main.

inversoModular ENDP
; Fin del procedimiento inversoModular.

END
; Fin del archivo ensamblador.
