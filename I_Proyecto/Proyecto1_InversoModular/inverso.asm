; ============================================================
; Proyecto 1 - Inverso Multiplicativo Modular
; IC-3101 Arquitectura de Computadores
;
; Programa en ensamblador x86-64 con MASM.
; Lee dos enteros: a y p.
; Calcula el inverso multiplicativo modular de a modulo p.
;
; Si mcd(a,p) = 1, existe inverso.
; Si mcd(a,p) != 1, no existe inverso.
;
; Se usa el algoritmo extendido de Euclides.
; Los parametros entre procedimientos se pasan por la pila.
;
; Integrantes del proyecto:
; - Julio Quirós Vargas
; - Fabiola González Gómez
; - Angie Alpizar Porras
; - José Gabriel Marín Aguilar
; ============================================================

option casemap:none

includelib ucrt.lib
includelib vcruntime.lib
includelib legacy_stdio_definitions.lib
includelib kernel32.lib

EXTERN printf:PROC
EXTERN scanf:PROC
EXTERN ExitProcess:PROC

PUBLIC main

.data
msg_pedir_a    db "Ingrese el numero a: ", 0
msg_pedir_p    db "Ingrese el modulo p: ", 0
formato_num    db "%lld", 0

msg_resultado  db "El inverso de %lld modulo %lld es: %lld", 13, 10, 0
msg_error      db "El numero no tiene inverso multiplicativo modular", 13, 10, 0


.code

; ============================================================
; PARTE 1 - Entrada, salida y control general
; ============================================================

; ------------------------------------------------------------
; main
; Variables locales:
;   [rbp-8]  = a
;   [rbp-16] = p
;   [rbp-24] = x
;   [rbp-32] = mcd
;   [rbp-40] = resultado
; ------------------------------------------------------------
main PROC
    push rbp
    mov  rbp, rsp
    sub  rsp, 80

    ; leerDatos(&a, &p)
    lea rax, [rbp-8]
    push rax

    lea rax, [rbp-16]
    push rax

    call leerDatos
    add  rsp, 16

    ; inversoModular(a, p, &x, &mcd)
    push QWORD PTR [rbp-8]
    push QWORD PTR [rbp-16]

    lea rax, [rbp-24]
    push rax

    lea rax, [rbp-32]
    push rax

    call inversoModular
    add  rsp, 32

    ; si mcd != 1, no existe inverso
    mov rax, QWORD PTR [rbp-32]
    cmp rax, 1
    jne main_no_existe

    ; ajustarPositivo(x, p, &resultado)
    push QWORD PTR [rbp-24]
    push QWORD PTR [rbp-16]

    lea rax, [rbp-40]
    push rax

    call ajustarPositivo
    add  rsp, 24

    ; imprimirResultado(a, p, resultado)
    push QWORD PTR [rbp-8]
    push QWORD PTR [rbp-16]
    push QWORD PTR [rbp-40]

    call imprimirResultado
    add  rsp, 24

    jmp main_fin

main_no_existe:
    call imprimirError

main_fin:
    ; Finalizar programa
    xor ecx, ecx
    call ExitProcess

main ENDP


; ------------------------------------------------------------
; leerDatos
; Recibe por pila:
;   [rbp+24] = direccion donde se guarda a
;   [rbp+16] = direccion donde se guarda p
; ------------------------------------------------------------
leerDatos PROC
    push rbp
    mov  rbp, rsp
    and  rsp, -16

    ; Mostrar mensaje para a
    mov rcx, OFFSET msg_pedir_a
    sub rsp, 32
    call printf
    add rsp, 32

    ; Leer a
    mov rcx, OFFSET formato_num
    mov rdx, QWORD PTR [rbp+24]
    sub rsp, 32
    call scanf
    add rsp, 32

    ; Mostrar mensaje para p
    mov rcx, OFFSET msg_pedir_p
    sub rsp, 32
    call printf
    add rsp, 32

    ; Leer p
    mov rcx, OFFSET formato_num
    mov rdx, QWORD PTR [rbp+16]
    sub rsp, 32
    call scanf
    add rsp, 32

    leave
    ret
leerDatos ENDP


; ------------------------------------------------------------
; imprimirResultado
; Recibe por pila:
;   [rbp+32] = a
;   [rbp+24] = p
;   [rbp+16] = resultado
; ------------------------------------------------------------
imprimirResultado PROC
    push rbp
    mov  rbp, rsp
    and  rsp, -16

    mov rcx, OFFSET msg_resultado
    mov rdx, QWORD PTR [rbp+32]     ; a
    mov r8,  QWORD PTR [rbp+24]     ; p
    mov r9,  QWORD PTR [rbp+16]     ; resultado

    sub rsp, 32
    call printf
    add rsp, 32

    leave
    ret
imprimirResultado ENDP


; ------------------------------------------------------------
; imprimirError
; Imprime el mensaje cuando no hay inverso.
; ------------------------------------------------------------
imprimirError PROC
    push rbp
    mov  rbp, rsp
    and  rsp, -16

    mov rcx, OFFSET msg_error

    sub rsp, 32
    call printf
    add rsp, 32

    leave
    ret
imprimirError ENDP


; ------------------------------------------------------------
; ajustarPositivo
; Recibe por pila:
;   [rbp+32] = x
;   [rbp+24] = p
;   [rbp+16] = direccion donde se guarda el resultado
;
; Deja el resultado en el rango 0..p-1
; ------------------------------------------------------------
ajustarPositivo PROC
    push rbp
    mov  rbp, rsp

    ; rdx = x mod p
    mov rax, QWORD PTR [rbp+32]
    cqo
    idiv QWORD PTR [rbp+24]

    mov rcx, rdx

    ; Si el residuo es negativo, se le suma p
    cmp rcx, 0
    jge ajustar_fin

    add rcx, QWORD PTR [rbp+24]

ajustar_fin:
    mov rax, QWORD PTR [rbp+16]
    mov QWORD PTR [rax], rcx

    leave
    ret
ajustarPositivo ENDP


; ============================================================
; PARTE 2 - Calculo del inverso modular
; ============================================================

; ------------------------------------------------------------
; validarDatos
; Recibe por pila:
;   [rbp+32] = a
;   [rbp+24] = p
;   [rbp+16] = direccion donde se guarda valido
;
; valido = 1 si se puede intentar calcular
; valido = 0 si los datos no sirven
; ------------------------------------------------------------
validarDatos PROC
    push rbp
    mov  rbp, rsp

    ; valido = 0
    mov rax, QWORD PTR [rbp+16]
    mov QWORD PTR [rax], 0

    ; p debe ser mayor que 1
    mov rax, QWORD PTR [rbp+24]
    cmp rax, 1
    jle validar_fin

    ; Si a es multiplo de p, no hay inverso
    mov rax, QWORD PTR [rbp+32]
    cqo
    idiv QWORD PTR [rbp+24]

    cmp rdx, 0
    je validar_fin

    ; valido = 1
    mov rax, QWORD PTR [rbp+16]
    mov QWORD PTR [rax], 1

validar_fin:
    leave
    ret
validarDatos ENDP


; ------------------------------------------------------------
; euclidesExtendido
;
; Calcula x, y y mcd:
;   a*x + p*y = mcd(a,p)
;
; Recibe por pila:
;   [rbp+48] = a
;   [rbp+40] = p
;   [rbp+32] = direccion de x
;   [rbp+24] = direccion de y
;   [rbp+16] = direccion de mcd
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
; ------------------------------------------------------------
euclidesExtendido PROC
    push rbp
    mov  rbp, rsp
    sub  rsp, 64

    ; old_r = a
    mov rax, QWORD PTR [rbp+48]
    mov QWORD PTR [rbp-8], rax

    ; r = p
    mov rax, QWORD PTR [rbp+40]
    mov QWORD PTR [rbp-16], rax

    ; old_s = 1, s = 0
    mov QWORD PTR [rbp-24], 1
    mov QWORD PTR [rbp-32], 0

    ; old_t = 0, t = 1
    mov QWORD PTR [rbp-40], 0
    mov QWORD PTR [rbp-48], 1

ciclo_euclides:
    cmp QWORD PTR [rbp-16], 0
    je  fin_euclides

    ; q = old_r / r
    ; residuo = old_r mod r
    mov rax, QWORD PTR [rbp-8]
    cqo
    idiv QWORD PTR [rbp-16]

    mov QWORD PTR [rbp-56], rax
    mov QWORD PTR [rbp-64], rdx

    ; (old_r, r) = (r, residuo)
    mov rax, QWORD PTR [rbp-16]
    mov QWORD PTR [rbp-8], rax

    mov rax, QWORD PTR [rbp-64]
    mov QWORD PTR [rbp-16], rax

    ; nuevo_s = old_s - q*s
    mov rax, QWORD PTR [rbp-56]
    imul rax, QWORD PTR [rbp-32]

    mov rcx, QWORD PTR [rbp-24]
    sub rcx, rax

    mov rax, QWORD PTR [rbp-32]
    mov QWORD PTR [rbp-24], rax

    mov QWORD PTR [rbp-32], rcx

    ; nuevo_t = old_t - q*t
    mov rax, QWORD PTR [rbp-56]
    imul rax, QWORD PTR [rbp-48]

    mov rcx, QWORD PTR [rbp-40]
    sub rcx, rax

    mov rax, QWORD PTR [rbp-48]
    mov QWORD PTR [rbp-40], rax

    mov QWORD PTR [rbp-48], rcx

    jmp ciclo_euclides

fin_euclides:
    ; Si el mcd sale negativo, se ajusta el signo
    mov rax, QWORD PTR [rbp-8]
    cmp rax, 0
    jge guardar_euclides

    neg rax
    mov QWORD PTR [rbp-8], rax

    neg QWORD PTR [rbp-24]
    neg QWORD PTR [rbp-40]

guardar_euclides:
    ; Guardar mcd
    mov rax, QWORD PTR [rbp+16]
    mov rcx, QWORD PTR [rbp-8]
    mov QWORD PTR [rax], rcx

    ; Guardar x
    mov rax, QWORD PTR [rbp+32]
    mov rcx, QWORD PTR [rbp-24]
    mov QWORD PTR [rax], rcx

    ; Guardar y
    mov rax, QWORD PTR [rbp+24]
    mov rcx, QWORD PTR [rbp-40]
    mov QWORD PTR [rax], rcx

    leave
    ret
euclidesExtendido ENDP


; ------------------------------------------------------------
; inversoModular
; Recibe por pila:
;   [rbp+40] = a
;   [rbp+32] = p
;   [rbp+24] = direccion de x
;   [rbp+16] = direccion de mcd
;
; Variables locales:
;   [rbp-8]  = valido
;   [rbp-16] = y
; ------------------------------------------------------------
inversoModular PROC
    push rbp
    mov  rbp, rsp
    sub  rsp, 16

    ; validarDatos(a, p, &valido)
    push QWORD PTR [rbp+40]
    push QWORD PTR [rbp+32]

    lea rax, [rbp-8]
    push rax

    call validarDatos
    add  rsp, 24

    cmp QWORD PTR [rbp-8], 1
    je  calcular_inverso

    ; Si no es valido, mcd = 0
    mov rax, QWORD PTR [rbp+24]
    mov QWORD PTR [rax], 0

    mov rax, QWORD PTR [rbp+16]
    mov QWORD PTR [rax], 0

    jmp fin_inverso

calcular_inverso:
    ; euclidesExtendido(a, p, &x, &y, &mcd)
    push QWORD PTR [rbp+40]
    push QWORD PTR [rbp+32]

    mov rax, QWORD PTR [rbp+24]
    push rax

    lea rax, [rbp-16]
    push rax

    mov rax, QWORD PTR [rbp+16]
    push rax

    call euclidesExtendido
    add  rsp, 40

fin_inverso:
    leave
    ret
inversoModular ENDP

END