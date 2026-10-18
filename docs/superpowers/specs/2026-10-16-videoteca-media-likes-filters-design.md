# Publicaciones multimedia, likes y filtros ML en Videoteca

## Objetivo

Extender Videoteca, una aplicación Flutter académica para Android y web, para que las personas autenticadas publiquen fotos y videos, den like a publicaciones y apliquen tres filtros faciales con ML Kit: lentes oscuros, bigote y corona. Los filtros deben quedar incorporados en el archivo final, incluido el video que se publica y reproduce en el feed.

El alcance prioriza una demostración funcional en Android. La web conserva el acceso, el feed, los likes y la publicación desde galería; los filtros de ML Kit y la captura con cámara se implementan para Android. ML Kit Flutter no ofrece soporte web.

## Alcance

- Publicar imágenes y videos seleccionados desde la galería.
- Capturar fotos y videos desde la cámara en Android.
- Ofrecer al menos tres filtros faciales: lentes oscuros, bigote y corona.
- Detectar rasgos faciales con ML Kit Face Detection y ubicar los recursos gráficos con landmarks del rostro y su cuadro delimitador.
- Aplicar los efectos a fotos antes de subirlas.
- Para videos, analizar y componer los efectos sobre el archivo grabado o seleccionado, exportar un nuevo video y subir ese resultado. El efecto no puede limitarse a una capa sobre la vista previa.
- Mostrar el progreso del análisis/exportación y de la subida, así como errores recuperables.
- Permitir que una persona autenticada dé y quite su propio like en cada publicación; mostrar el total de likes.
- Conservar las publicaciones y la autenticación actuales en Firebase y Cloudinary.

Fuera de alcance: filtros ML en web, reconocimiento de identidad, edición/borrado de publicaciones, comentarios, moderación y subidas firmadas desde servidor.

## Decisiones de arquitectura

### Plataformas

Android será la plataforma completa para cámara y filtros ML. La versión web permitirá seleccionar y publicar imágenes o videos desde el selector de archivos, navegar el feed y usar likes. La interfaz web no ofrecerá efectos ML, porque el plugin `google_mlkit_face_detection` de Flutter solo soporta Android/iOS. El proyecto no configura iOS actualmente.

Se usará el plugin Flutter `camera` para captura Android y `google_mlkit_face_detection` para detección facial. Las dependencias nativas de Android se mantendrán en el proyecto existente.

### Filtros de foto y video

Los tres recursos gráficos serán assets locales transparentes, con tamaño, rotación y posición calculados desde la detección facial:

- Lentes oscuros: alinear con los landmarks de ambos ojos.
- Bigote: ubicar bajo la nariz, usando landmark de nariz y geometría facial.
- Corona: centrar sobre el borde superior del cuadro delimitador del rostro.

Para fotos, se detectará el rostro en la imagen y se exportará una copia con el efecto compuesto. Para videos, la grabación o selección producirá un archivo de entrada temporal. Un puente Android procesará los fotogramas con ML Kit y generará un archivo MP4 nuevo con la capa animada siguiendo al rostro; Media3 Transformer será la base para la composición/exportación nativa. La app subirá el archivo procesado, nunca el original cuando se haya elegido un filtro.

El primer alcance de la demo optimizará videos cortos, hasta 15 segundos y 720p de salida, para mantener razonables el tiempo de procesamiento, la memoria y el tamaño de subida. La interfaz mostrará un estado diferenciado de “Aplicando filtro” y después el progreso de subida. Si no se detecta un rostro o falla la exportación, no se publicará un resultado que aparente tener el filtro aplicado; se conservará la selección para reintentar o cambiar de filtro.

La composición es posterior a la captura: no se promete vista previa filtrada en tiempo real. El requisito se cumple cuando el archivo exportado ya contiene los efectos y ese mismo archivo se publica.

### Publicaciones y almacenamiento

Los bytes de las fotos/videos se guardarán en Cloudinary y sus metadatos en la colección Firestore existente `videos`, sin migrar documentos antiguos. Los documentos nuevos tendrán:

- `mediaType`: `image` o `video`.
- `mediaUrl`: URL HTTPS de Cloudinary del recurso final.
- `cloudinaryPublicId`, `title`, `description`, `authorId`, `authorName` y `createdAt`.

El lector tratará documentos antiguos sin `mediaType`/`mediaUrl` como videos y leerá su `videoUrl` actual. Las imágenes se enviarán a la API de subida de imágenes de Cloudinary y los videos a la API de videos. Se mantienen las restricciones actuales de autenticación, título, descripción y tamaño máximo de 100 MB para subidas. No se almacena el API Secret de Cloudinary en Flutter.

El feed decidirá el reproductor/renderizador según `mediaType`, mantendrá el desplazamiento vertical y los metadatos actuales, y mostrará fotos estáticas sin inicializar un reproductor de video.

### Likes

Cada like se representará como un documento en `videos/{postId}/likes/{uid}`. El ID del documento será el UID de Firebase Auth, por lo que cada usuario tendrá como máximo un like por publicación. Crear el documento da like y borrarlo lo quita. El conteo visible se deriva de los documentos de likes en tiempo real, adecuado al tamaño de la demostración; no se confiará en un contador modificable por el cliente.

Las reglas de Firestore permitirán a usuarios autenticados leer likes y crear/eliminar únicamente el documento cuyo ID sea su propio UID. Los metadatos de las publicaciones seguirán sin permitir actualizaciones o borrados desde el cliente.

## Flujo de publicación

1. La persona inicia sesión y selecciona una foto/video de galería o captura una foto/video con la cámara Android.
2. En Android puede escoger uno de los tres filtros o publicar sin filtro. En web se publica el archivo seleccionado sin filtros ML.
3. Para una foto filtrada, ML Kit obtiene los landmarks; el compositor produce el archivo final.
4. Para un video filtrado, el procesador Android analiza el clip y exporta un MP4 con el recurso siguiendo el rostro. El audio original se conserva.
5. La app valida formato y tamaño del resultado y lo sube al endpoint de Cloudinary correspondiente.
6. Tras la respuesta de Cloudinary, Firestore crea el documento con URL, tipo, título, descripción y autor de Firebase Auth; la fecha usa tiempo de servidor.
7. El feed recibe la nueva publicación por su stream y la muestra con sus controles de like.

Si Cloudinary acepta el archivo y Firestore falla, se mostrará el error de publicación y se documentará la limpieza manual del recurso huérfano, igual que en el flujo actual.

## Seguridad y límites

- Todas las lecturas y escrituras de Firestore requieren autenticación.
- El autor y fecha no son campos editables por el usuario; el UID se deriva de Auth y la fecha de `FieldValue.serverTimestamp()`.
- Un usuario solo puede crear/eliminar su propio documento de like.
- El preset unsigned de Cloudinary sigue siendo una limitación de la demo académica. No se debe incluir API Secret.
- Los filtros son overlays decorativos; ML Kit detecta puntos faciales y no identifica a la persona.
- El procesamiento por fotograma puede consumir memoria/batería. Los clips cortos y salida 720p limitan ese coste.
- La captura web y los efectos ML quedan excluidos de esta iteración; publicación web desde galería sí queda incluida.

## Criterios de aceptación

1. Una publicación puede ser una imagen o un video; documentos antiguos de video siguen cargando sin migración manual.
2. Una persona autenticada puede elegir una imagen o video de galería y publicarlo; en Android también puede capturar foto/video con cámara.
3. Android ofrece lentes, bigote y corona, y ML Kit ubica cada efecto sobre el rostro detectado en fotos.
4. Al aplicar un filtro a un video, el archivo subido y reproducido en el feed contiene el efecto siguiendo el rostro y conserva el audio.
5. Antes de subir un video filtrado, la interfaz muestra el progreso de procesamiento; luego muestra progreso de subida y errores concretos.
6. Un clip filtrado que no detecta rostro no se presenta como procesado correctamente.
7. Dar like crea un único documento por usuario/publicación; tocar de nuevo lo elimina. El conteo cambia para usuarios conectados en tiempo real.
8. Las reglas impiden crear likes en nombre de otro usuario y mantienen protegidos los metadatos de publicación.
9. El feed muestra fotos como imágenes y videos con el reproductor actual.
10. La web mantiene feed, likes y subida desde galería sin exponer controles ML no soportados.

## Verificación prevista

- Pruebas unitarias de composición del modelo para documentos nuevos y antiguos, validación de foto/video, selección de filtros y reglas de publicación.
- Pruebas del repositorio de likes: crear/quitar, UID propio, actualización del conteo y errores.
- Pruebas de widgets para controles de galería/cámara, selector de filtro, progreso de procesamiento/subida, feed mixto y estado de likes.
- Pruebas Android con imágenes de rostro frontal, inclinación moderada y ausencia de rostro; verificar visualmente ubicación/tamaño de lentes, bigote y corona.
- Grabar un clip corto con rostro, exportar, reproducir el MP4 final, comprobar que el efecto sigue el rostro y que conserva audio, subirlo y verificar la reproducción publicada.
- Ejecutar `flutter analyze`, `flutter test`, compilación Android y compilación web. La web no debe importar código de ML Kit ni de cámara Android en rutas compartidas.

## Referencias técnicas

- [ML Kit Face Detection: landmarks y seguimiento](https://developers.google.com/ml-kit/vision/face-detection/face-detection-concepts)
- [Plugin Flutter de detección facial](https://pub.dev/packages/google_mlkit_face_detection)
- [Plugin Flutter de cámara](https://pub.dev/packages/camera)
- [Media3 Transformer: exportación y efectos de video](https://developer.android.com/media/media3/transformer)
- [Media3: overlay y efectos personalizados](https://developer.android.com/media/implement/editing-app)
