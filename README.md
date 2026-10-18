# Videoteca

Aplicación Flutter para Android y web con registro e inicio de sesión por correo y contraseña mediante Firebase Authentication.

## Ejecutar

```sh
flutter pub get
cp cloudinary.example.json cloudinary.json   # y completa tus valores
flutter run -d edge --dart-define-from-file=cloudinary.json
```

Para Android, inicia un emulador o conecta un dispositivo y ejecuta el mismo comando sin `-d edge`. Las compilaciones usan la misma opción, por ejemplo `flutter build web --dart-define-from-file=cloudinary.json`.

`cloudinary.json` está en `.gitignore`: cada persona lo crea en su copia local a partir de `cloudinary.example.json`. Sin ese archivo la app funciona, pero el diálogo de publicación indica que falta configurar Cloudinary.

## Firebase

El proyecto es `listasuper-75ab3`. Las apps Firebase son:

- Android: `com.faro.videos`
- Web: `Videoteca`

La configuración de ambas plataformas está en `lib/firebase_options.dart`; la configuración de Android descargada con Firebase CLI está en `android/app/google-services.json`. El proveedor de correo y contraseña se declara en `firebase.json` y ya se desplegó al proyecto.

La app incluye acceso, registro, recuperación de contraseña y el feed de publicaciones guardadas en Cloud Firestore. La base de datos Standard `(default)` está creada en `us-central1`. Solo usuarios autenticados pueden leer publicaciones o crear registros con su propio UID.

**Reglas pendientes de despliegue:** `firestore.rules` ya incluye fotos y likes, pero el proyecto conserva las reglas anteriores hasta desplegarlas con `firebase deploy --only firestore:rules`. Hasta entonces, las publicaciones de fotos y los likes serán rechazados por Firestore.

## Publicar fotos y videos

Los archivos se guardan en **Cloudinary** y sus datos (título, descripción, tipo, URL, autor y fecha) en Firestore. El autor sale de Firebase Auth; Firestore asigna la fecha en el servidor. No se usa Firebase Storage ni se guarda el archivo en Firestore.

Las publicaciones nuevas usan los campos `mediaType` (`image` o `video`) y `mediaUrl`. Las publicaciones de video anteriores, sin `mediaType`, se siguen leyendo como video con su `videoUrl`; no hace falta migrarlas.

`cloudinary.json` define dos valores: `CLOUDINARY_CLOUD_NAME` (el `cloud_name` de la cuenta) y `CLOUDINARY_UPLOAD_PRESET` (un preset **unsigned**). El preset debe aceptar también imágenes `jpg`, `jpeg`, `png` y `webp`, además de `mp4`, `mov`, `m4v` y `webm`, porque las fotos se envían a la API de imágenes de Cloudinary. Revisa los formatos permitidos del preset en el panel de Cloudinary. Nunca pongas el API secret de Cloudinary en este archivo ni en la app.

El [plan Free de Cloudinary](https://cloudinary.com/pricing) no requiere tarjeta, incluye 25 créditos mensuales y acepta [archivos de hasta 100 MB](https://cloudinary.com/pricing/compare-plans). La app rechaza archivos vacíos, de otros formatos o de más de 100 MB.

Para la demostración web, usa archivos pequeños: el selector del navegador puede cargar el archivo completo en memoria antes de enviarlo, incluso si está por debajo del límite de 100 MB.

**Solo para demostración académica:** el nombre de un preset unsigned puede descubrirse en la app y utilizarse para subir archivos fuera de ella. Un producto público necesita subidas firmadas por un servidor que verifique Firebase Auth. Si Cloudinary acepta el archivo pero falla la escritura en Firestore, el archivo huérfano se elimina manualmente desde Cloudinary.

## Filtros faciales y cámara (solo Android)

En Android, el diálogo de publicación ofrece **Cámara** (foto o video de hasta 15 segundos) y tres filtros faciales: **Lentes**, **Bigote** y **Corona**. Web publica desde galería sin filtros ni cámara, porque ML Kit no tiene soporte web.

- **Fotos:** ML Kit Face Detection localiza ojos, nariz, boca y el cuadro del rostro. El filtro se dibuja en una copia de la foto, que es la que se sube. Si no hay rostro, no se publica y se conserva la selección para cambiar de filtro o reintentar.
- **Videos:** el puente nativo (`android/app/src/main/kotlin/com/faro/videos/`) analiza el clip cada 200 ms con ML Kit, sigue el rostro y exporta un MP4 nuevo de hasta 720p con Media3 Transformer. El audio original se conserva y se sube el archivo procesado. Los clips de más de 15 segundos se rechazan.
- Los sprites de los filtros están en `assets/filters/` y se regeneran con `dart run tool/generate_filter_assets.dart`.

La geometría de los filtros (cálculo de posición, tamaño y giro a partir de los puntos faciales) está documentada en el [plan de implementación](docs/superpowers/plans/2026-10-16-videoteca-media-likes-filters.md) y se repite en Dart (`lib/filters/face_geometry.dart`) y en Kotlin.

## Likes

Cada publicación muestra un botón de like y su total. Cada like es un documento en `videos/{postId}/likes/{uid}`: una persona tiene como máximo un like por publicación, y tocar de nuevo lo quita. El conteo se actualiza en tiempo real.

## Feed

La vista principal muestra las publicaciones en un feed vertical de pantalla completa: cada gesto avanza una publicación. Las fotos se muestran como imagen estática; los videos se reproducen en silencio mientras están visibles. Una pantalla final indica que no hay más publicaciones. La edición, el borrado y los comentarios aún no están implementados.

Los iconos de Android y web se pueden regenerar con `tool/generate_icons.ps1` en Windows.
