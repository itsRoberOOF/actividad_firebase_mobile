import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:videoteca/filters/face_geometry.dart';
import 'package:videoteca/filters/sprite_compositor.dart';

img.Image _canvas(int size, img.Color color) {
  final canvas = img.Image(width: size, height: size, numChannels: 3);
  img.fill(canvas, color: color);
  return canvas;
}

void main() {
  test('pinta un sprite opaco en su centro y deja intacto el resto', () {
    final target = _canvas(100, img.ColorRgb8(255, 255, 255));
    final sprite = img.Image(width: 20, height: 20, numChannels: 4);
    img.fill(sprite, color: img.ColorRgba8(255, 0, 0, 255));

    drawSprite(
      target: target,
      sprite: sprite,
      placement: const FacePlacement(
        centerX: 50,
        centerY: 50,
        width: 20,
        rotationDegrees: 0,
      ),
    );

    final center = target.getPixel(50, 50);
    expect((center.r, center.g, center.b), (255, 0, 0));
    final corner = target.getPixel(5, 5);
    expect((corner.r, corner.g, corner.b), (255, 255, 255));
  });

  test('mezcla el alfa del sprite con el fondo', () {
    final target = _canvas(40, img.ColorRgb8(255, 255, 255));
    final sprite = img.Image(width: 10, height: 10, numChannels: 4);
    img.fill(sprite, color: img.ColorRgba8(0, 0, 0, 128));

    drawSprite(
      target: target,
      sprite: sprite,
      placement: const FacePlacement(
        centerX: 20,
        centerY: 20,
        width: 10,
        rotationDegrees: 0,
      ),
    );

    final blended = target.getPixel(20, 20);
    expect(blended.r, closeTo(127, 2));
    expect(blended.g, closeTo(127, 2));
    expect(blended.b, closeTo(127, 2));
  });

  test('gira en sentido horario: la mitad derecha del sprite queda abajo', () {
    final target = _canvas(100, img.ColorRgb8(255, 255, 255));
    final sprite = img.Image(width: 40, height: 20, numChannels: 4);
    for (var y = 0; y < sprite.height; y++) {
      for (var x = 0; x < sprite.width; x++) {
        final color = x < 20
            ? img.ColorRgba8(0, 0, 255, 255)
            : img.ColorRgba8(255, 0, 0, 255);
        sprite.setPixel(x, y, color);
      }
    }

    drawSprite(
      target: target,
      sprite: sprite,
      placement: const FacePlacement(
        centerX: 50,
        centerY: 50,
        width: 40,
        rotationDegrees: 90,
      ),
    );

    final below = target.getPixel(50, 60);
    expect((below.r, below.b), (255, 0), reason: 'la parte roja debe quedar abajo');
    final above = target.getPixel(50, 40);
    expect((above.r, above.b), (0, 255), reason: 'la parte azul debe quedar arriba');
  });

  test('un sprite parcialmente fuera del cuadro no lanza error', () {
    final target = _canvas(30, img.ColorRgb8(255, 255, 255));
    final sprite = img.Image(width: 20, height: 20, numChannels: 4);
    img.fill(sprite, color: img.ColorRgba8(0, 255, 0, 255));

    drawSprite(
      target: target,
      sprite: sprite,
      placement: const FacePlacement(
        centerX: 0,
        centerY: 0,
        width: 40,
        rotationDegrees: 45,
      ),
    );

    expect(target.getPixel(0, 0).g, 255);
  });
}
