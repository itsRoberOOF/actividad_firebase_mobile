import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'video_publisher.dart';

typedef VideoPicker = Future<XFile?> Function();

class VideoUploadDialog extends StatefulWidget {
  const VideoUploadDialog({
    super.key,
    required this.publisher,
    required this.author,
    this.pickVideo,
  });

  final VideoPublisher publisher;
  final User? author;
  final VideoPicker? pickVideo;

  @override
  State<VideoUploadDialog> createState() => _VideoUploadDialogState();
}

class _VideoUploadDialogState extends State<VideoUploadDialog> {
  final title = TextEditingController();
  final description = TextEditingController();
  XFile? selected;
  int? selectedBytes;
  bool busy = false;
  double progress = 0;
  String? error;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> selectVideo() async {
    if (busy) return;
    try {
      final picked =
          await (widget.pickVideo?.call() ??
              ImagePicker().pickVideo(source: ImageSource.gallery));
      if (picked == null) return;
      final bytes = await picked.length();
      validateVideoSelection(
        name: picked.name,
        mimeType: picked.mimeType,
        bytes: bytes,
      );
      if (mounted) {
        setState(() {
          selected = picked;
          selectedBytes = bytes;
          error = null;
        });
      }
    } on VideoPublishException catch (problem) {
      if (mounted) setState(() => error = problem.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo abrir el video. Inténtalo otra vez.',
        );
      }
    }
  }

  Future<void> publish() async {
    if (busy) return;
    final file = selected;
    if (file == null) {
      setState(() => error = 'Selecciona un video para continuar.');
      return;
    }
    setState(() {
      busy = true;
      progress = 0;
      error = null;
    });
    try {
      await widget.publisher.publish(
        file: file,
        title: title.text,
        description: description.text,
        author: widget.author,
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on VideoPublishException catch (problem) {
      if (mounted) setState(() => error = problem.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo publicar el video. Inténtalo otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF102B3C);
    const sky = Color(0xFF37BCE8);
    const muted = Color(0xFF5A7180);
    final configured = widget.publisher.uploader.isConfigured;
    final file = selected;

    return PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: const Color(0xFFF8FCFE),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDF5FC),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Subir video',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comparte algo que valga la pena ver.',
                  style: TextStyle(color: muted, fontSize: 15),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD5E3E9)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : selectVideo,
                        icon: const Icon(Icons.video_library_outlined),
                        label: const Text('Seleccionar video'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        file == null
                            ? 'MP4, MOV, M4V o WebM · máximo 100 MB'
                            : '${file.name.isEmpty ? 'Video seleccionado' : file.name} · ${((selectedBytes ?? 0) / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Título',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('video-title'),
                  controller: title,
                  maxLength: 100,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: '¿De qué trata tu video?',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Descripción',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('video-description'),
                  controller: description,
                  maxLength: 1000,
                  maxLines: 3,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Cuéntanos un poco más (opcional)',
                    counterText: '',
                  ),
                ),
                if (!configured) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Configura Cloudinary para poder publicar videos.',
                    style: TextStyle(color: Color(0xFF8A4E10)),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFF9C3427)),
                  ),
                ],
                if (busy) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress, color: sky),
                  const SizedBox(height: 6),
                  Text(
                    'Subiendo ${(progress * 100).round()} %',
                    style: const TextStyle(color: muted),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy || !configured ? null : publish,
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Publicar video'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
