import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'face_filter_service.dart';
import 'face_geometry.dart';
import 'filter_kind.dart';
import 'sprite_compositor.dart';

/// Filtros sólo en Android: ML Kit y el puente de video no existen en web ni en
/// otras plataformas.
FaceFilterService? createFaceFilterService() => defaultTargetPlatform ==
        TargetPlatform.android
    ? NativeFaceFilterService()
    : null;

typedef SpriteLoader = Future<Uint8List> Function(String asset);
typedef TemporaryDirectoryProvider = Future<Directory> Function();

Future<Uint8List> _loadAsset(String asset) async {
  final data = await rootBundle.load(asset);
  return data.buffer.asUint8List();
}

abstract class FaceLandmarkDetector {
  Future<List<FaceLandmarks>> detect(String imagePath);
}

class MlKitFaceLandmarkDetector implements FaceLandmarkDetector {
  @override
  Future<List<FaceLandmarks>> detect(String imagePath) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    try {
      final faces = await detector.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return faces.map(_fromFace).toList();
    } finally {
      await detector.close();
    }
  }

  FaceLandmarks _fromFace(Face face) {
    final box = face.boundingBox;
    return FaceLandmarks(
      boundingBox: math.Rectangle(box.left, box.top, box.width, box.height),
      leftEye: _point(face.landmarks[FaceLandmarkType.leftEye]),
      rightEye: _point(face.landmarks[FaceLandmarkType.rightEye]),
      noseBase: _point(face.landmarks[FaceLandmarkType.noseBase]),
      leftMouth: _point(face.landmarks[FaceLandmarkType.leftMouth]),
      rightMouth: _point(face.landmarks[FaceLandmarkType.rightMouth]),
    );
  }

  math.Point<double>? _point(FaceLandmark? landmark) => landmark == null
      ? null
      : math.Point(
          landmark.position.x.toDouble(),
          landmark.position.y.toDouble(),
        );
}

abstract class VideoFilterGateway {
  Future<String> applyVideoFilter({
    required String inputPath,
    required String outputPath,
    required String overlayPath,
    required FaceFilter filter,
    required void Function(double) onProgress,
  });
}

/// Progreso global del análisis (30 %) y la exportación (70 %).
double overallVideoProgress(String stage, double progress) {
  final clamped = progress.clamp(0.0, 1.0).toDouble();
  return stage == 'analyzing' ? clamped * 0.3 : 0.3 + clamped * 0.7;
}

FilterException filterExceptionFor(String code) => switch (code) {
  'NO_FACE' => const FilterException(
    'No detectamos un rostro en el video. Prueba con otro clip o cambia de filtro.',
    code: 'NO_FACE',
  ),
  'TOO_LONG' => const FilterException(
    'El video dura más de 15 segundos. Graba o elige un clip más corto.',
    code: 'TOO_LONG',
  ),
  'INVALID_VIDEO' => const FilterException(
    'No pudimos leer el video. Elige otro archivo.',
    code: 'INVALID_VIDEO',
  ),
  _ => const FilterException(
    'No pudimos aplicar el filtro al video. Inténtalo otra vez.',
    code: 'EXPORT_FAILED',
  ),
};

class MethodChannelVideoFilterGateway implements VideoFilterGateway {
  static const _method = MethodChannel('videoteca/video_filters');
  static const _progressEvents = EventChannel('videoteca/video_filters/progress');

  @override
  Future<String> applyVideoFilter({
    required String inputPath,
    required String outputPath,
    required String overlayPath,
    required FaceFilter filter,
    required void Function(double) onProgress,
  }) async {
    final subscription = _progressEvents.receiveBroadcastStream().listen((
      event,
    ) {
      if (event is! Map) return;
      final stage = event['stage'];
      final progress = event['progress'];
      if (stage is String && progress is num) {
        onProgress(overallVideoProgress(stage, progress.toDouble()));
      }
    });
    try {
      final result = await _method.invokeMethod<String>('applyVideoFilter', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'overlayPath': overlayPath,
        'filter': filter.nativeName,
        'maxDurationMs': 15000,
        'maxHeight': 720,
      });
      return result ?? outputPath;
    } on PlatformException catch (error) {
      throw filterExceptionFor(error.code);
    } on MissingPluginException {
      throw const FilterException(
        'Los filtros de video solo están disponibles en Android.',
        code: 'UNSUPPORTED',
      );
    } finally {
      await subscription.cancel();
    }
  }
}

class NativeFaceFilterService implements FaceFilterService {
  NativeFaceFilterService({
    FaceLandmarkDetector? detector,
    VideoFilterGateway? video,
    SpriteLoader? loadSprite,
    TemporaryDirectoryProvider? temporaryDirectory,
  }) : _detector = detector ?? MlKitFaceLandmarkDetector(),
       _video = video ?? MethodChannelVideoFilterGateway(),
       _loadSprite = loadSprite ?? _loadAsset,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final FaceLandmarkDetector _detector;
  final VideoFilterGateway _video;
  final SpriteLoader _loadSprite;
  final TemporaryDirectoryProvider _temporaryDirectory;

  @override
  Future<XFile> applyToPhoto(XFile photo, FaceFilter filter) async {
    final decoded = img.decodeImage(await photo.readAsBytes());
    if (decoded == null) {
      throw const FilterException(
        'No pudimos leer la foto. Elige otra imagen.',
        code: 'INVALID_PHOTO',
      );
    }
    final sprite = img.decodePng(await _loadSprite(filter.asset));
    if (sprite == null) {
      throw const FilterException(
        'No pudimos cargar el filtro. Inténtalo otra vez.',
        code: 'INVALID_OVERLAY',
      );
    }

    // ML Kit trabaja sobre la imagen ya orientada, así sus coordenadas
    // coinciden con los píxeles que se componen.
    final upright = img.bakeOrientation(decoded);
    final directory = await _workDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final analysisFile = File('${directory.path}/analysis_$stamp.jpg');
    await analysisFile.writeAsBytes(img.encodeJpg(upright, quality: 95));
    final faces = await _detector
        .detect(analysisFile.path)
        .whenComplete(analysisFile.delete);

    var placed = 0;
    for (final face in faces) {
      final placement = placeFilter(filter, face);
      if (placement == null) continue;
      drawSprite(target: upright, sprite: sprite, placement: placement);
      placed++;
    }
    if (placed == 0) {
      throw const FilterException(
        'No detectamos un rostro en la foto. Prueba con otra foto o cambia de filtro.',
        code: 'NO_FACE',
      );
    }

    final outputFile = File('${directory.path}/${filter.nativeName}_$stamp.jpg');
    await outputFile.writeAsBytes(img.encodeJpg(upright, quality: 92));
    return XFile(outputFile.path, mimeType: 'image/jpeg');
  }

  @override
  Future<XFile> applyToVideo(
    XFile video,
    FaceFilter filter, {
    required void Function(double) onProgress,
  }) async {
    final directory = await _workDirectory();
    final overlayFile = File('${directory.path}/overlay_${filter.nativeName}.png');
    await overlayFile.writeAsBytes(await _loadSprite(filter.asset));
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final outputPath = '${directory.path}/${filter.nativeName}_$stamp.mp4';
    await _video.applyVideoFilter(
      inputPath: video.path,
      outputPath: outputPath,
      overlayPath: overlayFile.path,
      filter: filter,
      onProgress: onProgress,
    );
    return XFile(outputPath, mimeType: 'video/mp4');
  }

  Future<Directory> _workDirectory() async {
    final root = await _temporaryDirectory();
    final directory = Directory('${root.path}/filters');
    await directory.create(recursive: true);
    return directory;
  }
}
