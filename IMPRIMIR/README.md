# Métodos para imprimir imágenes en ESC/POS

Cuando trabajas con impresoras térmicas ESC/POS (como la Sanei SM1-21), existen **dos formas distintas** de enviar imágenes. No son equivalentes: cada una organiza los datos de forma radicalmente diferente.

---

## Tabla comparativa rápida

| Característica | ESC * | GS v 0 |
|:---|:---|:---|
| Persistencia | Se pierde tras imprimir | Guardada en memoria |
| Reutilización | Reenviar todo cada vez | Un comando de 3 bytes |
| Formato de datos | Vertical (columnas) | Horizontal (filas) |
| Complejidad | Alta | Baja |
| Ideal para | Gráficos dinámicos | Logos fijos |

---

##  Método 1: ESC * — Imagen directa (clásico)

Imprime en el momento **sin almacenar** nada en la impresora.

### Ejemplo de llamada (BASIC)

```basic
' ESC * modo 0 (8-dot single density)
' nl=16, nh=0 → 16 columnas de 8 píxeles
PRINT#1, CHR$(&H1B);"*";CHR$(0);CHR$(16);CHR$(0);
' Seguido de los datos verticales (32 bytes para 16×16)
```

Los datos se organizan en **columnas verticales de 8 píxeles**: el primer byte representa los bits 0-7 de la columna 1, el segundo byte los bits 0-7 de la columna 2, etc.
Se necesita ordenar los datos con la aplicacion  ORDENAR_ESC.C

> **⚠️ Importante:** La utilidad `ORDENAR_ESC.C` ordena los datos en formato vertical para que la imagen sea visible correctamente con este comando.


## Método 2: GS v 0 — Imagen descargada (moderno)

Guarda la imagen en **memoria interna** y luego la imprime cuando quieras.

### Ejemplo de llamada (BASIC)

```basic
' GS * — Descargar imagen 16×16 (n1=2 bytes, n2=16 filas)
PRINT#1, CHR$(&H1D);"*";CHR$(2);CHR$(16);
' ... 32 bytes de datos horizontales ...

' GS / — Imprimir imagen descargada (m=0 normal)
PRINT#1, CHR$(&H1D);"/";CHR$(0);
```

Los datos se organizan en **filas horizontales**: byte 1 = píxeles 0-7 de la fila 1, byte 2 = píxeles 8-15 de la fila 1, etc.

> **✅ Ventaja:** No necesita conversión previa. Los arrays en formato bitmap horizontal (estándar C/XBM) funcionan directamente.


### Ventajas

- ✅ Compatible con impresoras antiguas
- ✅ Muy flexible
- ✅ Bueno para gráficos pequeños
- ✅ Poco buffer interno

### Desventajas

- ❌ Datos verticales
- ❌ Conversión complicada — **requiere `ORDENAR_ESC.C` para reorganizar datos**
- ❌ Imágenes giradas fácilmente
- ❌ Malo para BASIC lento
- ❌ Difícil con arrays C/XBM

---

## GS v 0

### Ventajas

- ✅ Usa bitmap normal (formato horizontal estándar)
- ✅ Compatible con tus arrays actuales (sin conversión)
- ✅ Muchísimo más fácil
- ✅ Perfecto para logos/imágenes
- ✅ Ideal para BASIC
- ✅ Sin rotaciones

### Desventajas

- ⚠️ Algunas impresoras muy antiguas no lo soportan
- ⚠️ Usa más buffer RAM
- ⚠️ Menos "retro compatible"

---

*Basado en el manual de comandos Mobile Printer BLM-80/SM1-21/SM2-41/SM3-21 Rev.3.1J*
