import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'face_geometry.dart';

/// Dibuja [sprite] sobre [target] según [placement]. El sprite se reduce al
/// tamaño final y luego se muestrea por mapeo inverso, así la rotación no deja
/// huecos. El alfa del sprite se mezcla con el píxel existente.
void drawSprite({
  required img.Image target,
  required img.Image sprite,
  required FacePlacement placement,
}) {
  final width = placement.width.round();
  final height = (placement.width * sprite.height / sprite.width).round();
  if (width < 1 || height < 1) return;
  final scaled = img.copyResize(
    sprite,
    width: width,
    height: height,
    interpolation: img.Interpolation.linear,
  );

  final halfWidth = scaled.width / 2;
  final halfHeight = scaled.height / 2;
  final radians = placement.rotationDegrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  final extentX = cos.abs() * halfWidth + sin.abs() * halfHeight;
  final extentY = sin.abs() * halfWidth + cos.abs() * halfHeight;

  final left = math.max(0, (placement.centerX - extentX).floor());
  final right = math.min(target.width - 1, (placement.centerX + extentX).ceil());
  final top = math.max(0, (placement.centerY - extentY).floor());
  final bottom = math.min(
    target.height - 1,
    (placement.centerY + extentY).ceil(),
  );

  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      final dx = x + 0.5 - placement.centerX;
      final dy = y + 0.5 - placement.centerY;
      // Inversa de la rotación: pasa del fotograma al sistema del sprite.
      final localX = dx * cos + dy * sin;
      final localY = -dx * sin + dy * cos;
      final spriteX = (localX + halfWidth).floor();
      final spriteY = (localY + halfHeight).floor();
      if (spriteX < 0 ||
          spriteY < 0 ||
          spriteX >= scaled.width ||
          spriteY >= scaled.height) {
        continue;
      }
      final source = scaled.getPixel(spriteX, spriteY);
      final alpha = source.a / 255;
      if (alpha <= 0) continue;
      final destination = target.getPixel(x, y);
      final remaining = 1 - alpha;
      target.setPixelRgba(
        x,
        y,
        (source.r * alpha + destination.r * remaining).round(),
        (source.g * alpha + destination.g * remaining).round(),
        (source.b * alpha + destination.b * remaining).round(),
        destination.a,
      );
    }
  }
}
