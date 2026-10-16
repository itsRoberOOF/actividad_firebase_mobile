import 'package:cloud_firestore/cloud_firestore.dart';

class VideoRecord {
  const VideoRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.cloudinaryPublicId,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String cloudinaryPublicId;
  final String authorId;
  final String authorName;
  final DateTime? createdAt;

  factory VideoRecord.fromDocument(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];
    return VideoRecord(
      id: id,
      title: data['title'] as String,
      description: data['description'] as String,
      videoUrl: data['videoUrl'] as String,
      cloudinaryPublicId: data['cloudinaryPublicId'] as String,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
