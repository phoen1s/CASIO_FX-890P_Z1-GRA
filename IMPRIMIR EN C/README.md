# 🖨️ Utilidades Gráficas FX-DOS

> Colección de utilidades para MS-DOS y FX-DOS para procesar, convertir e imprimir imágenes sprite en el **CASIO FX-890P/Z-1** y sistemas compatibles.

<p align="center">
  <a href="https://www.youtube.com/watch?v=IRTzOmUaizQ">
    <img src="https://img.youtube.com/vi/IRTzOmUaizQ/0.jpg" alt="Video demo en YouTube" width="480">
  </a>
  <br>
  <em>🎥 Haz clic en la imagen para ver el video</em>
</p>

---

## 📋 Tabla de Contenidos

- [Visión General](#visión-general)
- [Programas](#programas)
  - [ORDENAR_ESC](#-ordenar_esc)
  - [CREAR_BINARIO](#-crear_binario)
  - [IMP_GS_FILE_BIN](#-imp_gs_file_bin)
  - [IMP_ESC_FILE_BIN](#-imp_esc_file_bin)
- [Aplicación macOS](#-esc_gs_serialapp)
- [Flujo de Trabajo](#flujo-de-trabajo)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Licencia](#licencia)

---

## Visión General

Este proyecto proporciona un conjunto de herramientas completas para el manejo de sprites gráficos en entornos de bajo nivel. Cubre todo el pipeline desde el **procesamiento de datos sprite** hasta la **impresión física** en la impresora **SM1-21**, incluyendo una **aplicación complementaria para macOS** para visualización a través del puerto serie.

Todas las herramientas están diseñadas específicamente para:
- **FX-DOS** en el **CASIO FX-890P/Z-1**
- Sistemas compatibles con MS-DOS
- Rutinas gráficas raster y de imagen de bits a bajo nivel

---

## Programas

### 🔧 ORDENAR_ESC

**Función:** Utilidad en MSDOS que procesa y reordena los datos de imagen de archivos `SPRITE.H` para su correcta interpretación.

Al trabajar con impresión mediante secuencias de escape, las estructuras de datos de imagen requieren un reordenamiento específico. `ORDENAR_ESC` realiza esta reorganización obligatoria.

#### Archivos de Salida

| Archivo | Descripción |
|---------|-------------|
| `SPRITE.H` | Versión reordenada del archivo original, lista para integrarse en proyectos o rutinas gráficas en FX-DOS |
| `SPRITE.BIN` | Datos de imagen en formato bruto, optimizado para uso directo en modo **ESC * (Bit Image)** |

> ⚠️ **IMPORTANTE:** La ejecución de `ORDENAR_ESC` es **obligatoria** cuando se desean utilizar imágenes en modo **ESC * (Bit Image)**. Omitir este paso puede provocar estructuras de imagen no válidas, causando distorsión, errores de representación o resultados impredecibles en pantalla o impresora.

---

### 🔧 CREAR_BINARIO

**Función:**  Utilidad en MSDOS que convierte un archivo de imagen `SPRITE.H` en un archivo binario (`SPRITE.BIN`).

A diferencia de `ORDENAR_ESC`, esta utilidad **no modifica ni reordena** el contenido. Realiza una conversión directa a formato binario, preservando la estructura original de los datos.

#### Archivo de Salida

| Archivo | Descripción |
|---------|-------------|
| `SPRITE.BIN` | Datos de imagen en formato binario para uso con comandos **GS * (Raster Graphics)** |

Este proceso permite optimizar la transferencia de datos y asegurar la compatibilidad.

---

### 🖨️ IMP_GS_FILE_BIN

**Función:** Imprime archivos de imagen binarios usando el modo **GS (Raster Graphics)** a través del puerto serie **COM** hacia la impresora **SM1-21**.

Desarrollado en **C89** para sistemas FX-DOS.

#### Requisitos
- El archivo `SPRITE.BIN` debe haber sido generado previamente con **[CREAR_BINARIO](#-crear_binario)**
- `SPRITE.BIN` debe estar almacenado en el CASIO FX-890P/Z-1 o en un dispositivo compatible con FX-DOS

#### Flujo
```
SPRITE.H → [CREAR_BINARIO] → SPRITE.BIN → [IMP_GS_FILE_BIN] → Impresora (Modo GS)
```

---

### 🖨️ IMP_ESC_FILE_BIN

**Función:** Imprime archivos de imagen binarios usando el modo **ESC * (Bit Image)** a través del puerto serie **COM** hacia la impresora **SM1-21**.

Desarrollado en **C89** para sistemas FX-DOS.

#### Requisitos
- El archivo `SPRITE.BIN` debe haber sido generado previamente con **[ORDENAR_ESC](#-ordenar_esc)**
- `SPRITE.BIN` debe estar almacenado en el CASIO FX-890P/Z-1 o en un entorno compatible con FX-DOS

#### Flujo
```
SPRITE.H → [ORDENAR_ESC] → SPRITE.BIN → [IMP_ESC_FILE_BIN] → Impresora (Modo ESC *)
```

---

## 🍎 ESC_GS_SERIAL.APP

**Función:** Aplicación en **Python** para **macOS** (incluyendo Apple Silicon M3) que recibe y muestra imágenes enviadas desde el CASIO FX-890P/Z-1 a través del puerto serie.

Esta aplicación actúa como un **receptor gráfico moderno** entre el entorno retro FX-DOS y sistemas macOS contemporáneos, permitiendo:
- Visualización de imágenes
- Depuración y validación de datos serie
- Detección automática de formato

#### Formatos Soportados

| Formato | Descripción |
|---------|-------------|
| **ESC *** | Modo Gráfico de Bits |
| **GS *** | Modo Raster Graphics |

Al recibir los datos, la aplicación detecta automáticamente el formato, interpreta correctamente la imagen y la muestra en pantalla en tiempo real.

---

## Flujo de Trabajo

### Pipeline ESC * (Gráfico de Bits)
```
┌───────────┐     ┌─────────────┐     ┌──────────────┐     ┌──────────┐
│ SPRITE.H  │────→│ ORDENAR_ESC │────→│ SPRITE.BIN   │────→│ IMP_ESC_ │────→ Impresora SM1-21
│ (origen)  │     │ (reordenar) │     │ (binario)    │     │ FILE_BIN │      (Modo ESC *)
└───────────┘     └─────────────┘     └──────────────┘     └──────────┘
                                              │
                                              ▼
                                    ┌─────────────────┐
                                    │ ESC_GS_SERIAL   │
                                    │ (visor macOS)   │
                                    └─────────────────┘
```

### Pipeline GS * (Raster Graphics)
```
┌───────────┐     ┌─────────────┐     ┌──────────────┐     ┌──────────┐
│ SPRITE.H  │────→│CREAR_BINARIO│────→│ SPRITE.BIN   │────→│ IMP_GS_  │────→ Impresora SM1-21
│ (origen)  │     │ (convertir) │     │ (binario)    │     │ FILE_BIN │      (Modo GS)
└───────────┘     └─────────────┘     └──────────────┘     └──────────┘
                                              │
                                              ▼
                                    ┌─────────────────┐
                                    │ ESC_GS_SERIAL   │
                                    │ (visor macOS)   │
                                    └─────────────────┘
```

---

## Requisitos del Sistema

| Componente | Requisito |
|-----------|-----------|
| **Sistema Destino** | CASIO FX-890P/Z-1 con FX-DOS |
| **SO (Herramientas)** | MS-DOS / FX-DOS |
| **Compilador** | Compilador compatible con C89 |
| **App macOS** | macOS (Intel / Apple Silicon M3) con Python |
| **Impresora** | SM1-21 (puerto serie COM) |

---

