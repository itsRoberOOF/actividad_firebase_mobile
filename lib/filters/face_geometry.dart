import 'dart:math' as math;

import 'filter_kind.dart';

/// Puntos de un rostro en píxeles de la imagen analizada (origen arriba a la
/// izquierda, eje y hacia abajo). Cualquier landmark puede faltar.
class FaceLandmarks {
  const FaceLandmarks({
    required this.boundingBox,
    this.leftEye,
    this.rightEye,
    this.noseBase,
    this.leftMouth,
    this.rightMouth,
  });

  final math.Rectangle<double> boundingBox;
  final math.Point<double>? leftEye;
  final math.Point<double>? rightEye;
  final math.Point<double>? noseBase;
  final math.Point<double>? leftMouth;
  final math.Point<double>? rightMouth;
}

/// Centro, ancho y giro (grados, horario en pantalla) de un sprite.
class FacePlacement {
  const FacePlacement({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.rotationDegrees,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double rotationDegrees;
}

/// Calcula dónde dibujar [filter] sobre [face]. Devuelve null cuando faltan
/// los landmarks que el filtro necesita.
///
/// Esta geometría se repite en Kotlin (`FaceGeometry.kt`); cambiarla aquí exige
/// cambiarla allí.
FacePlacement? placeFilter(FaceFilter filter, FaceLandmarks face) {
  final rotation = _rollDegrees(face);
  switch (filter) {
    case FaceFilter.sunglasses:
      final left = face.leftEye;
      final right = face.rightEye;
      if (left == null || right == null) return null;
      final eyeDistance = _distance(left, right);
      if (eyeDistance <= 0) return null;
      return FacePlacement(
        centerX: (left.x + right.x) / 2,
        centerY: (left.y + right.y) / 2,
        width: 2 * eyeDistance,
        rotationDegrees: rotation,
      );
    case FaceFilter.mustache:
      final nose = face.noseBase;
      final left = face.leftEye;
      final right = face.rightEye;
      if (nose == null || left == null || right == null) return null;
      final eyeDistance = _distance(left, right);
      if (eyeDistance <= 0) return null;
      final leftMouth = face.leftMouth;
      final rightMouth = face.rightMouth;
      final mouthWidth = leftMouth != null && rightMouth != null
          ? _distance(leftMouth, rightMouth)
          : eyeDistance;
      final width = 1.3 * mouthWidth;
      final offset = _rotate(0, 0.12 * eyeDistance, rotation);
      return FacePlacement(
        centerX: nose.x + offset.x,
        centerY: nose.y + offset.y,
        width: width,
        rotationDegrees: rotation,
      );
    case FaceFilter.crown:
      final box = face.boundingBox;
      final width = 0.9 * box.width;
      final anchorX = box.left + box.width / 2;
      final anchorY = box.top + 0.05 * box.height;
      final offset = _rotate(0, -(width * filter.spriteAspect) / 2, rotation);
      return FacePlacement(
        centerX: anchorX + offset.x,
        centerY: anchorY + offset.y,
        width: width,
        rotationDegrees: rotation,
      );
  }
}

/// Inclinación de la línea entre los ojos. Se normaliza para que el vector
/// apunte hacia la derecha de la imagen, así no depende del orden de los
/// landmarks.
double _rollDegrees(FaceLandmarks face) {
  final left = face.leftEye;
  final right = face.rightEye;
  if (left == null || right == null) return 0;
  var dx = right.x - left.x;
  var dy = right.y - left.y;
  if (dx < 0) {
    dx = -dx;
    dy = -dy;
  }
  return math.atan2(dy, dx) * 180 / math.pi;
}

double _distance(math.Point<double> a, math.Point<double> b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// Gira (x, y) alrededor del origen; con eje y hacia abajo, un ángulo positivo
/// es horario en pantalla.
math.Point<double> _rotate(double x, double y, double degrees) {
  final radians = degrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  return math.Point(x * cos - y * sin, x * sin + y * cos);
}
