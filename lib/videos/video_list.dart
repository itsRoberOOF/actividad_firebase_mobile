import 'package:flutter/material.dart';

import 'video_repository.dart';

class VideoList extends StatefulWidget {
  const VideoList({super.key, required this.repository});

  final VideoRepository repository;

  @override
  State<VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  late Stream<List<VideoRecord>> videos;

  @override
  void initState() {
    super.initState();
    videos = widget.repository.watchVideos();
  }

  @override
  void didUpdateWidget(covariant VideoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      videos = widget.repository.watchVideos();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<VideoRecord>>(
    stream: videos,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('No pudimos cargar los videos. Revisa tu conexión.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = snapshot.data!;
      if (records.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.video_library_outlined,
                  size: 62,
                  color: Color(0xFF087FAC),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Todavía no hay videos',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102B3C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pulsa “Subir video” para compartir el primero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey.shade600),
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _VideoCard(record: records[index]),
      );
    },
  );
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.record});

  final VideoRecord record;

  @override
  Widget build(BuildContext context) {
    final date = record.createdAt;
    final dateText = date == null
        ? 'Publicando…'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD5E3E9)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFDDF5FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.video_file_outlined,
              color: Color(0xFF087FAC),
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102B3C),
                  ),
                ),
                if (record.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    record.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  '${record.authorName} · $dateText',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5A7180),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
