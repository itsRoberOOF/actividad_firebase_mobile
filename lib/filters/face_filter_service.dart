import 'package:image_picker/image_picker.dart';

import 'filter_kind.dart';

/// Error recuperable al aplicar un filtro. El mensaje es para la persona usuaria;
/// [code] permite distinguir el caso en pruebas.
class FilterException implements Exception {
  const FilterException(this.message, {this.code = 'FILTER_FAILED'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// Incorpora un filtro facial al archivo. La implementación real sólo existe en
/// Android (ver `face_filter_io.dart`); en web no hay servicio.
abstract class FaceFilterService {
  /// Devuelve una copia de [photo] con el filtro horneado.
  Future<XFile> applyToPhoto(XFile photo, FaceFilter filter);

  /// Devuelve un MP4 nuevo con el filtro horneado. [onProgress] va de 0 a 1.
  Future<XFile> applyToVideo(
    XFile video,
    FaceFilter filter, {
    required void Function(double) onProgress,
  });
}
