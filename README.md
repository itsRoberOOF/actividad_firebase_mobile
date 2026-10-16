# Videoteca

Aplicación Flutter para Android y web con registro e inicio de sesión por correo y contraseña mediante Firebase Authentication.

## Ejecutar

```sh
flutter pub get
flutter run -d edge
```

Para Android, inicia un emulador o conecta un dispositivo y ejecuta `flutter run`.

## Firebase

El proyecto es `listasuper-75ab3`. Las apps Firebase son:

- Android: `com.faro.videos`
- Web: `Videoteca`

La configuración de ambas plataformas está en `lib/firebase_options.dart`; la configuración de Android descargada con Firebase CLI está en `android/app/google-services.json`. El proveedor de correo y contraseña se declara en `firebase.json` y ya se desplegó al proyecto.

La app incluye acceso, registro, recuperación de contraseña y una vista inicial con videos guardados en Cloud Firestore. La base de datos Standard `(default)` está creada en `us-central1`; las reglas de `firestore.rules` están desplegadas. Solo usuarios autenticados pueden leer videos o publicar registros con su propio UID.

## Subir videos

Los archivos se guardan en **Cloudinary** y sus datos (título, descripción, autor, fecha y URL) en Firestore. El autor sale de Firebase Auth; Firestore asigna la fecha en el servidor. No se usa Firebase Storage ni se guarda el archivo en Firestore.

1. Crea una cuenta [Cloudinary Free](https://cloudinary.com/pricing), que no requiere tarjeta. El plan gratuito incluye 25 créditos mensuales y acepta videos de hasta 100 MB.
2. En los ajustes de subida, crea un preset **unsigned** para video. Permite solo `mp4`, `mov`, `m4v` y `webm`, impide sobrescribir archivos y restringe los demás parámetros según tus necesidades. Guarda el nombre del preset y el `cloud_name` de tu cuenta.
3. Ejecuta la app con ambos valores públicos:

```sh
flutter run -d edge --dart-define=CLOUDINARY_CLOUD_NAME=TU_CLOUD_NAME --dart-define=CLOUDINARY_UPLOAD_PRESET=TU_PRESET
```

En Android, omite `-d edge` y selecciona el dispositivo. El diálogo permite elegir un video de la galería, escribir título y descripción, y ver el progreso. La app rechaza archivos vacíos, de otros formatos o de más de 100 MB.

Para la demostración web, usa videos cortos: el selector del navegador puede cargar el archivo completo en memoria antes de enviarlo, incluso si está por debajo del límite de 100 MB.

**Solo para demostración académica:** el nombre de un preset unsigned puede descubrirse en la app y utilizarse para subir archivos fuera de ella. Un producto público necesita subidas firmadas por un servidor que verifique Firebase Auth. Si Cloudinary acepta el archivo pero falla la escritura en Firestore, el archivo huérfano se elimina manualmente desde Cloudinary.

La reproducción y edición de videos aún no están implementadas.

Los iconos de Android y web se pueden regenerar con `tool/generate_icons.ps1` en Windows.
