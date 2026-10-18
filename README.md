# Semana 8 - Clon de TikTok

## Equipo e Integrantes

- **Equipo:** #12
- Roberto Morán
- Óscar Pleités
- Diego Arévalo
- Roberto Polanco
- Christopher Marroquín
- Angie Guzmán

## Acerca de

Videoteca es una app en Flutter para Android y web inspirada en TikTok. Los usuarios inician sesión con Firebase Authentication y publican fotos y videos que se muestran en un feed vertical de pantalla completa. Los archivos se guardan en Cloudinary y sus datos (título, descripción, autor, fecha y likes) en Cloud Firestore.

## Funcionalidades

- Registro, inicio de sesión y recuperación de contraseña con correo y contraseña.
- Feed vertical con `ListView.builder`: cada gesto avanza una publicación, el video visible se reproduce automáticamente y al final se muestra un aviso con icono de que no hay más publicaciones.
- Título, descripción, creador y fecha en la esquina inferior izquierda de cada publicación.
- Botón flotante para publicar fotos o videos desde la galería con título y descripción. El autor y la fecha se asignan automáticamente.
- Likes en tiempo real: uno por usuario y publicación; al tocar de nuevo se quita.
- Solo en Android: cámara (foto o video de hasta 15 segundos) y filtros faciales de **lentes**, **bigote** y **corona**. Usan ML Kit para detectar el rostro y quedan incorporados en el archivo que se sube.
- Validación de archivos (formato y máximo de 100 MB) y mensajes de error en español.

## Cómo ejecutarlo

Los datos de Cloudinary se leen de un archivo local `cloudinary.json`, que no se sube al repositorio. Se crea a partir del ejemplo con el `cloud_name` de la cuenta y un preset de subida *unsigned* que acepte imágenes y videos:

```sh
flutter pub get
cp cloudinary.example.json cloudinary.json
flutter run --dart-define-from-file=cloudinary.json
```

Sin ese archivo la app funciona, pero no permite publicar. En web no están disponibles la cámara ni los filtros. Las reglas de `firestore.rules` deben estar desplegadas (`firebase deploy --only firestore:rules`) para publicar fotos y dar likes.

## Uso de IA

Durante la actividad se utilizó inteligencia artificial como herramienta de apoyo en tres aspectos. Primero, para el diseño de la interfaz de la app. Segundo, para investigar dónde almacenar los videos: Firebase Storage requiere el plan de pago Blaze, así que se buscaron alternativas gratuitas y de esa investigación salió Cloudinary. Por último, como apoyo en la redacción de este README. En todos los casos, el resultado fue revisado y ajustado por el equipo.
