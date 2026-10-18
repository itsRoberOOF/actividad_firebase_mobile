import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:videoteca/videos/media_publisher.dart';
import 'package:videoteca/videos/media_uploader.dart';
import 'package:videoteca/videos/video_repository.dart';

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

class _Uploader implements MediaUploader {
  _Uploader({this.isConfigured = true});

  @override
  final bool isConfigured;
  final List<MediaType> uploadedTypes = [];
  bool fail = false;

  @override
  Future<UploadedMedia> upload(
    XFile file, {
    required MediaType mediaType,
    required void Function(double) onProgress,
  }) async {
    uploadedTypes.add(mediaType);
    if (fail) throw const MediaPublishException('Falló la subida');
    onProgress(.8);
    return const UploadedMedia(
      secureUrl: 'https://res.cloudinary.com/demo/video/upload/test.mp4',
      publicId: 'videos/test',
    );
  }
}

XFile _video() => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  name: 'prueba.mp4',
  mimeType: 'video/mp4',
);

XFile _photo() => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  name: 'foto.jpg',
  mimeType: 'image/jpeg',
);

void main() {
  test('bloquea publicación sin sesión, título o configuración', () async {
    final uploader = _Uploader();
    final publisher = MediaPublisher(
      uploader: uploader,
      repository: VideoRepository(store: _Store()),
    );
    expect(
      () => publisher.publish(
        file: _video(),
        title: 'Video',
        description: '',
        author: null,
        onProgress: (_) {},
      ),
      throwsA(isA<MediaPublishException>()),
    );
    expect(
      () => publisher.publish(
        file: _video(),
        title: '  ',
        description: '',
        author: _Author(),
        onProgress: (_) {},
      ),
      throwsA(isA<MediaPublishException>()),
    );
    final noConfig = MediaPublisher(
      uploader: _Uploader(isConfigured: false),
      repository: VideoRepository(store: _Store()),
    );
    expect(
      () => noConfig.publish(
        file: _video(),
        title: 'Video',
        description: '',
        author: _Author(),
        onProgress: (_) {},
      ),
      throwsA(isA<MediaPublishException>()),
    );
    expect(uploader.uploadedTypes, isEmpty);
  });

  test('guarda un video con su tipo y URL después de subirlo', () async {
    final store = _Store();
    final uploader = _Uploader();
    double progress = 0;
    await MediaPublisher(
      uploader: uploader,
      repository: VideoRepository(store: store),
    ).publish(
      file: _video(),
      title: ' Mi video ',
      description: ' Descripción ',
      author: _Author(),
      onProgress: (value) => progress = value,
    );

    expect(uploader.uploadedTypes, [MediaType.video]);
    expect(store.added?['title'], 'Mi video');
    expect(store.added?['description'], 'Descripción');
    expect(store.added?['authorId'], 'ana-uid');
    expect(store.added?['mediaType'], 'video');
    expect(
      store.added?['mediaUrl'],
      'https://res.cloudinary.com/demo/video/upload/test.mp4',
    );
    expect(store.added?.containsKey('videoUrl'), isFalse);
    expect(progress, .8);
  });

  test('publica una foto como imagen', () async {
    final store = _Store();
    final uploader = _Uploader();
    await MediaPublisher(
      uploader: uploader,
      repository: VideoRepository(store: store),
    ).publish(
      file: _photo(),
      title: 'Atardecer',
      description: '',
      author: _Author(),
      onProgress: (_) {},
    );

    expect(uploader.uploadedTypes, [MediaType.image]);
    expect(store.added?['mediaType'], 'image');
  });

  test(
    'no guarda si falla la subida y no confirma si falla Firestore',
    () async {
      final store = _Store();
      final uploader = _Uploader()..fail = true;
      final publisher = MediaPublisher(
        uploader: uploader,
        repository: VideoRepository(store: store),
      );
      Future<void> publish() => publisher.publish(
        file: _video(),
        title: 'Video',
        description: '',
        author: _Author(),
        onProgress: (_) {},
      );

      await expectLater(publish(), throwsA(isA<MediaPublishException>()));
      expect(store.added, isNull);

      uploader.fail = false;
      store.fail = true;
      await expectLater(
        publish(),
        throwsA(
          isA<MediaPublishException>().having(
            (error) => error.message,
            'mensaje',
            contains('no se publicó'),
          ),
        ),
      );
    },
  );
}
