import 'package:videoteca/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el panel de escritorio cabe en una ventana baja', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    expect(find.text('Encuentra algo que te mueva.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el panel de escritorio se desplaza en ventanas muy bajas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    expect(find.text('Encuentra algo que te mueva.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite cambiar entre inicio de sesión y registro', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    await tester.ensureVisible(find.text('Regístrate'));
    await tester.tap(find.text('Regístrate'));
    await tester.pump();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Repite tu contraseña'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
