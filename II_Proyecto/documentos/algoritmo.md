# Algoritmo - Proyecto 2

## Problema

Calcular la distancia de Frobenius entre dos matrices `A` y `B` de `3x3`.

La distancia se calcula como:

```text
d(A, B) = ||A - B||_F
        = sqrt( sum_i sum_j |a_ij - b_ij|^2 )
```

## Algoritmo general

```text
1. Solicitar al usuario los 9 valores de la matriz A.
2. Solicitar al usuario los 9 valores de la matriz B.
3. Guardar cada fila con padding:
   [x1, x2, x3, 0.0]
4. Para cada fila:
   4.1 Cargar una fila de A en un registro YMM.
   4.2 Cargar una fila de B en otro registro YMM.
   4.3 Calcular la diferencia empaquetada A - B con vsubpd.
   4.4 Guardar la diferencia para poder mostrarla.
   4.5 Calcular el valor absoluto con vandpd y una máscara.
   4.6 Elevar al cuadrado cada diferencia absoluta con vmulpd.
   4.7 Acumular los cuadrados con vaddpd.
5. Reducir las sumas parciales del vector acumulador.
6. Calcular la raíz cuadrada de la suma total.
7. Mostrar la matriz diferencia y la distancia final.
```

## Pseudocódigo

```text
leer A[3][3]
leer B[3][3]

sumaTotal = 0

para i = 0 hasta 2:
    vectorA = [A[i][0], A[i][1], A[i][2], 0.0]
    vectorB = [B[i][0], B[i][1], B[i][2], 0.0]

    diferencia = vectorA - vectorB             // AVX: vsubpd
    diferenciaAbs = abs(diferencia)            // AVX: vandpd con máscara
    cuadrados = diferenciaAbs * diferenciaAbs  // AVX: vmulpd

    sumaTotal += suma(cuadrados)

resultado = sqrt(sumaTotal)
mostrar resultado
```

## Nota sobre el valor absoluto

Para números IEEE 754, el signo está en el bit más significativo. Por eso, el valor absoluto puede obtenerse apagando ese bit con una máscara:

```text
abs(x) = x AND 0x7FFFFFFFFFFFFFFF
```

En la implementación con doubles, se usa esa máscara en cada lane del registro `YMM`.
