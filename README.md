# Videoteca

Aplicación Flutter para Android y web con registro e inicio de sesión por correo y contraseña mediante Firebase Authentication.

## Ejecutar

```sh
flutter pub get
cp cloudinary.example.json cloudinary.json   # y completa tus valores
flutter run -d edge --dart-define-from-file=cloudinary.json
```

Para Android, inicia un emulador o conecta un dispositivo y ejecuta el mismo comando sin `-d edge`. Las compilaciones usan la misma opción, por ejemplo `flutter build web --dart-define-from-file=cloudinary.json`.

`cloudinary.json` está en `.gitignore`: cada persona lo crea en su copia local a partir de `cloudinary.example.json`. Sin ese archivo la app funciona, pero el diálogo de subida indica que falta configurar Cloudinary.

## Firebase

El proyecto es `listasuper-75ab3`. Las apps Firebase son:

- Android: `com.faro.videos`
- Web: `Videoteca`

La configuración de ambas plataformas está en `lib/firebase_options.dart`; la configuración de Android descargada con Firebase CLI está en `android/app/google-services.json`. El proveedor de correo y contraseña se declara en `firebase.json` y ya se desplegó al proyecto.

La app incluye acceso, registro, recuperación de contraseña y una vista inicial con videos guardados en Cloud Firestore. La base de datos Standard `(default)` está creada en `us-central1`; las reglas de `firestore.rules` están desplegadas. Solo usuarios autenticados pueden leer videos o publicar registros con su propio UID.

## Subir videos

Los archivos se guardan en **Cloudinary** y sus datos (título, descripción, autor, fecha y URL) en Firestore. El autor sale de Firebase Auth; Firestore asigna la fecha en el servidor. No se usa Firebase Storage ni se guarda el archivo en Firestore.

`cloudinary.json` define dos valores: `CLOUDINARY_CLOUD_NAME` (el `cloud_name` de la cuenta) y `CLOUDINARY_UPLOAD_PRESET` (un preset **unsigned**). El preset de Videoteca guarda en la carpeta `videoteca`, acepta `mp4`, `mov`, `m4v` y `webm`, genera IDs únicos, no admite un ID enviado por el cliente y no sobrescribe archivos. Nunca pongas el API secret de Cloudinary en este archivo ni en la app.

El [plan Free de Cloudinary](https://cloudinary.com/pricing) no requiere tarjeta, incluye 25 créditos mensuales y acepta [videos de hasta 100 MB](https://cloudinary.com/pricing/compare-plans). El diálogo permite elegir un video de la galería, escribir título y descripción, y ver el progreso. La app rechaza archivos vacíos, de otros formatos o de más de 100 MB.

Para la demostración web, usa videos cortos: el selector del navegador puede cargar el archivo completo en memoria antes de enviarlo, incluso si está por debajo del límite de 100 MB.

**Solo para demostración académica:** el nombre de un preset unsigned puede descubrirse en la app y utilizarse para subir archivos fuera de ella. Un producto público necesita subidas firmadas por un servidor que verifique Firebase Auth. Si Cloudinary acepta el archivo pero falla la escritura en Firestore, el archivo huérfano se elimina manualmente desde Cloudinary.

La vista principal muestra los videos en un feed vertical de pantalla completa: cada gesto avanza un video, el visible se reproduce en silencio y una pantalla final indica que no hay más. La edición y el borrado de videos aún no están implementados.

Los iconos de Android y web se pueden regenerar con `tool/generate_icons.ps1` en Windows.
