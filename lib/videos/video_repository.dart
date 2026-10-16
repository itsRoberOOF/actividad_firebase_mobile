import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'video_record.dart';

export 'video_record.dart';

class VideoDocument {
  const VideoDocument(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

abstract class VideoDocumentStore {
  Future<void> add(Map<String, dynamic> data);
  Stream<List<VideoDocument>> watch();
}

class FirestoreVideoDocumentStore implements VideoDocumentStore {
  FirestoreVideoDocumentStore(FirebaseFirestore firestore)
    : _collection = firestore.collection('videos');

  final CollectionReference<Map<String, dynamic>> _collection;

  @override
  Future<void> add(Map<String, dynamic> data) async {
    await _collection.add(data);
  }

  @override
  Stream<List<VideoDocument>> watch() => _collection
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((document) => VideoDocument(document.id, document.data()))
            .toList(),
      );
}

class VideoRepository {
  VideoRepository({VideoDocumentStore? store})
    : _store = store ?? FirestoreVideoDocumentStore(FirebaseFirestore.instance);

  final VideoDocumentStore _store;

  Stream<List<VideoRecord>> watchVideos() => _store.watch().map((documents) {
    final videos = documents
        .map((document) => VideoRecord.fromDocument(document.id, document.data))
        .toList();
    videos.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null) return bDate == null ? 0 : 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return videos;
  });

  Future<void> createVideo({
    required String title,
    required String description,
    required String videoUrl,
    required String cloudinaryPublicId,
    required User author,
  }) async {
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 100) {
      throw ArgumentError.value(
        title,
        'title',
        'Debe tener de 1 a 100 caracteres',
      );
    }
    if (cleanDescription.length > 1000) {
      throw ArgumentError.value(
        description,
        'description',
        'Máximo 1000 caracteres',
      );
    }
    final displayName = author.displayName?.trim();
    final authorName = displayName == null || displayName.isEmpty
        ? 'Usuario'
        : displayName.length > 100
        ? displayName.substring(0, 100)
        : displayName;
    await _store.add({
      'title': cleanTitle,
      'description': cleanDescription,
      'videoUrl': videoUrl,
      'cloudinaryPublicId': cloudinaryPublicId,
      'authorId': author.uid,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
