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
; - Agregar este archivo .asm como