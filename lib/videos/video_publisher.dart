import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'video_repository.dart';
import 'video_uploader.dart';

export 'video_uploader.dart' show VideoPublishException, validateVideoSelection;

class VideoPublisher {
  const VideoPublisher({required this.uploader, required this.repository});

  final VideoUploader uploader;
  final VideoRepository repository;

  Future<void> publish({
    required XFile file,
    required String title,
    required String description,
    required User? author,
    required void Function(double) onProgress,
  }) async {
    if (author == null) {
      throw const VideoPublishException(
        'Inicia sesión para publicar un video.',
      );
    }
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 100) {
      throw const VideoPublishException(
        'Escribe un título de hasta 100 caracteres.',
      );
    }
    if (cleanDescription.length > 1000) {
      throw const VideoPublishException(
        'La descripción no puede superar 1000 caracteres.',
      );
    }
    if (!uploader.isConfigured) {
      throw const VideoPublishException(
        'Configura Cloudinary para poder subir videos.',
      );
    }
    validateVideoSelection(
      name: file.name,
      mimeType: file.mimeType,
      bytes: await file.length(),
    );

    final UploadedVideo uploaded;
    try {
      uploaded = await uploader.upload(file, onProgress: onProgress);
    } on VideoPublishException {
      rethrow;
    } catch (_) {
      throw const VideoPublishException(
        'No se pudo subir el video. Inténtalo otra vez.',
      );
    }
    try {
      await repository.createVideo(
        title: cleanTitle,
        description: cleanDescription,
        videoUrl: uploaded.secureUrl,
        cloudinaryPublicId: uploaded.publicId,
        author: author,
      );
    } catch (_) {
      throw const VideoPublishException(
        'El video se subió, pero no se publicó. Contacta al administrador.',
      );
    }
  }
}
