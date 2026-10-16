# Subida persistente de videos en Videoteca

## Objetivo y alcance

Permitir que una persona autenticada seleccione un video de su galería en Android o web, escriba título y descripción, lo suba y vuelva a encontrar sus datos tras cerrar y abrir la app. Es una demostración académica para pocos usuarios. La reproducción, edición, borrado, moderación y un catálogo público completo quedan fuera de esta entrega.

## Decisión de almacenamiento

| Opción | Evaluación |
| --- | --- |
| Cloudinary Free + Cloud Firestore | Elegida: evita activar Blaze, conserva Firebase Auth y separa archivos de datos consultables. Cloudinary ofrece 25 créditos mensuales sin tarjeta y hasta 100 MB por video en el plan gratuito. |
| Supabase Free | Descartada para esta entrega: límite de 50 MB por archivo y una integración adicional para conservar Firebase Auth. |
| Cloudflare R2 | Descartada para esta entrega: exige suscripción mediante checkout y un servicio propio para autorizar subidas. |

Cloudinary guardará los bytes del video. Una colección `videos` de Firestore guardará sus datos. Firestore deberá habilitarse en el proyecto `listasuper-75ab3`; su API está deshabilitada actualmente. No se usará Firebase Storage.

## Experiencia

En la vista autenticada habrá un botón flotante celeste con icono de subir, abajo a la derecha. Abrirá un diálogo adaptable a móvil y escritorio. El diálogo permitirá escoger un solo video de la galería o del selector de archivos, mostrar su nombre y tamaño, introducir un título obligatorio y una descripción opcional, y publicar. No pedirá fecha ni autor.

El diálogo validará que el archivo sea un video compatible y no supere 100 MB. Durante la subida mostrará progreso, impedirá envíos duplicados y permitirá reconocer errores de red o cuota. Tras guardar archivo y datos, mostrará confirmación y cerrará el diálogo. Si falla, conservará título, descripción y selección para reintentar. La vista inicial mostrará los registros subidos para comprobar la persistencia; la reproducción queda fuera del alcance.

## Datos y secuencia

1. `image_picker` selecciona un video. La app valida tipo y tamaño antes de enviarlo.
2. La app sube el archivo directamente a Cloudinary mediante un preset *unsigned* configurado para videos y formatos permitidos. `cloud_name` y nombre del preset son configuración pública; nunca se incluye el API secret en Flutter.
3. Al recibir `public_id` y `secure_url`, la app escribe un documento en `videos` con `title`, `description`, `cloudinaryPublicId`, `videoUrl`, `authorId`, `authorName` y `createdAt`.
4. `authorId` sale del UID de Firebase Auth; `authorName` de `displayName` (o `Usuario` si falta). `createdAt` usa el timestamp del servidor de Firestore. Estos tres valores no son campos editables del diálogo.
5. La pantalla consulta Firestore para mostrar los videos persistidos ordenados por fecha. Las reglas permiten leer a usuarios autenticados y crear solo documentos con `authorId == request.auth.uid`, campos y tamaños válidos y una fecha de servidor. No se habilitan cambios ni borrados desde el cliente en esta entrega.

Si la subida a Cloudinary termina pero falla la escritura en Firestore, la app avisará que no se publicó. El archivo quedará huérfano y se limpiará manualmente desde Cloudinary en esta demostración; borrarlo de forma segura desde el cliente requeriría un servidor con credenciales privadas.

## Seguridad, costos y configuración

Cloudinary Free no exige tarjeta, pero su preset *unsigned* se puede descubrir en la app y usar fuera de ella. Es una limitación aceptada solo para la demostración académica. El preset restringirá formatos y sobrescrituras; la app limitará archivos a 100 MB. Para usuarios públicos reales se necesitarán subidas firmadas por un servidor que verifique Firebase Auth.

La persona propietaria debe disponer de una cuenta Cloudinary y proporcionar `cloud_name` y un preset *unsigned*. Firestore puede usar su cuota gratuita para los datos de texto; no se guardarán videos en documentos. Las reglas se versionarán en el repositorio y se desplegarán al proyecto Firebase. No se solicitará ni almacenará el API secret de Cloudinary.

## Verificación

- Pruebas de validación: selección ausente, título vacío, tipo o tamaño inválidos, duplicados y error de subida.
- Prueba de escritura: UID/nombre desde Auth y fecha de servidor, sin campos manuales.
- `flutter analyze`, pruebas de Flutter y compilaciones web/Android.
- Con las cuentas configuradas, subida real y lectura tras recargar sesión en web; Android se verificará en un dispositivo o emulador disponible.

## Fuentes de límites y seguridad

- [Firebase Storage requiere Blaze](https://firebase.google.com/docs/storage/faq-and-troubleshooting).
- [Cuotas gratuitas de Firestore](https://firebase.google.com/docs/firestore/quotas).
- [Cloudinary Free y créditos](https://cloudinary.com/pricing).
- [Límite de video de Cloudinary Free](https://cloudinary.com/pricing/compare-plans).
- [Riesgo de las subidas sin firma](https://cloudinary.com/documentation/upload_images).
