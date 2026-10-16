import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:videoteca/videos/video_publisher.dart';
import 'package:videoteca/videos/video_repository.dart';
import 'package:videoteca/videos/video_uploader.dart';

class _Author extends Fake implements User {
  @override
  String get uid => 'ana-uid';

  @override
  String? get displayName => 'Ana';
}

class _Store implements VideoDocumentStore {
  Map<String, dynamic>? added;
  bool fail = false;

  @override
  Future<void> add(Map<String, dynamic> data) async {
    if (fail) throw StateError('Firestore no disponible');
    added = data;
  }

  @override
  Stream<List<VideoDocument>> watch() => const Stream.empty();
}

class _Uploader implements VideoUploader {
  _Uploader({this.isConfigured = true});

  @override
  final bool isConfigured;
  int uploads = 0;
  bool fail = false;

  @override
  Future<UploadedVideo> upload(
    XFile file, {
    required void Function(double) onProgress,
  }) async {
    uploads++;
    if (fail) throw const VideoPublishException('Falló la subida');
    onProgress(.8);
    return const UploadedVideo(
      secureUrl: 'https://res.cloudinary.com/demo/video/upload/test.mp4',
      publicId: 'videos/test',
    );
  }
}

XFile video() => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  name: 'prueba.mp4',
  mimeType: 'video/mp4',
);

void main() {
  test('rechaza archivos que no son video o superan 100 MB', () {
    expect(
      () => validateVideoSelection(
        name: 'archivo.pdf',
        mimeType: 'application/pdf',
        bytes: 100,
      ),
      throwsA(isA<VideoPublishException>()),
    );
    expect(
      () => validateVideoSelection(
        name: 'video.mp4',
        mimeType: 'video/mp4',
        bytes: 100000001,
      ),
      throwsA(isA<VideoPublishException>()),
    );
  });

  test('acepta un MP4 con MIME genérico de navegador', () {
    expect(
      () => validateVideoSelection(
        name: 'clip.mp4',
        mimeType: 'application/octet-stream',
        bytes: 1024,
      ),
      returnsNormally,
    );
  });

  test('bloquea publicación sin sesión, título o configuración', () async {
    final uploader = _Uploader();
    final publisher = VideoPublisher(
      uploader: uploader,
      repository: VideoRepository(store: _Store()),
    );
    expect(
      () => publisher.publish(
        file: video(),
        title: 'Video',
        description: '',
        author: null,
        onProgress: (_) {},
      ),
      throwsA(isA<VideoPublishException>()),
    );
    expect(
      () => publisher.publish(
        file: video(),
        title: '  ',
        description: '',
        author: _Author(),
        onProgress: (_) {},
      ),
      throwsA(isA<VideoPublishException>()),
    );
    final noConfig = VideoPublisher(
      uploader: _Uploader(isConfigured: false),
      repository: VideoRepository(store: _Store()),
    );
    expect(
      () => noConfig.publish(
        file: video(),
        title: 'Video',
        description: '',
        author: _Author(),
        onProgress: (_) {},
      ),
      throwsA(isA<VideoPublishException>()),
    );
    expect(uploader.uploads, 0);
  });

  test('guarda los datos después de subir el video', () async {
    final store = _Store();
    final uploader = _Uploader();
    double progress = 0;
    await VideoPublisher(
      uploader: uploader,
      repository: VideoRepository(store: store),
    ).publish(
      file: video(),
      title: ' Mi video ',
      description: ' Descripción ',
      author: _Author(),
      onProgress: (value) => progress = value,
    );

    expect(uploader.uploads, 1);
    expect(store.added?['title'], 'Mi video');
    expect(store.added?['description'], 'Descripción');
    expect(store.added?['authorId'], 'ana-uid');
    expect(progress, .8);
  });

  test(
    'no guarda si falla Cloudinary y no confirma si falla Firestore',
    () async {
      final store = _Store();
      final uploader = _Uploader()..fail = true;
      final publisher = VideoPublisher(
        uploader: uploader,
        repository: VideoRepository(store: store),
      );
      Future<void> publish() => publisher.publish(
        file: video(),
        title: 'Video',
        description: '',
        author: _Author(),
        onProgress: (_) {},
      );

      await expectLater(publish(), throwsA(isA<VideoPublishException>()));
      expect(store.added, isNull);

      uploader.fail = false;
      store.fail = true;
      await expectLater(
        publish(),
        throwsA(
          isA<VideoPublishException>().having(
            (error) => error.message,
            'mensaje',
            contains('no se publicó'),
          ),
        ),
      );
    },
  );
}
