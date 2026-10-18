import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/videos/like_repository.dart';

/// Simula la subcolección `likes`: un documento por UID y emisión en tiempo real.
class _FakeLikeStore implements LikeStore {
  final Set<String> _uids = {};
  final _controller = StreamController<Set<String>>.broadcast();
  final List<String> writes = [];
  bool fail = false;

  @override
  Stream<Set<String>> watch(String postId) async* {
    yield Set.of(_uids);
    yield* _controller.stream;
  }

  @override
  Future<void> write(String postId, String uid, {required bool liked}) async {
    if (fail) throw StateError('permiso denegado');
    writes.add('$postId:$uid:${liked ? 'like' : 'unlike'}');
    if (liked) {
      _uids.add(uid);
    } else {
      _uids.remove(uid);
    }
    _controller.add(Set.of(_uids));
  }

  void close() => _controller.close();
}

void main() {
  late _FakeLikeStore store;
  late LikeRepository repository;

  setUp(() {
    store = _FakeLikeStore();
    repository = LikeRepository(store: store);
  });

  tearDown(() => store.close());

  test('dar like crea un documento por usuario y el conteo cambia en vivo', () async {
    final states = <PostLikes>[];
    final subscription = repository
        .watchLikes('post-1', viewerId: 'ana')
        .listen(states.add);

    await Future<void>.delayed(Duration.zero);
    await repository.setLiked(postId: 'post-1', viewerId: 'ana', liked: true);
    await repository.setLiked(postId: 'post-1', viewerId: 'luis', liked: true);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(store.writes, ['post-1:ana:like', 'post-1:luis:like']);
    expect(states.first.count, 0);
    expect(states.first.likedByViewer, isFalse);
    expect(states.last.count, 2);
    expect(states.last.likedByViewer, isTrue);
  });

  test('quitar el like elimina el documento del usuario', () async {
    await repository.setLiked(postId: 'post-1', viewerId: 'ana', liked: true);

    final states = <PostLikes>[];
    final subscription = repository
        .watchLikes('post-1', viewerId: 'ana')
        .listen(states.add);
    await Future<void>.delayed(Duration.zero);
    expect(states.last.likedByViewer, isTrue);

    await repository.setLiked(postId: 'post-1', viewerId: 'ana', liked: false);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(states.last.count, 0);
    expect(states.last.likedByViewer, isFalse);
  });

  test('sin usuario autenticado no marca el like propio', () async {
    await repository.setLiked(postId: 'post-1', viewerId: 'ana', liked: true);

    final first = await repository
        .watchLikes('post-1', viewerId: null)
        .first;

    expect(first.count, 1);
    expect(first.likedByViewer, isFalse);
  });

  test('exige un UID para escribir el like', () {
    expect(
      () => repository.setLiked(postId: 'post-1', viewerId: '', liked: true),
      throwsArgumentError,
    );
    expect(store.writes, isEmpty);
  });

  test('propaga el error de Firestore en lugar de ocultarlo', () async {
    store.fail = true;

    await expectLater(
      repository.setLiked(postId: 'post-1', viewerId: 'ana', liked: true),
      throwsA(isA<StateError>()),
    );
  });
}
