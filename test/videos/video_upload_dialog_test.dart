import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:videoteca/main.dart';
import 'package:videoteca/videos/video_publisher.dart';
import 'package:videoteca/videos/video_repository.dart';
import 'package:videoteca/videos/video_upload_dialog.dart';
import 'package:videoteca/videos/video_uploader.dart';

class _Author extends Fake implements User {
  @override
  String get uid => 'author';

  @override
  String? get displayName => 'Ana';
}

class _Store implements VideoDocumentStore {
  @override
  Future<void> add(Map<String, dynamic> data) async {}

  @override
  Stream<List<VideoDocument>> watch() => Stream.value([]);
}

class _Uploader implements VideoUploader {
  _Uploader(this.result);

  final Completer<UploadedVideo> result;
  int calls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<UploadedVideo> upload(
    XFile file, {
    required void Function(double) onProgress,
  }) {
    calls++;
    onProgress(.5);
    return result.future;
  }
}

XFile _video() => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  name: 'video.mp4',
  mimeType: 'video/mp4',
);

void main() {
  testWidgets('la vista autenticada abre el diálogo desde el botón flotante', (
    tester,
  ) async {
    final repository = VideoRepository(store: _Store());
    final publisher = VideoPublisher(
      uploader: _Uploader(Completer<UploadedVideo>()),
      repository: repository,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VideotecaHome(
          repository: repository,
          publisher: publisher,
          author: _Author(),
          pickVideo: () async => _video(),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.text('Subir video'));
    await tester.pumpAndSettle();

    expect(find.byType(VideoUploadDialog), findsOneWidget);
    expect(find.text('Seleccionar video'), findsOneWidget);
    expect(find.byKey(const Key('video-title')), findsOneWidget);
    expect(find.byKey(const Key('video-description')), findsOneWidget);
    expect(find.text('Publicar video'), findsOneWidget);
    expect(find.text('Autor'), findsNothing);
    expect(find.text('Fecha'), findsNothing);
  });

  testWidgets('bloquea duplicados y conserva los datos tras un error', (
    tester,
  ) async {
    final pending = Completer<UploadedVideo>();
    final uploader = _Uploader(pending);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoUploadDialog(
            publisher: VideoPublisher(
              uploader: uploader,
              repository: VideoRepository(store: _Store()),
            ),
            author: _Author(),
            pickVideo: () async => _video(),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Publicar video'));
    await tester.tap(find.text('Publicar video'));
    await tester.pump();
    expect(find.text('Selecciona un video para continuar.'), findsOneWidget);

    await tester.tap(find.text('Seleccionar video'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('video-title')), 'Mi video');
    await tester.enterText(
      find.byKey(const Key('video-description')),
      'Prueba',
    );
    await tester.ensureVisible(find.text('Publicar video'));
    await tester.tap(find.text('Publicar video'));
    await tester.pump();

    expect(uploader.calls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    pending.completeError(const VideoPublishException('Falló la subida'));
    await tester.pumpAndSettle();
    expect(find.text('Falló la subida'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('video-title')))
          .controller
          ?.text,
      'Mi video',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('video-description')))
          .controller
          ?.text,
      'Prueba',
    );
  });

  testWidgets('no permite cerrar el diálogo mientras sube un video', (
    tester,
  ) async {
    final pending = Completer<UploadedVideo>();
    final repository = VideoRepository(store: _Store());
    await tester.pumpWidget(
      MaterialApp(
        home: VideotecaHome(
          repository: repository,
          publisher: VideoPublisher(
            uploader: _Uploader(pending),
            repository: repository,
          ),
          author: _Author(),
          pickVideo: () async => _video(),
        ),
      ),
    );
    await tester.tap(find.text('Subir video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar video'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('video-title')), 'Mi video');
    await tester.ensureVisible(find.text('Publicar video'));
    await tester.tap(find.text('Publicar video'));
    await tester.pump();

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(VideoUploadDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(VideoUploadDialog), findsOneWidget);
  });

  testWidgets('cierra el diálogo y confirma una publicación exitosa', (
    tester,
  ) async {
    final pending = Completer<UploadedVideo>();
    final repository = VideoRepository(store: _Store());
    await tester.pumpWidget(
      MaterialApp(
        home: VideotecaHome(
          repository: repository,
          publisher: VideoPublisher(
            uploader: _Uploader(pending),
            repository: repository,
          ),
          author: _Author(),
          pickVideo: () async => _video(),
        ),
      ),
    );
    await tester.tap(find.text('Subir video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar video'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('video-title')), 'Mi video');
    await tester.ensureVisible(find.text('Publicar video'));
    await tester.tap(find.text('Publicar video'));
    await tester.pump();

    pending.complete(
      const UploadedVideo(
        secureUrl: 'https://res.cloudinary.com/demo/video/upload/test.mp4',
        publicId: 'test',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VideoUploadDialog), findsNothing);
    expect(find.text('Tu video se publicó.'), findsOneWidget);
  });

  testWidgets('explica cuándo falta configuración de Cloudinary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoUploadDialog(
            publisher: VideoPublisher(
              uploader: CloudinaryVideoUploader(
                cloudName: '',
                uploadPreset: '',
              ),
              repository: VideoRepository(store: _Store()),
            ),
            author: _Author(),
            pickVideo: () async => _video(),
          ),
        ),
      ),
    );

    expect(find.textContaining('Configura Cloudinary'), findsOneWidget);
  });

  testWidgets('el botón de publicar queda visible en un móvil de 390x844', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.25)),
          child: child!,
        ),
        home: Scaffold(
          body: VideoUploadDialog(
            publisher: VideoPublisher(
              uploader: _Uploader(Completer<UploadedVideo>()),
              repository: VideoRepository(store: _Store()),
            ),
            author: _Author(),
          ),
        ),
      ),
    );

    expect(tester.getBottomLeft(find.text('Publicar video')).dy, lessThan(760));
  });
}
