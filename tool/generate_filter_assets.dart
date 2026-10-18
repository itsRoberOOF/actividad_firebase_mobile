// Genera los recursos transparentes de los filtros faciales.
//
// Ejecutar desde la raíz del proyecto:
//   dart run tool/generate_filter_assets.dart
//
// Cada sprite se dibuja a 4x y se reduce con promedio para obtener bordes suaves.
// La geometría de anclaje está documentada en lib/filters/face_geometry.dart.
import 'dart:io';

import 'package:image/image.dart' as img;

const _supersample = 4;
const _outputDirectory = 'assets/filters';

void main() {
  _write(
    'sunglasses.png',
    width: 1000,
    height: 400,
    draw: _drawSunglasses,
  );
  _write('mustache.png', width: 600, height: 220, draw: _drawMustache);
  _write('crown.png', width: 600, height: 360, draw: _drawCrown);
}

typedef _Drawer = void Function(img.Image canvas);

void _write(
  String fileName, {
  required int width,
  required int height,
  required _Drawer draw,
}) {
  final canvas = img.Image(
    width: width * _supersample,
    height: height * _supersample,
    numChannels: 4,
  );
  draw(canvas);
  final output = img.copyResize(
    canvas,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
  final directory = Directory(_outputDirectory)..createSync(recursive: true);
  File('${directory.path}/$fileName').writeAsBytesSync(img.encodePng(output));
  stdout.writeln('$_outputDirectory/$fileName (${width}x$height)');
}

img.Point _p(num x, num y) => img.Point(
  (x * _supersample).round(),
  (y * _supersample).round(),
);

List<img.Point> _points(List<(num, num)> values) => [
  for (final (x, y) in values) _p(x, y),
];

img.Color _rgba(int r, int g, int b, [int a = 255]) =>
    img.ColorRgba8(r, g, b, a);

void _circle(img.Image canvas, num x, num y, num radius, img.Color color) {
  img.fillCircle(
    canvas,
    x: (x * _supersample).round(),
    y: (y * _supersample).round(),
    radius: (radius * _supersample).round(),
    color: color,
  );
}

// Lentes centrados en 25 % y 75 % del ancho: coinciden con los ojos cuando el
// sprite mide dos distancias interpupilares.
void _drawSunglasses(img.Image canvas) {
  final frame = _rgba(27, 27, 31);
  final lens = _rgba(18, 22, 30, 225);
  final glint = _rgba(255, 255, 255, 70);
  for (final centerX in [250, 750]) {
    _circle(canvas, centerX, 200, 175, frame);
    _circle(canvas, centerX, 200, 146, lens);
    img.fillPolygon(
      canvas,
      vertices: _points([
        (centerX - 90, 150),
        (centerX - 40, 120),
        (centerX + 30, 220),
        (centerX - 20, 240),
      ]),
      color: glint,
    );
  }
  img.fillPolygon(
    canvas,
    vertices: _points([(415, 186), (585, 186), (585, 214), (415, 214)]),
    color: frame,
  );
  img.fillPolygon(
    canvas,
    vertices: _points([(76, 186), (4, 176), (4, 192), (76, 214)]),
    color: frame,
  );
  img.fillPolygon(
    canvas,
    vertices: _points([(924, 186), (996, 176), (996, 192), (924, 214)]),
    color: frame,
  );
}

// Bigote de dos puntas que se curvan hacia arriba; el borde superior central
// queda justo debajo de la nariz.
void _drawMustache(img.Image canvas) {
  const centerY = 120.0;
  const halfWidth = 300.0;
  final top = <(num, num)>[];
  final bottom = <(num, num)>[];
  for (var x = 0.0; x <= halfWidth * 2; x += 2) {
    final t = (x - halfWidth).abs() / halfWidth;
    final yCenter = centerY - 45 * t * t * t * t;
    final thickness = 72 * (1 - 0.75 * t * t);
    top.add((x, yCenter - thickness / 2));
    bottom.add((x, yCenter + thickness / 2));
  }
  img.fillPolygon(
    canvas,
    vertices: _points([...top, ...bottom.reversed]),
    color: _rgba(48, 30, 18),
  );
}

// Corona dorada con banda inferior. El centro inferior del sprite es el punto
// de anclaje sobre el borde superior del rostro.
void _drawCrown(img.Image canvas) {
  final gold = _rgba(245, 197, 66);
  final band = _rgba(200, 150, 30);
  img.fillPolygon(
    canvas,
    vertices: _points([
      (40, 360),
      (40, 110),
      (180, 210),
      (300, 40),
      (420, 210),
      (560, 110),
      (560, 360),
    ]),
    color: gold,
  );
  img.fillPolygon(
    canvas,
    vertices: _points([(40, 270), (560, 270), (560, 360), (40, 360)]),
    color: band,
  );
  _circle(canvas, 40, 110, 16, gold);
  _circle(canvas, 300, 40, 18, gold);
  _circle(canvas, 560, 110, 16, gold);
  _circle(canvas, 300, 312, 26, _rgba(200, 30, 50));
  _circle(canvas, 180, 316, 18, _rgba(40, 110, 220));
  _circle(canvas, 420, 316, 18, _rgba(30, 160, 90));
}
