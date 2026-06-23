# Guía de defensa - Proyecto 2: Distancia de Frobenius con AVX

## 1. Objetivo del proyecto

El proyecto consiste en implementar en ensamblador MASM x64 un programa que calcule la distancia de Frobenius entre dos matrices `A` y `B` de tamaño `3x3`.

La fórmula usada es:

```text
d(A, B) = ||A - B||_F
        = sqrt( sumatoria de |a_ij - b_ij|^2 )
```

En palabras simples:

1. Se leen dos matrices `A` y `B` de `3x3`.
2. Se calcula la matriz diferencia `D = A - B`.
3. Se toma el valor absoluto de cada elemento de `D`.
4. Se eleva cada elemento al cuadrado.
5. Se suman todos los cuadrados.
6. Se calcula la raíz cuadrada de esa suma.
7. Se muestra el resultado en consola.

## 2. Requisitos importantes del enunciado

Los puntos más importantes que se deben poder defender son:

- El programa debe pedir al usuario los valores de las dos matrices.
- El resultado debe mostrarse en consola.
- La diferencia matricial debe calcularse usando aritmética empacada AVX.
- El valor absoluto debe calcularse usando una instrucción `AND` empacada.
- Se puede usar precisión simple o doble.
- Se pueden agregar ceros de relleno porque cada fila real tiene solo 3 elementos.
- Para este proyecto no era necesario dividir el código en módulos.

## 3. Tipo de dato usado

La implementación usa precisión doble, es decir, valores `REAL8` de 64 bits.

Por eso se usan instrucciones con sufijo `pd` o `sd`:

- `pd` significa packed double, es decir, doubles empaquetados.
- `sd` significa scalar double, es decir, un double escalar.

Un registro `YMM` tiene 256 bits. Como cada `double` ocupa 64 bits:

```text
256 / 64 = 4 doubles por registro YMM
```

Por eso cada operación empacada puede trabajar con 4 valores `double` al mismo tiempo.

## 4. Diseño de memoria de las matrices

Aunque las matrices son de `3x3`, internamente cada fila se guarda con 4 elementos:

```text
Fila real:       [x1, x2, x3]
Fila en memoria: [x1, x2, x3, 0.0]
```

Ese cuarto valor es padding o relleno.

La razón es que cada fila ocupa exactamente 4 doubles:

```text
4 doubles x 8 bytes = 32 bytes
```

Entonces cada fila cabe exactamente en un registro `YMM`.

La matriz completa se guarda así:

```text
Fila 1: elementos 0, 1, 2, padding
Fila 2: elementos 4, 5, 6, padding
Fila 3: elementos 8, 9, 10, padding
```

Por eso cada matriz reserva 12 valores:

```asm
MatrizA REAL8 12 DUP(0.0)
MatrizB REAL8 12 DUP(0.0)
```

El padding no altera el resultado porque siempre vale `0.0`, y al hacer la diferencia entre paddings se obtiene:

```text
0.0 - 0.0 = 0.0
```

Al elevarlo al cuadrado, sigue aportando cero a la suma final.

## 5. Entrada de datos

El programa usa `printf` para mostrar mensajes y `scanf` para leer valores `double`.

Formato usado para leer:

```asm
fmtScan db "%lf", 0
```

`%lf` indica que se leerá un número de punto flotante de doble precisión.

Para calcular dónde guardar cada valor se usa el offset:

```text
offset = (fila * 4 + columna) * 8
```

Se multiplica por 4 porque cada fila interna tiene 4 posiciones, no 3. Se multiplica por 8 porque cada `REAL8` ocupa 8 bytes.

## 6. Cálculo de la matriz diferencia

La diferencia se calcula fila por fila usando AVX empacado.

Ejemplo conceptual de una fila:

```text
A_fila = [a1, a2, a3, 0.0]
B_fila = [b1, b2, b3, 0.0]
D_fila = [a1-b1, a2-b2, a3-b3, 0.0]
```

La instrucción principal es:

```asm
vsubpd ymm2, ymm0, ymm1
```

Esto significa:

```text
ymm2 = ymm0 - ymm1
```

Como `ymm0` contiene una fila de `A` y `ymm1` contiene una fila de `B`, la instrucción calcula 4 restas en paralelo.

Este punto es importante porque cumple el requisito de usar instrucciones empacadas para la diferencia matricial.

## 7. Valor absoluto con AND empacado

El valor absoluto se calcula con:

```asm
vandpd ymm3, ymm2, ymmword ptr [AbsMask]
```

La idea es que en IEEE 754 el bit más significativo representa el signo. Para obtener el valor absoluto basta con apagar ese bit de signo.

La máscara usada es:

```asm
AbsMask QWORD 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh, 07FFFFFFFFFFFFFFFh
```

Cada elemento de la máscara tiene todos los bits en 1 excepto el bit de signo. Entonces:

```text
abs(x) = x AND 0x7FFFFFFFFFFFFFFF
```

Como se usa `vandpd`, el AND se aplica de forma empacada a los 4 doubles del registro.

Este punto es importante porque cumple el requisito de usar una instrucción `AND` empacada para el valor absoluto.

## 8. Cuadrados y acumulación

Después de tener el valor absoluto de la diferencia, cada elemento se eleva al cuadrado con:

```asm
vmulpd ymm3, ymm3, ymm3
```

Esto multiplica cada lane por sí mismo:

```text
[x1, x2, x3, 0.0] * [x1, x2, x3, 0.0]
= [x1^2, x2^2, x3^2, 0.0]
```

Luego se acumulan las sumas parciales en `ymm6`:

```asm
vaddpd ymm6, ymm6, ymm3
```

`ymm6` funciona como acumulador vectorial. Después de procesar las tres filas, contiene sumas parciales por lane.

## 9. Reducción final y raíz cuadrada

Al final, las sumas parciales de `ymm6` se guardan en memoria temporal:

```asm
vmovupd ymmword ptr [TempSums], ymm6
```

Luego se suman de forma escalar:

```asm
vmovsd xmm0, real8 ptr [TempSums]
vaddsd xmm0, xmm0, real8 ptr [TempSums + 8]
vaddsd xmm0, xmm0, real8 ptr [TempSums + 16]
vaddsd xmm0, xmm0, real8 ptr [TempSums + 24]
```

Después se calcula la raíz cuadrada:

```asm
vsqrtsd xmm0, xmm0, xmm0
```

Ese resultado es la distancia de Frobenius.

## 10. Instrucciones AVX usadas

| Instrucción | Uso en el programa |
|---|---|
| `vmovupd` | Cargar/guardar vectores de doubles no necesariamente alineados. |
| `vsubpd` | Calcular la diferencia empacada `A - B`. |
| `vandpd` | Calcular valor absoluto apagando el bit de signo. |
| `vmulpd` | Elevar al cuadrado cada diferencia. |
| `vaddpd` | Acumular sumas parciales por lane. |
| `vmovsd` | Mover un double escalar. |
| `vaddsd` | Sumar doubles escalares en la reducción final. |
| `vsqrtsd` | Calcular la raíz cuadrada final. |
| `vzeroupper` | Limpiar la parte alta de registros YMM antes de salir. |

## 11. Caso de prueba principal

Caso del enunciado:

```text
A =
[ 4   71   12  ]
[ 81  82   84  ]
[ 6   22   140 ]

B =
[ 3   14   15 ]
[ 9   26   53 ]
[ 5   89   79 ]
```

La diferencia esperada es:

```text
A - B =
[ 1   57   -3 ]
[ 72  56   31 ]
[ 1  -67   61 ]
```

La suma de cuadrados es:

```text
1^2 + 57^2 + (-3)^2 + 72^2 + 56^2 + 31^2 + 1^2 + (-67)^2 + 61^2
= 20751
```

La distancia esperada es:

```text
sqrt(20751) ≈ 144.052074
```

## 12. Preguntas probables de defensa

### ¿Qué es la distancia de Frobenius?

Es la distancia entre dos matrices calculada como la norma de la matriz diferencia. Primero se calcula `A - B`, luego se elevan al cuadrado todos sus elementos, se suman y se obtiene la raíz cuadrada.

### ¿Por qué se usa AVX?

Porque AVX permite ejecutar una misma operación sobre varios datos al mismo tiempo. En este caso, cada fila se procesa como un vector de 4 doubles.

### ¿Qué significa que la operación sea empacada?

Significa que un registro contiene varios valores y una sola instrucción opera sobre todos esos valores en paralelo.

### ¿Por qué las matrices tienen 12 espacios si son de 3x3?

Porque se agrega un cuarto valor de padding por fila. Así cada fila tiene 4 doubles y cabe exactamente en un registro `YMM` de 256 bits.

### ¿Por qué el padding no cambia el resultado?

Porque el padding es `0.0` en ambas matrices. Entonces su diferencia es `0.0`, su valor absoluto es `0.0`, y su cuadrado también es `0.0`.

### ¿Dónde se cumple el requisito de diferencia empacada?

En las instrucciones `vsubpd`, que calculan la diferencia entre filas de `A` y `B` usando registros YMM.

### ¿Dónde se cumple el requisito de valor absoluto con AND?

En las instrucciones `vandpd`, usando la máscara `AbsMask` para apagar el bit de signo de cada double.

### ¿Por qué no se usaron módulos?

Porque el enunciado del Proyecto 2 indica que para este proyecto no era necesario usar módulos. El objetivo principal era demostrar uso de AVX empacado.

### ¿Por qué se usó precisión doble?

Porque el enunciado permite precisión simple o doble. Se eligió doble precisión para trabajar con `REAL8` y registros `YMM` que procesan 4 doubles por instrucción.

### ¿Qué parte del programa muestra que el resultado es correcto?

El programa imprime la matriz diferencia y la distancia final. Además, el caso del enunciado produce aproximadamente `144.052074`, que coincide con `sqrt(20751)`.

## 13. Errores comunes que conviene saber explicar

- Confundir `vsubpd` con una resta escalar. `vsubpd` resta varios doubles en paralelo.
- Olvidar que cada fila tiene padding y por eso ocupa 32 bytes.
- Pensar que el valor absoluto se calcula con una comparación. Aquí se calcula con `AND`, apagando el bit de signo.
- Usar `vmovapd` sin garantizar alineación. Esta implementación usa `vmovupd`, que no exige alineación.
- Confundir la matriz diferencia con la matriz de valores absolutos. El programa guarda ambas: `MatrizD` y `MatrizAbs`.
- Olvidar que la raíz cuadrada se calcula después de sumar todos los cuadrados.

## 14. Resumen corto para responder en defensa

El programa lee dos matrices `3x3`, las guarda internamente como filas de 4 doubles con un cero de padding, y procesa cada fila con registros `YMM`. La diferencia `A - B` se calcula con `vsubpd`, el valor absoluto se obtiene con `vandpd` y una máscara que apaga el bit de signo, luego los valores se elevan al cuadrado con `vmulpd`, se acumulan con `vaddpd`, se reduce la suma a un escalar y finalmente se calcula la raíz cuadrada con `vsqrtsd`. El resultado mostrado es la distancia de Frobenius.
