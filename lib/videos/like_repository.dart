import 'package:cloud_firestore/cloud_firestore.dart';

class PostLikes {
  const PostLikes({required this.count, required this.likedByViewer});

  final int count;
  final bool likedByViewer;
}

/// Acceso a `videos/{postId}/likes/{uid}`. Cada like es un documento cuyo ID es
/// el UID de Firebase Auth, así una persona tiene como máximo un like por
/// publicación.
abstract class LikeStore {
  /// UIDs que dieron like, en tiempo real.
  Stream<Set<String>> watch(String postId);

  Future<void> write(String postId, String uid, {required bool liked});
}

class FirestoreLikeStore implements LikeStore {
  FirestoreLikeStore(FirebaseFirestore firestore) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _likes(String postId) =>
      _firestore.collection('videos').doc(postId).collection('likes');

  @override
  Stream<Set<String>> watch(String postId) => _likes(postId).snapshots().map(
    (snapshot) => snapshot.docs.map((document) => document.id).toSet(),
  );

  @override
  Future<void> write(String postId, String uid, {required bool liked}) {
    final document = _likes(postId).doc(uid);
    return liked
        ? document.set({'uid': uid, 'createdAt': FieldValue.serverTimestamp()})
        : document.delete();
  }
}

/// Crea el almacén de Firestore en el primer uso: construir el repositorio no
/// exige Firebase inicializado.
class _LazyFirestoreLikeStore implements LikeStore {
  _LazyFirestoreLikeStore(this._firestore);

  final FirebaseFirestore? _firestore;
  FirestoreLikeStore? _store;

  FirestoreLikeStore get _resolved => _store ??= FirestoreLikeStore(
    _firestore ?? FirebaseFirestore.instance,
  );

  @override
  Stream<Set<String>> watch(String postId) => _resolved.watch(postId);

  @override
  Future<void> write(String postId, String uid, {required bool liked}) =>
      _resolved.write(postId, uid, liked: liked);
}

class LikeRepository {
  LikeRepository({LikeStore? store, FirebaseFirestore? firestore})
    : _store = store ?? _LazyFirestoreLikeStore(firestore);

  final LikeStore _store;

  Stream<PostLikes> watchLikes(String postId, {required String? viewerId}) =>
      _store
          .watch(postId)
          .map(
            (uids) => PostLikes(
              count: uids.length,
              likedByViewer: viewerId != null && uids.contains(viewerId),
            ),
          );

  Future<void> setLiked({
    required String postId,
    required String viewerId,
    required bool liked,
  }) {
    if (viewerId.isEmpty) {
      throw ArgumentError.value(viewerId, 'viewerId', 'Falta el usuario');
    }
    return _store.write(postId, viewerId, liked: liked);
  }
}
