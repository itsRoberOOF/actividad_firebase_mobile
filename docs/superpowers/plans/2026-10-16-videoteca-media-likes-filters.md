# Publicaciones multimedia, likes y filtros ML: plan de implementación

> Spec: [2026-10-16-videoteca-media-likes-filters-design.md](../specs/2026-10-16-videoteca-media-likes-filters-design.md)

**Objetivo:** Videoteca publica fotos y videos, da likes por usuario y aplica tres filtros faciales (lentes, bigote, corona). En Android los filtros se incorporan en el archivo final, en fotos (Dart + ML Kit) y en videos (Kotlin + ML Kit + Media3). La web conserva feed, likes y subida desde galería.

## Restricciones globales

- No hacer commits ni despliegues. Las reglas de Firestore se escriben en el repo; el despliegue lo decide la persona propietaria.
- Web: ninguna ruta compartida importa `google_mlkit_*`, `camera` ni código Android. Se usan imports condicionales (`dart.library.io`).
- UI en español; identificadores en inglés; comentarios breves y sólo donde el porqué no es obvio.
- Sin API secret de Cloudinary; sin Firebase Storage.
- Los PNG de filtro viven en `assets/filters/` (generados por `tool/generate_filter_assets.dart`). Dart los copia a un archivo temporal antes de llamar al puente Android.

## Contratos compartidos

### Documento de publicación (`videos/{postId}`)

Documentos nuevos: `mediaType` (`image` | `video`), `mediaUrl` (URL HTTPS de Cloudinary), `cloudinaryPublicId`, `title`, `description`, `authorId`, `authorName`, `createdAt` (servidor).

Documentos antiguos sin `mediaType` se leen como `video` y usan `videoUrl`. No se migran.

### Likes (`videos/{postId}/likes/{uid}`)

Documento con ID = UID de Firebase Auth y campos `uid`, `createdAt` (servidor). Crear = dar like; borrar = quitar. El conteo es el número de documentos de la subcolección, observado en tiempo real.

### Geometría de filtros (única fuente de verdad; Dart y Kotlin la implementan igual)

Entrada por rostro, en píxeles de la imagen de análisis (origen arriba-izquierda, y hacia abajo): `L`/`R` = ojos izquierdo/derecho, `N` = base de la nariz, `ML`/`MR` = comisuras de la boca, `B` = cuadro delimitador (x, y, w, h). Cualquier landmark puede faltar.

1. Ángulo de inclinación `θ` (grados, positivo = horario en pantalla): si existen `L` y `R`, `v = R − L`; si `v.x < 0`, `v = −v`; `θ = atan2(v.y, v.x)`. Si no existen ojos, `θ = 0`.
2. Distancia interpupilar `d = |R − L|`.
3. Rotación de vector: `R(θ)·(x, y) = (x·cosθ − y·sinθ, x·sinθ + y·cosθ)`.
4. Lentes (`sunglasses`): requiere `L` y `R`. Centro = `(L+R)/2`. Ancho `w = 2.0·d`.
5. Bigote (`mustache`): requiere `N` y `L`/`R`. Ancho `mw = |MR − ML|` si hay comisuras, si no `d`; `w = 1.3·mw`. Centro = `N + R(θ)·(0, 0.12·d)`.
6. Corona (`crown`): requiere `B`. Ancla = `(B.x + B.w/2, B.y + 0.05·B.h)`; `w = 0.9·B.w`. Centro = `ancla + R(θ)·(0, −h/2)`.

Altura del sprite: `h = w · alto_sprite / ancho_sprite` (lentes 400/1000, bigote 220/600, corona 360/600).

Resultado: `Placement(cx, cy, w, θ)`. El sprite se dibuja centrado en `(cx, cy)`, con ancho `w` y rotado `θ` (horario en pantalla).

Si falta el landmark requerido, el rostro se descarta para ese filtro. Si ningún rostro produce colocación, el resultado es "no se detectó un rostro".

### Puente Android de video

- MethodChannel `videoteca/video_filters`, método `applyVideoFilter`. Argumentos: `inputPath` (String), `outputPath` (String, se sobrescribe), `overlayPath` (String, PNG del filtro), `filter` (`sunglasses` | `mustache` | `crown`), `maxDurationMs` (15000), `maxHeight` (720). Resultado: `outputPath` (String).
- Errores (`PlatformException.code`): `TOO_LONG`, `INVALID_VIDEO`, `NO_FACE`, `EXPORT_FAILED`.
- EventChannel `videoteca/video_filters/progress`: mapas `{stage: "analyzing" | "exporting", progress: double 0..1}`.
- Análisis: muestreo cada 200 ms con `MediaMetadataRetriever`; detección con ML Kit (`com.google.mlkit:face-detection`) sobre el fotograma reducido a `maxHeight`. Se toma el rostro más grande por muestra. Entre muestras se interpolan linealmente `cx`, `cy`, `w`, `θ`; antes de la primera y después de la última se mantiene el valor extremo.
- Exportación: Media3 `Transformer` con `OverlayEffect` y un `TextureOverlay` cuyo `OverlaySettings` cambia por fotograma. Audio original conservado. Salida ≤ 720p.

## Tareas

### Tarea 1: Modelo de publicación y reglas

- `VideoRecord` gana `mediaType` y `mediaUrl`; `videoUrl` se mantiene sólo como fuente de documentos antiguos.
- `VideoRepository.createPost` escribe los campos nuevos.
- `firestore.rules`: publicaciones nuevas con `mediaType`/`mediaUrl`; subcolección `likes` que sólo permite crear/borrar el propio UID.
- Pruebas: documentos nuevos y antiguos, validación de `createPost`.

### Tarea 2: Likes

- `LikeRepository` con una abstracción `LikeStore` (inyectable). Métodos: `watch(postId) → Stream<Set<String>>` (UIDs que dieron like), `setLiked(postId, uid, liked)`.
- Pruebas: crear/quitar, un documento por UID, conteo actualizado, error propagado.

### Tarea 3: Subida de imágenes y publicación

- `validateMediaSelection` acepta imágenes (`jpg`, `jpeg`, `png`, `webp`) y videos; devuelve `MediaType`.
- `MediaUploader` usa `/image/upload` o `/video/upload`.
- `MediaPublisher.publish` acepta `mediaType`, `file`, título, descripción y progreso.
- Pruebas: validación, endpoint por tipo, fallo tras subida.

### Tarea 4: Feed mixto y likes

- `VideoList` decide el renderizador por `mediaType`; las fotos usan `Image.network` sin reproductor.
- Botón de like y contador en la columna derecha de cada publicación. Sin `LikeRepository` no se muestran controles.
- Pruebas: feed mixto, fotos sin reproductor, estado de like.

### Tarea 5: Geometría y filtros de foto

- `lib/filters/filter_kind.dart`, `lib/filters/face_geometry.dart` (formulas de la sección anterior, puras).
- `lib/filters/sprite_compositor.dart`: composición con mapeo inverso y mezcla alfa, sobre `package:image`.
- `lib/filters/photo_filter_service.dart`: normaliza orientación EXIF, detecta con ML Kit (imports condicionales), compone y escribe JPEG temporal.
- Pruebas: geometría con landmarks sintéticos, compositor sobre imagen pequeña, orientación.

### Tarea 6: Puente de video (Android)

- `MainActivity.kt` registra el canal; `VideoFilterProcessor.kt` implementa análisis y exportación.
- Dependencias Gradle: `androidx.media3` (transformer, effect, common) y `com.google.mlkit:face-detection`.
- Dart: `lib/filters/video_filter_channel.dart` (imports condicionales; en web lanza `unsupported`).

### Tarea 7: Captura y diálogo

- `lib/capture/camera_capture_screen.dart` (Android, `camera`): foto y video de hasta 15 s.
- `MediaUploadDialog` (sustituye a `VideoUploadDialog`): galería; en Android también cámara y selector de filtro; estados "Aplicando filtro…", "Subiendo …"; conserva la selección ante errores.

### Tarea 8: Verificación

- `flutter analyze`, `flutter test`, `flutter build web`, `flutter build apk --debug`.
- Pruebas Android con dispositivo o emulador: no disponibles en esta sesión; queda documentado.
