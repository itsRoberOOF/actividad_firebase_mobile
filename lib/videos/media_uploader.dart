import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import 'media_type.dart';

const maxMediaBytes = 100000000;
const allowedVideoExtensions = {'mp4', 'mov', 'm4v', 'webm'};
const allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

class MediaPublishException implements Exception {
  const MediaPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UploadedMedia {
  const UploadedMedia({required this.secureUrl, required this.publicId});

  final String secureUrl;
  final String publicId;
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Tipo del archivo según su extensión; sin extensión decide el MIME.
MediaType? mediaTypeFor({required String name, required String? mimeType}) {
  final extension = _extension(name);
  if (extension.isNotEmpty) {
    if (allowedImageExtensions.contains(extension)) return MediaType.image;
    if (allowedVideoExtensions.contains(extension)) return MediaType.video;
    return null;
  }
  if (mimeType == null) return null;
  if (mimeType.startsWith('image/')) return MediaType.image;
  if (mimeType.startsWith('video/')) return MediaType.video;
  return null;
}

MediaType validateMediaSelection({
  required String name,
  required String? mimeType,
  required int bytes,
}) {
  final type = mediaTypeFor(name: name, mimeType: mimeType);
  if (type == null) {
    throw const MediaPublishException(
      'Elige una foto JPG, PNG o WebP, o un video MP4, MOV, M4V o WebM.',
    );
  }
  if (bytes <= 0) {
    throw const MediaPublishException(
      'El archivo está vacío. Elige otro archivo.',
    );
  }
  if (bytes > maxMediaBytes) {
    throw const MediaPublishException('El archivo no puede superar 100 MB.');
  }
  return type;
}

String _uploadMimeType(XFile file, MediaType type) {
  final declared = file.mimeType;
  if (declared != null && declared.startsWith('${type.name}/')) return declared;
  return switch (_extension(file.name)) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'm4v' => 'video/x-m4v',
    _ => type == MediaType.image ? 'image/jpeg' : 'video/mp4',
  };
}

abstract class MediaUploader {
  bool get isConfigured;

  Future<UploadedMedia> upload(
    XFile file, {
    required MediaType mediaType,
    required void Function(double) onProgress,
  });
}

class CloudinaryMediaUploader implements MediaUploader {
  CloudinaryMediaUploader({
    Dio? dio,
    this.cloudName = const String.fromEnvironment('CLOUDINARY_CLOUD_NAME'),
    this.uploadPreset = const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
    ),
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final String cloudName;
  final String uploadPreset;

  @override
  bool get isConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;

  @override
  Future<UploadedMedia> upload(
    XFile file, {
    required MediaType mediaType,
    required void Function(double) onProgress,
  }) async {
    if (!isConfigured) {
      throw const MediaPublishException(
        'Configura Cloudinary para poder subir archivos.',
      );
    }
    final size = await file.length();
    validateMediaSelection(name: file.name, mimeType: file.mimeType, bytes: size);

    try {
      final form = FormData.fromMap({
        'upload_preset': uploadPreset,
        'file': MultipartFile.fromStream(
          () => file.openRead(),
          size,
          filename: file.name.isEmpty ? 'archivo' : file.name,
          contentType: DioMediaType.parse(_uploadMimeType(file, mediaType)),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.cloudinary.com/v1_1/$cloudName/${mediaType.name}/upload',
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress((sent / total).clamp(0, 1));
        },
      );
      final data = response.data;
      final secureUrl = data?['secure_url'];
      final publicId = data?['public_id'];
      if (secureUrl is! String || publicId is! String) {
        throw const MediaPublishException(
          'Cloudinary no devolvió los datos del archivo.',
        );
      }
      return UploadedMedia(secureUrl: secureUrl, publicId: publicId);
    } on MediaPublishException {
      rethrow;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw MediaPublishException(
        status == 400
            ? 'Cloudinary rechazó el archivo. Revisa el formato y el preset.'
            : 'No se pudo subir el archivo. Revisa tu conexión e inténtalo otra vez.',
      );
    } catch (_) {
      throw const MediaPublishException(
        'No se pudo subir el archivo. Inténtalo otra vez.',
      );
    }
  }
}
