import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'media_uploader.dart';
import 'video_repository.dart';

export 'media_uploader.dart' show MediaPublishException, validateMediaSelection;

class MediaPublisher {
  const MediaPublisher({required this.uploader, required this.repository});

  final MediaUploader uploader;
  final VideoRepository repository;

  Future<void> publish({
    required XFile file,
    required String title,
    required String description,
    required User? author,
    required void Function(double) onProgress,
  }) async {
    if (author == null) {
      throw const MediaPublishException(
        'Inicia sesión para publicar.',
      );
    }
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 100) {
      throw const MediaPublishException(
        'Escribe un título de hasta 100 caracteres.',
      );
    }
    if (cleanDescription.length > 1000) {
      throw const MediaPublishException(
        'La descripción no puede superar 1000 caracteres.',
      );
    }
    if (!uploader.isConfigured) {
      throw const MediaPublishException(
        'Configura Cloudinary para poder publicar.',
      );
    }
    final mediaType = validateMediaSelection(
      name: file.name,
      mimeType: file.mimeType,
      bytes: await file.length(),
    );

    final UploadedMedia uploaded;
    try {
      uploaded = await uploader.upload(
        file,
        mediaType: mediaType,
        onProgress: onProgress,
      );
    } on MediaPublishException {
      rethrow;
    } catch (_) {
      throw const MediaPublishException(
        'No se pudo subir el archivo. Inténtalo otra vez.',
      );
    }
    try {
      await repository.createPost(
        title: cleanTitle,
        description: cleanDescription,
        mediaType: mediaType,
        mediaUrl: uploaded.secureUrl,
        cloudinaryPublicId: uploaded.publicId,
        author: author,
      );
    } catch (_) {
      throw const MediaPublishException(
        'El archivo se subió, pero no se publicó. Contacta al administrador.',
      );
    }
  }
}
