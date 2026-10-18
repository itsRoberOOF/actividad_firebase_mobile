import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Abre la captura con cámara y devuelve la foto o el video, o null si la
/// persona cancela.
typedef CameraCaptureLauncher = Future<XFile?> Function(BuildContext context);
