import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/videos/video_repository.dart';

class _Author extends Fake implements User {
  @override
  String get uid => 'user-123';

  @override
  String? get displayName => 'Ana';
}

class _LongNameAuthor extends _Author {
  @override
  String? get displayName => 'A' * 101;
}

class _Store implements VideoDocumentStore {
  Map<String, dynamic>? added;
  List<VideoDocument> documents = [];

  @override
  Future<void> add(Map<String, dynamic> data) async => added = data;

  @override
  Stream<List<VideoDocument>> watch() => Stream.value(documents);
}

void main() {
  test('guarda autor de Firebase y fecha del servidor', () async {
    final store = _Store();
    final repository = VideoRepository(store: store);

    await repository.createPost(
      title: 'Mi primer video',
      description: 'Descripción',
      mediaType: MediaType.video,
      mediaUrl: 'https://example.com/video.mp4',
      cloudinaryPublicId: 'videos/abc',
      author: _Author(),
    );

    expect(store.added?['authorId'], 'user-123');
    expect(store.added?['authorName'], 'Ana');
    expect(store.added?['createdAt'], isA<FieldValue>());
    expect(store.added?['title'], 'Mi primer video');
  });

  test('limita el nombre del autor al máximo que aceptan las reglas', () async {
    final store = _Store();
    await VideoRepository(store: store).createPost(
      title: 'Prueba',
      description: '',
      mediaType: MediaType.image,
      mediaUrl: 'https://res.cloudinary.com/demo/image/upload/test.jpg',
      cloudinaryPublicId: 'test',
      author: _LongNameAuthor(),
    );
    expect((store.added?['authorName'] as String).length, 100);
  });

  test('rechaza títulos vacíos antes de escribir', () async {
    final store = _Store();
    await expectLater(
      VideoRepository(store: store).createPost(
        title: '   ',
        description: '',
        mediaType: MediaType.image,
        mediaUrl: 'https://res.cloudinary.com/demo/image/upload/test.jpg',
        cloudinaryPublicId: 'test',
        author: _Author(),
      ),
      throwsArgumentError,
    );
    expect(store.added, isNull);
  });

  test('lee documentos antiguos de video sin mediaType', () async {
    final store = _Store()
      ..documents = [
        VideoDocument('legacy', {
          'title': 'Antiguo',
          'description': '',
          'videoUrl': 'https://example.com/old.mp4',
          'cloudinaryPublicId': 'old',
          'authorId': 'one',
          'authorName': 'Ana',
          'createdAt': Timestamp.fromDate(DateTime.utc(2025)),
        }),
      ];

    final video = (await VideoRepository(store: store).watchVideos().first)
        .single;

    expect(video.mediaType, MediaType.video);
    expect(video.mediaUrl, 'https://example.com/old.mp4');
  });

  test('ordena registros persistidos y tolera fecha pendiente', () async {
    final store = _Store()
      ..documents = [
        VideoDocument('old', {
          'title': 'Antiguo',
          'description': '',
          'videoUrl': 'https://example.com/old.mp4',
          'cloudinaryPublicId': 'old',
          'authorId': 'one',
          'authorName': 'Ana',
          'createdAt': Timestamp.fromDate(DateTime.utc(2025)),
        }),
        VideoDocument('pending', {
          'title': 'Pendiente',
          'description': '',
          'mediaType': 'image',
          'mediaUrl': 'https://example.com/pending.jpg',
          'cloudinaryPublicId': 'pending',
          'authorId': 'one',
          'authorName': 'Ana',
          'createdAt': null,
        }),
        VideoDocument('new', {
          'title': 'Nuevo',
          'description': '',
          'mediaType': 'video',
          'mediaUrl': 'https://example.com/new.mp4',
          'cloudinaryPublicId': 'new',
          'authorId': 'two',
          'authorName': 'Luis',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
        }),
      ];

    final videos = await VideoRepository(store: store).watchVideos().first;

    expect(videos.map((video) => video.id), ['new', 'old', 'pending']);
    expect(videos.last.createdAt, isNull);
    expect(videos.last.mediaType, MediaType.image);
  });
}
