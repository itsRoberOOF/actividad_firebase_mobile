import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/filters/face_geometry.dart';
import 'package:videoteca/filters/filter_kind.dart';

void main() {
  const box = Rectangle<double>(100, 50, 100, 120);

  group('lentes', () {
    test('centra los lentes entre los ojos y ajusta el ancho a dos distancias', () {
      final placement = placeFilter(
        FaceFilter.sunglasses,
        const FaceLandmarks(
          boundingBox: box,
          leftEye: Point(100, 100),
          rightEye: Point(200, 100),
        ),
      )!;

      expect(placement.centerX, closeTo(150, 1e-9));
      expect(placement.centerY, closeTo(100, 1e-9));
      expect(placement.width, closeTo(200, 1e-9));
      expect(placement.rotationDegrees, closeTo(0, 1e-9));
    });

    test('sigue la inclinación de la línea entre ojos', () {
      final placement = placeFilter(
        FaceFilter.sunglasses,
        const FaceLandmarks(
          boundingBox: box,
          leftEye: Point(100, 100),
          rightEye: Point(200, 200),
        ),
      )!;

      expect(placement.centerX, closeTo(150, 1e-9));
      expect(placement.centerY, closeTo(150, 1e-9));
      expect(placement.width, closeTo(2 * sqrt(20000), 1e-9));
      expect(placement.rotationDegrees, closeTo(45, 1e-9));
    });

    test('no depende del orden de los ojos', () {
      final placement = placeFilter(
        FaceFilter.sunglasses,
        const FaceLandmarks(
          boundingBox: box,
          leftEye: Point(200, 100),
          rightEye: Point(100, 100),
        ),
      )!;

      expect(placement.rotationDegrees, closeTo(0, 1e-9));
      expect(placement.centerX, closeTo(150, 1e-9));
    });

    test('no se coloca sin ambos ojos', () {
      expect(
        placeFilter(
          FaceFilter.sunglasses,
          const FaceLandmarks(boundingBox: box, leftEye: Point(100, 100)),
        ),
        isNull,
      );
    });
  });

  group('bigote', () {
    const eyes = FaceLandmarks(
      boundingBox: box,
      leftEye: Point(100, 100),
      rightEye: Point(200, 100),
      noseBase: Point(150, 180),
    );

    test('usa la anchura de la boca y se ubica bajo la nariz', () {
      final placement = placeFilter(
        FaceFilter.mustache,
        const FaceLandmarks(
          boundingBox: box,
          leftEye: Point(100, 100),
          rightEye: Point(200, 100),
          noseBase: Point(150, 180),
          leftMouth: Point(125, 220),
          rightMouth: Point(175, 220),
        ),
      )!;

      expect(placement.width, closeTo(65, 1e-9));
      expect(placement.centerX, closeTo(150, 1e-9));
      expect(placement.centerY, closeTo(192, 1e-9));
    });

    test('sin comisuras usa la distancia entre ojos', () {
      final placement = placeFilter(FaceFilter.mustache, eyes)!;

      expect(placement.width, closeTo(130, 1e-9));
    });

    test('se necesita la nariz', () {
      expect(
        placeFilter(
          FaceFilter.mustache,
          const FaceLandmarks(
            boundingBox: box,
            leftEye: Point(100, 100),
            rightEye: Point(200, 100),
          ),
        ),
        isNull,
      );
    });
  });

  group('corona', () {
    test('se centra sobre el borde superior del cuadro del rostro', () {
      final placement = placeFilter(
        FaceFilter.crown,
        const FaceLandmarks(boundingBox: box),
      )!;

      expect(placement.width, closeTo(90, 1e-9));
      expect(placement.centerX, closeTo(150, 1e-9));
      expect(placement.centerY, closeTo(56 - 27, 1e-9));
      expect(placement.rotationDegrees, closeTo(0, 1e-9));
    });

    test('gira alrededor del ancla cuando la cabeza se inclina', () {
      final placement = placeFilter(
        FaceFilter.crown,
        const FaceLandmarks(
          boundingBox: box,
          leftEye: Point(100, 100),
          rightEye: Point(100, 200),
        ),
      )!;

      expect(placement.rotationDegrees, closeTo(90, 1e-9));
      expect(placement.centerX, closeTo(150 + 27, 1e-6));
      expect(placement.centerY, closeTo(56, 1e-6));
    });
  });
}
