import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_repository.dart';

typedef VideoStageBuilder = Widget Function(
  BuildContext context,
  VideoRecord record,
  bool isActive,
);

class VideoList extends StatefulWidget {
  const VideoList({super.key, required this.repository, this.videoBuilder});

  final VideoRepository repository;
  final VideoStageBuilder? videoBuilder;

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
          title: 'No pudimos cargar los videos',
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
          title: 'Todavía no hay videos',
          detail: 'Pulsa “Subir video” para compartir el primero.',
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
                      title: 'Ya viste todos los videos',
                      detail: 'Vuelve más tarde para descubrir nuevos clips.',
                    );
                  }
                  final record = records[index];
                  return _VideoPage(
                    key: ValueKey(record.id),
                    record: record,
                    video:
                        widget.videoBuilder?.call(
                          context,
                          record,
                          index == _activeIndex,
                        ) ??
                        _VideoStage(
                          key: ValueKey('stage-${record.id}'),
                          record: record,
                          isActive: index == _activeIndex,
                        ),
                  );
                },
              ),
            ),
      );
    },
  );
}

class _VideoPage extends StatelessWidget {
  const _VideoPage({super.key, required this.record, required this.video});

  final VideoRecord record;
  final Widget video;

  @override
  Widget build(BuildContext context) {
    final date = record.createdAt;
    final dateText = date == null
        ? 'Publicando…'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: video),
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
      ],
    );
  }
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
    if (oldWidget.record.videoUrl != widget.record.videoUrl ||
        oldWidget.isActive != widget.isActive) {
      _stop();
      if (widget.isActive) _start();
    }
  }

  Future<void> _start() async {
    _failed = false;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.record.videoUrl),
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
