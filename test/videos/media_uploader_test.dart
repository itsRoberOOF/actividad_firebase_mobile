import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:videoteca/videos/media_type.dart';
import 'package:videoteca/videos/media_uploader.dart';

void main() {
  group('validación de archivos', () {
    test('clasifica fotos y videos por extensión', () {
      expect(mediaTypeFor(name: 'FOTO.JPG', mimeType: null), MediaType.image);
      expect(mediaTypeFor(name: 'foto.webp', mimeType: null), MediaType.image);
      expect(mediaTypeFor(name: 'clip.webm', mimeType: null), MediaType.video);
    });

    test('sin extensión decide el tipo MIME', () {
      expect(mediaTypeFor(name: '', mimeType: 'image/png'), MediaType.image);
      expect(mediaTypeFor(name: '', mimeType: 'video/mp4'), MediaType.video);
      expect(mediaTypeFor(name: '', mimeType: 'application/pdf'), isNull);
      expect(mediaTypeFor(name: '', mimeType: null), isNull);
    });

    test('rechaza documentos, tamaños excesivos y archivos vacíos', () {
      expect(
        () => validateMediaSelection(
          name: 'archivo.pdf',
          mimeType: 'application/pdf',
          bytes: 100,
        ),
        throwsA(isA<MediaPublishException>()),
      );
      expect(
        () => validateMediaSelection(
          name: 'video.mp4',
          mimeType: 'video/mp4',
          bytes: 100000001,
        ),
        throwsA(isA<MediaPublishException>()),
      );
      expect(
        () => validateMediaSelection(
          name: 'foto.png',
          mimeType: 'image/png',
          bytes: 0,
        ),
        throwsA(isA<MediaPublishException>()),
      );
    });

    test('acepta un MP4 con MIME genérico de navegador', () {
      expect(
        validateMediaSelection(
          name: 'clip.mp4',
          mimeType: 'application/octet-stream',
          bytes: 1024,
        ),
        MediaType.video,
      );
    });
  });

  test('sube fotos al endpoint de imágenes y videos al de videos', () async {
    final requests = <Uri>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options.uri);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'secure_url': 'https://res.cloudinary.com/demo/x.jpg',
                  'public_id': 'x',
                },
              ),
            );
          },
        ),
      );
    final uploader = CloudinaryMediaUploader(
      dio: dio,
      cloudName: 'demo',
      uploadPreset: 'preset',
    );
    final photo = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'foto.jpg',
      mimeType: 'image/jpeg',
    );
    final video = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'clip.mp4',
      mimeType: 'video/mp4',
    );

    final uploaded = await uploader.upload(
      photo,
      mediaType: MediaType.image,
      onProgress: (_) {},
    );
    await uploader.upload(video, mediaType: MediaType.video, onProgress: (_) {});

    expect(uploaded.secureUrl, 'https://res.cloudinary.com/demo/x.jpg');
    expect(uploaded.publicId, 'x');
    expect(requests.map((uri) => uri.path), [
      '/v1_1/demo/image/upload',
      '/v1_1/demo/video/upload',
    ]);
  });

  test('no intenta subir sin configuración', () {
    final uploader = CloudinaryMediaUploader(cloudName: '', uploadPreset: '');
    expect(uploader.isConfigured, isFalse);
  });
}
