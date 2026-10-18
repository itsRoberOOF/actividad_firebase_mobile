import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/videos/like_repository.dart';
import 'package:videoteca/videos/video_list.dart';
import 'package:videoteca/videos/video_repository.dart';

class _Store implements VideoDocumentStore {
  _Store(this.documents);

  final List<VideoDocument> documents;

  @override
  Future<void> add(Map<String, dynamic> data) async {}

  @override
  Stream<List<VideoDocument>> watch() => Stream.value(documents);
}

class _LikeStore implements LikeStore {
  _LikeStore(Set<String> initial) : _uids = {...initial};

  final Set<String> _uids;
  final _controller = StreamController<Set<String>>.broadcast();

  @override
  Stream<Set<String>> watch(String postId) async* {
    yield Set.of(_uids);
    yield* _controller.stream;
  }

  @override
  Future<void> write(String postId, String uid, {required bool liked}) async {
    if (liked) {
      _uids.add(uid);
    } else {
      _uids.remove(uid);
    }
    _controller.add(Set.of(_uids));
  }
}

VideoDocument _video(String id, String title, DateTime date) =>
    VideoDocument(id, {
      'title': title,
      'description': 'Descripción de $title',
      'mediaType': 'video',
      'mediaUrl': 'https://example.com/$id.mp4',
      'cloudinaryPublicId': id,
      'authorId': 'author',
      'authorName': 'Ana',
      'createdAt': Timestamp.fromDate(date),
    });

VideoDocument _legacyVideo(String id, String title, DateTime date) =>
    VideoDocument(id, {
      'title': title,
      'description': '',
      'videoUrl': 'https://example.com/$id.mp4',
      'cloudinaryPublicId': id,
      'authorId': 'author',
      'authorName': 'Ana',
      'createdAt': Timestamp.fromDate(date),
    });

VideoDocument _photo(String id, String title, DateTime date) =>
    VideoDocument(id, {
      'title': title,
      'description': '',
      'mediaType': 'image',
      'mediaUrl': 'https://example.com/$id.jpg',
      'cloudinaryPublicId': id,
      'authorId': 'author',
      'authorName': 'Ana',
      'createdAt': Timestamp.fromDate(date),
    });

void main() {
  testWidgets('avanza por publicaciones y muestra el fin del feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoList(
            repository: VideoRepository(
              store: _Store([
                _video('one', 'Primero', DateTime(2026, 10, 14)),
                _video('two', 'Segundo', DateTime(2026, 10, 13)),
              ]),
            ),
            videoBuilder: (context, record, isActive) => ColoredBox(
              key: ValueKey('player-${record.id}'),
              color: Colors.black,
              child: Center(
                child: Text(
                  isActive ? 'Activo ${record.id}' : 'Pausado ${record.id}',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Primero'), findsOneWidget);
    expect(find.text('Descripción de Primero'), findsOneWidget);
    expect(find.text('Ana · 14/10/2026'), findsOneWidget);
    expect(find.text('Activo one'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsOneWidget);
    expect(find.text('Activo two'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Ya viste todo'), findsOneWidget);
    expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    expect(find.text('Activo two'), findsNothing);
  });

  testWidgets('las fotos no pasan por el reproductor de video', (tester) async {
    final playerIds = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoList(
            repository: VideoRepository(
              store: _Store([
                _photo('foto', 'Foto', DateTime(2026, 10, 15)),
                _legacyVideo('antiguo', 'Antiguo', DateTime(2026, 10, 14)),
              ]),
            ),
            videoBuilder: (context, record, isActive) {
              playerIds.add(record.id);
              return const ColoredBox(color: Colors.black);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Foto'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(playerIds, isNot(contains('foto')));

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Antiguo'), findsOneWidget);
    expect(playerIds, contains('antiguo'));
  });

  testWidgets('muestra el conteo de likes y alterna el like del usuario', (
    tester,
  ) async {
    final likeStore = _LikeStore({'otra-persona'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoList(
            repository: VideoRepository(
              store: _Store([
                _video('one', 'Primero', DateTime(2026, 10, 14)),
              ]),
            ),
            likeRepository: LikeRepository(store: likeStore),
            viewerId: 'ana',
            videoBuilder: (context, record, isActive) =>
                const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Dar like'), findsOneWidget);

    await tester.tap(find.byTooltip('Dar like'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.byTooltip('Quitar like'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar like'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Dar like'), findsOneWidget);
  });

  testWidgets('sin repositorio de likes no muestra controles de like', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoList(
            repository: VideoRepository(
              store: _Store([_photo('foto', 'Foto', DateTime(2026, 10, 15))]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Dar like'), findsNothing);
  });
}
