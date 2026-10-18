import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/camera_capture_types.dart';
import '../filters/face_filter_service.dart';
import '../filters/filter_kind.dart';
import 'media_publisher.dart';
import 'media_type.dart';

typedef MediaPicker = Future<XFile?> Function();

enum _Phase { idle, applyingFilter, uploading }

class MediaUploadDialog extends StatefulWidget {
  const MediaUploadDialog({
    super.key,
    required this.publisher,
    required this.author,
    this.pickPhoto,
    this.pickVideo,
    this.capture,
    this.filters,
  });

  final MediaPublisher publisher;
  final User? author;
  final MediaPicker? pickPhoto;
  final MediaPicker? pickVideo;

  /// Null fuera de Android: no hay cámara en la interfaz.
  final CameraCaptureLauncher? capture;

  /// Null fuera de Android: no hay filtros ML en la interfaz.
  final FaceFilterService? filters;

  @override
  State<MediaUploadDialog> createState() => _MediaUploadDialogState();
}

class _MediaUploadDialogState extends State<MediaUploadDialog> {
  final title = TextEditingController();
  final description = TextEditingController();
  XFile? selected;
  MediaType? selectedType;
  int? selectedBytes;
  FaceFilter? filter;
  bool busy = false;
  _Phase phase = _Phase.idle;
  double progress = 0;
  String? error;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  void _setError(String message) {
    if (mounted) setState(() => error = message);
  }

  Future<void> _select(Future<XFile?> Function() pick) async {
    if (busy) return;
    try {
      final picked = await pick();
      if (picked == null) return;
      final bytes = await picked.length();
      final type = validateMediaSelection(
        name: picked.name,
        mimeType: picked.mimeType,
        bytes: bytes,
      );
      if (mounted) {
        setState(() {
          selected = picked;
          selectedType = type;
          selectedBytes = bytes;
          error = null;
        });
      }
    } on MediaPublishException catch (problem) {
      _setError(problem.message);
    } catch (_) {
      _setError('No se pudo abrir el archivo. Inténtalo otra vez.');
    }
  }

  Future<void> publish() async {
    if (busy) return;
    final file = selected;
    final type = selectedType;
    if (file == null || type == null) {
      setState(() => error = 'Selecciona una foto o un video para continuar.');
      return;
    }
    setState(() {
      busy = true;
      progress = 0;
      error = null;
      phase = _Phase.idle;
    });
    try {
      var toUpload = file;
      final chosen = filter;
      final service = widget.filters;
      if (chosen != null && service != null) {
        setState(() => phase = _Phase.applyingFilter);
        toUpload = type == MediaType.image
            ? await service.applyToPhoto(file, chosen)
            : await service.applyToVideo(
                file,
                chosen,
                onProgress: (value) {
                  if (mounted) setState(() => progress = value);
                },
              );
      }
      if (mounted) {
        setState(() {
          phase = _Phase.uploading;
          progress = 0;
        });
      }
      await widget.publisher.publish(
        file: toUpload,
        title: title.text,
        description: description.text,
        author: widget.author,
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FilterException catch (problem) {
      _setError(problem.message);
    } on MediaPublishException catch (problem) {
      _setError(problem.message);
    } catch (_) {
      _setError('No se pudo publicar. Inténtalo otra vez.');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          phase = _Phase.idle;
        });
      }
    }
  }

  String get _progressLabel => switch (phase) {
    _Phase.applyingFilter when selectedType == MediaType.video =>
      'Aplicando filtro ${(progress * 100).round()} %',
    _Phase.applyingFilter => 'Aplicando filtro…',
    _Phase.uploading => 'Subiendo ${(progress * 100).round()} %',
    _Phase.idle => '',
  };

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF102B3C);
    const sky = Color(0xFF37BCE8);
    const muted = Color(0xFF5A7180);
    final configured = widget.publisher.uploader.isConfigured;
    final file = selected;
    final indeterminate =
        phase == _Phase.applyingFilter && selectedType == MediaType.image;

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
                        'Nueva publicación',
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
                  'Comparte una foto o un video.',
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _select(
                                    widget.pickPhoto ??
                                        () => ImagePicker().pickImage(
                                          source: ImageSource.gallery,
                                        ),
                                  ),
                            icon: const Icon(Icons.photo_outlined),
                            label: const Text('Foto'),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _select(
                                    widget.pickVideo ??
                                        () => ImagePicker().pickVideo(
                                          source: ImageSource.gallery,
                                        ),
                                  ),
                            icon: const Icon(Icons.video_library_outlined),
                            label: const Text('Video'),
                          ),
                          if (widget.capture != null)
                            OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _select(
                                      () => widget.capture!(context),
                                    ),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Cámara'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        file == null
                            ? 'Foto JPG, PNG o WebP · Video MP4, MOV, M4V o WebM · máximo 100 MB'
                            : '${file.name.isEmpty ? 'Archivo seleccionado' : file.name} · ${((selectedBytes ?? 0) / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (widget.filters != null && file != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Filtro facial',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Sin filtro'),
                        selected: filter == null,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => filter = null),
                      ),
                      for (final option in FaceFilter.values)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: filter == option,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => filter = option),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Título',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('media-title'),
                  controller: title,
                  maxLength: 100,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: '¿Qué estás compartiendo?',
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
                  key: const Key('media-description'),
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
                    'Configura Cloudinary para poder publicar.',
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
                  LinearProgressIndicator(
                    value: indeterminate ? null : progress,
                    color: sky,
                  ),
                  const SizedBox(height: 6),
                  Text(_progressLabel, style: const TextStyle(color: muted)),
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
                    label: const Text('Publicar'),
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
