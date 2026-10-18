import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'like_repository.dart';
import 'video_repository.dart';

typedef VideoStageBuilder = Widget Function(
  BuildContext context,
  VideoRecord record,
  bool isActive,
);

class VideoList extends StatefulWidget {
  const VideoList({
    super.key,
    required this.repository,
    this.videoBuilder,
    this.likeRepository,
    this.viewerId,
  });

  final VideoRepository repository;
  final VideoStageBuilder? videoBuilder;

  /// Sin repositorio de likes el feed no muestra controles de like.
  final LikeRepository? likeRepository;
  final String? viewerId;

  @override
  State<VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  late Stream<List<VideoRecord>> _videos;
  final ScrollController _scrollController = ScrollController();
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _videos = widget.repository.watchVideos();
  }

  @override
  void didUpdateWidget(covariant VideoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _videos = widget.repository.watchVideos();
      _activeIndex = 0;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<VideoRecord>>(
    stream: _videos,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _FeedMessage(
          icon: Icons.wifi_off_rounded,
          title: 'No pudimos cargar las publicaciones',
          detail: 'Revisa tu conexión e inténtalo de nuevo.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = snapshot.data!;
      if (records.isEmpty) {
        return const _FeedMessage(
          icon: Icons.video_library_outlined,
          title: 'Todavía no hay publicaciones',
          detail: 'Pulsa “Nueva publicación” para compartir la primera.',
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) =>
            NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                final nextIndex =
                    (notification.metrics.pixels / constraints.maxHeight)
                        .round()
                        .clamp(0, records.length);
                if (nextIndex != _activeIndex) {
                  setState(() => _activeIndex = nextIndex);
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                physics: const PageScrollPhysics(),
                itemExtent: constraints.maxHeight,
                itemCount: records.length + 1,
                itemBuilder: (context, index) {
                  if (index == records.length) {
                    return const _FeedMessage(
                      icon: Icons.video_library_outlined,
                      title: 'Ya viste todo',
                      detail: 'Vuelve más tarde para descubrir nuevas publicaciones.',
                    );
                  }
                  final record = records[index];
                  final isActive = index == _activeIndex;
                  final likeRepository = widget.likeRepository;
                  return _PostPage(
                    key: ValueKey(record.id),
                    record: record,
                    media: _buildMedia(context, record, isActive),
                    likeButton: likeRepository == null
                        ? null
                        : _LikeButton(
                            key: ValueKey('like-${record.id}'),
                            repository: likeRepository,
                            postId: record.id,
                            viewerId: widget.viewerId,
                          ),
                  );
                },
              ),
            ),
      );
    },
  );

  Widget _buildMedia(BuildContext context, VideoRecord record, bool isActive) {
    if (record.mediaType == MediaType.image) {
      return _PhotoStage(key: ValueKey('photo-${record.id}'), url: record.mediaUrl);
    }
    return widget.videoBuilder?.call(context, record, isActive) ??
        _VideoStage(
          key: ValueKey('stage-${record.id}'),
          record: record,
          isActive: isActive,
        );
  }
}

class _PostPage extends StatelessWidget {
  const _PostPage({
    super.key,
    required this.record,
    required this.media,
    required this.likeButton,
  });

  final VideoRecord record;
  final Widget media;
  final Widget? likeButton;

  @override
  Widget build(BuildContext context) {
    final date = record.createdAt;
    final dateText = date == null
        ? 'Publicando…'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: media),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD9000000)],
                stops: [0.42, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 80,
          bottom: 94,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (record.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  record.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.white),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${record.authorName} · $dateText',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: const Color(0xFFBCECFB)),
              ),
            ],
          ),
        ),
        if (likeButton != null)
          Positioned(right: 16, bottom: 160, child: likeButton!),
      ],
    );
  }
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({
    super.key,
    required this.repository,
    required this.postId,
    required this.viewerId,
  });

  final LikeRepository repository;
  final String postId;
  final String? viewerId;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  late Stream<PostLikes> _likes;

  @override
  void initState() {
    super.initState();
    _likes = _watch();
  }

  @override
  void didUpdateWidget(covariant _LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.postId != widget.postId ||
        oldWidget.viewerId != widget.viewerId) {
      _likes = _watch();
    }
  }

  Stream<PostLikes> _watch() => widget.repository.watchLikes(
    widget.postId,
    viewerId: widget.viewerId,
  );

  Future<void> _toggle(bool liked) async {
    final viewerId = widget.viewerId;
    if (viewerId == null) return;
    try {
      await widget.repository.setLiked(
        postId: widget.postId,
        viewerId: viewerId,
        liked: liked,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar tu like.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PostLikes>(
    stream: _likes,
    builder: (context, snapshot) {
      final likes = snapshot.data;
      final liked = likes?.likedByViewer ?? false;
      final canToggle = widget.viewerId != null && likes != null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: liked ? 'Quitar like' : 'Dar like',
            onPressed: canToggle ? () => _toggle(!liked) : null,
            icon: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? const Color(0xFFFF5C7A) : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            likes == null ? '—' : '${likes.count}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    },
  );
}

class _PhotoStage extends StatelessWidget {
  const _PhotoStage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Text(
          'No se pudo mostrar la foto.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}

class _VideoStage extends StatefulWidget {
  const _VideoStage({super.key, required this.record, required this.isActive});

  final VideoRecord record;
  final bool isActive;

  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _start();
  }

  @override
  void didUpdateWidget(covariant _VideoStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.mediaUrl != widget.record.mediaUrl ||
        oldWidget.isActive != widget.isActive) {
      _stop();
      if (widget.isActive) _start();
    }
  }

  Future<void> _start() async {
    _failed = false;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.record.mediaUrl),
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) return;
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      if (mounted && identical(_controller, controller)) setState(() {});
    } catch (_) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _failed = true);
      }
    }
  }

  void _stop() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            _stop();
            setState(() => _failed = false);
            _start();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('No se pudo reproducir. Reintentar'),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 94,
          child: IconButton.filledTonal(
            tooltip: _muted ? 'Activar sonido' : 'Silenciar',
            onPressed: () {
              setState(() => _muted = !_muted);
              controller.setVolume(_muted ? 0 : 1);
            },
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF102B3C),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF37BCE8)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: const Color(0xFFBCECFB)),
            ),
          ],
        ),
      ),
    ),
  );
}
