import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

VideoDocument _video(String id, String title, DateTime date) =>
    VideoDocument(id, {
      'title': title,
      'description': 'Descripción de $title',
      'videoUrl': 'https://example.com/$id.mp4',
      'cloudinaryPublicId': id,
      'authorId': 'author',
      'authorName': 'Ana',
      'createdAt': Timestamp.fromDate(date),
    });

void main() {
  testWidgets('avanza por videos y muestra el fin del feed', (tester) async {
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
    expect(find.text('Ya viste todos los videos'), findsOneWidget);
    expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    expect(find.text('Activo two'), findsNothing);
  });
}
