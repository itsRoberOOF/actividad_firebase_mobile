import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

const maxVideoBytes = 100000000;
const allowedVideoExtensions = {'mp4', 'mov', 'm4v', 'webm'};

class VideoPublishException implements Exception {
  const VideoPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UploadedVideo {
  const UploadedVideo({required this.secureUrl, required this.publicId});

  final String secureUrl;
  final String publicId;
}

void validateVideoSelection({
  required String name,
  required String? mimeType,
  required int bytes,
}) {
  final extension = name.toLowerCase().split('.').last;
  final genericMime =
      mimeType == null ||
      mimeType.isEmpty ||
      mimeType == 'application/octet-stream';
  if ((name.isNotEmpty && !allowedVideoExtensions.contains(extension)) ||
      (name.isEmpty && mimeType?.startsWith('video/') != true) ||
      (!genericMime && !mimeType.startsWith('video/'))) {
    throw const VideoPublishException('Elige un video MP4, MOV, M4V o WebM.');
  }
  if (bytes <= 0) {
    throw const VideoPublishException(
      'El video está vacío. Elige otro archivo.',
    );
  }
  if (bytes > maxVideoBytes) {
    throw const VideoPublishException('El video no puede superar 100 MB.');
  }
}

String _uploadMimeType(XFile file) {
  if (file.mimeType?.startsWith('video/') == true) return file.mimeType!;
  final extension = file.name.toLowerCase().split('.').last;
  return switch (extension) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'm4v' => 'video/x-m4v',
    _ => 'video/mp4',
  };
}

abstract class VideoUploader {
  bool get isConfigured;

  Future<UploadedVideo> upload(
    XFile file, {
    required void Function(double) onProgress,
  });
}

class CloudinaryVideoUploader implements VideoUploader {
  CloudinaryVideoUploader({
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
  Future<UploadedVideo> upload(
    XFile file, {
    required void Function(double) onProgress,
  }) async {
    if (!isConfigured) {
      throw const VideoPublishException(
        'Configura Cloudinary para poder subir videos.',
      );
    }
    final size = await file.length();
    validateVideoSelection(
      name: file.name,
      mimeType: file.mimeType,
      bytes: size,
    );

    try {
      final form = FormData.fromMap({
        'upload_preset': uploadPreset,
        'file': MultipartFile.fromStream(
          () => file.openRead(),
          size,
          filename: file.name.isEmpty ? 'video.mp4' : file.name,
          contentType: DioMediaType.parse(_uploadMimeType(file)),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress((sent / total).clamp(0, 1));
        },
      );
      final data = response.data;
      final secureUrl = data?['secure_url'];
      final publicId = data?['public_id'];
      if (secureUrl is! String || publicId is! String) {
        throw const VideoPublishException(
          'Cloudinary no devolvió los datos del video.',
        );
      }
      return UploadedVideo(secureUrl: secureUrl, publicId: publicId);
    } on VideoPublishException {
      rethrow;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw VideoPublishException(
        status == 400
            ? 'Cloudinary rechazó el video. Revisa el formato y el preset.'
            : 'No se pudo subir el video. Revisa tu conexión e inténtalo otra vez.',
      );
    } catch (_) {
      throw const VideoPublishException(
        'No se pudo subir el video. Inténtalo otra vez.',
      );
    }
  }
}
