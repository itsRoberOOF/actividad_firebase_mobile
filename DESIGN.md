---
name: Videoteca
description: Acceso a una app de videos con identidad celeste.
colors:
  sky: "#37BCE8"
  deep-sky: "#118DBB"
  ink: "#102B3C"
  canvas: "#F6FAFC"
  muted: "#5A7180"
  field-border: "#D5E3E9"
  error-surface: "#FFEDEA"
rounded:
  wordmark: "11px"
  control: "14px"
  feature: "20px"
spacing:
  label-gap: "8px"
  field-gap: "18px"
  page-gutter: "28px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "#FFFFFF"
    rounded: "{rounded.control}"
    height: "56px"
  input:
    backgroundColor: "#FFFFFF"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
---

# Design System: Videoteca

## Overview

**Creative North Star: "Una ventana al siguiente video"**

Videoteca usa una superficie celeste expresiva para presentar el producto y una superficie clara para completar tareas. El acceso debe sentirse directo: un título, campos legibles, un único botón principal y mensajes que indiquen cómo corregir errores.

**Key Characteristics:**

- Identidad celeste y tinta azul oscuro.
- Ilustración de un fotograma con control de reproducción.
- Controles Material 3 redondeados y amplios.

## Colors

El celeste identifica Videoteca; la tinta oscura da contraste a texto y acciones. El fondo claro mantiene la atención en los formularios. Los estados de error usan una superficie rojiza y texto oscuro.

**The Celeste Rule.** El celeste domina la zona de identidad y los acentos; los botones principales del formulario usan tinta oscura para conservar jerarquía y contraste.

## Typography

La implementación usa la tipografía de sistema de Flutter y Material 3. Los titulares de la zona de identidad llegan a 46 sp en escritorio y 32 sp en móvil; los títulos de formulario usan 31 sp, el texto de apoyo 15 sp y las etiquetas 14 sp. El peso y el espacio entre letras distinguen titulares y cuerpo.

## Layout

Desde 900 dp, el acceso muestra dos columnas: identidad a la izquierda y formulario a la derecha. Si la ventana mide menos de 720 dp de alto, el fotograma se compacta y deja visible el titular completo. En anchos menores, la identidad aparece arriba y el formulario se desplaza verticalmente. El formulario se limita a 430–500 dp y usa 28 dp de margen horizontal.

## Elevation & Depth

El formulario es plano. Solo el fotograma ilustrado se levanta con una sombra suave desplazada para sugerir contenido en primer plano.

## Shapes

Los campos y botones comparten esquinas de 14 dp; la marca usa 11 dp. La vista inicial de sesión usa un contenedor de 20 dp.

## Components

### Buttons

La acción principal es un botón oscuro de 56 dp de alto con texto blanco y una flecha. Los enlaces de cambio de modo y recuperación usan botones de texto de Material 3.

### Inputs / Fields

Los campos tienen fondo blanco, borde claro y foco celeste más marcado. La contraseña ofrece control explícito para mostrar u ocultar el texto. Los errores aparecen debajo del campo o en un bloque con texto accionable.

### Brand panel

La marca, el titular y el fotograma forman un panel celeste. En móvil se reduce a marca, titular y explicación breve para que el formulario aparezca pronto.

## Do's and Don'ts

### Do:

- **Do** conservar etiquetas visibles sobre todos los campos.
- **Do** mantener el botón principal a ancho completo en los formularios.

### Don't:

- **Don't** usar el celeste como color de texto largo sobre fondo blanco.
- **Don't** ocultar los mensajes de validación mientras la persona corrige el formulario.
