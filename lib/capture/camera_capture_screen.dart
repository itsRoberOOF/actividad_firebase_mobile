import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Límite de la demo: los filtros de video se procesan en clips cortos.
const maxRecordingDuration = Duration(seconds: 15);

/// Captura una foto o un video con la cámara trasera. Devuelve el archivo al
/// cerrarse; si la persona cancela, devuelve null.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  Timer? _recordingLimit;
  String? _error;
  bool _videoMode = false;
  bool _busy = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _recordingLimit?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Sin cámaras');
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos abrir la cámara. Revisa los permisos e inténtalo otra vez.',
        );
      }
    }
  }

  Future<void> _shutter() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    if (_recording) {
      await _stopRecording();
      return;
    }
    setState(() => _busy = true);
    try {
      if (_videoMode) {
        await controller.startVideoRecording();
        _recordingLimit = Timer(maxRecordingDuration, () => _stopRecording());
        if (mounted) setState(() => _recording = true);
      } else {
        final photo = await controller.takePicture();
        if (mounted) Navigator.of(context).pop(photo);
      }
    } catch (_) {
      _showCaptureError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_recording) return;
    _recordingLimit?.cancel();
    setState(() => _busy = true);
    try {
      final video = await controller.stopVideoRecording();
      if (mounted) Navigator.of(context).pop(video);
    } catch (_) {
      _recording = false;
      _showCaptureError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showCaptureError() {
    if (!mounted) return;
    setState(() {
      _recording = false;
      _error = 'No pudimos capturar. Inténtalo otra vez.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_videoMode ? 'Grabar video' : 'Tomar foto'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            )
          : !ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Foto'),
                              icon: Icon(Icons.photo_camera_outlined),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Video'),
                              icon: Icon(Icons.videocam_outlined),
                            ),
                          ],
                          selected: {_videoMode},
                          onSelectionChanged: _busy || _recording
                              ? null
                              : (selection) =>
                                    setState(() => _videoMode = selection.first),
                        ),
                        const SizedBox(height: 16),
                        Tooltip(
                          message: _recording
                              ? 'Detener grabación'
                              : _videoMode
                              ? 'Grabar video'
                              : 'Tomar foto',
                          child: FilledButton(
                            onPressed: _busy ? null : _shutter,
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(22),
                              backgroundColor: _recording
                                  ? Colors.redAccent
                                  : Colors.white,
                              foregroundColor: Colors.black,
                            ),
                            child: Icon(
                              _recording
                                  ? Icons.stop_rounded
                                  : _videoMode
                                  ? Icons.fiber_manual_record
                                  : Icons.camera_alt_rounded,
                              size: 32,
                            ),
                          ),
                        ),
                        if (_recording) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Grabando… máximo 15 segundos',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
