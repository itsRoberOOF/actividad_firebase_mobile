import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:videoteca/filters/face_filter_service.dart';
import 'package:videoteca/filters/filter_kind.dart';
import 'package:videoteca/main.dart';
import 'package:videoteca/videos/like_repository.dart';
import 'package:videoteca/videos/media_publisher.dart';
import 'package:videoteca/videos/media_upload_dialog.dart';
import 'package:videoteca/videos/media_uploader.dart';
import 'package:videoteca/videos/video_repository.dart';

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

class _LikeStore implements LikeStore {
  @override
  Stream<Set<String>> watch(String postId) => Stream.value({});

  @override
  Future<void> write(String postId, String uid, {required bool liked}) async {}
}

class _Uploader implements MediaUploader {
  _Uploader(this.result);

  final Completer<UploadedMedia> result;
  final List<XFile> uploaded = [];

  @override
  bool get isConfigured => true;

  @override
  Future<UploadedMedia> upload(
    XFile file, {
    required MediaType mediaType,
    required void Function(double) onProgress,
  }) {
    uploaded.add(file);
    onProgress(.5);
    return result.future;
  }
}

class _Filters implements FaceFilterService {
  _Filters({this.photoError, this.videoResult});

  FilterException? photoError;
  final Completer<XFile>? videoResult;
  final XFile photoOutput = _file('image/jpeg');
  final XFile videoOutput = _file('video/mp4');
  final List<String> photoCalls = [];
  final List<String> videoCalls = [];

  @override
  Future<XFile> applyToPhoto(XFile photo, FaceFilter filter) async {
    photoCalls.add(filter.nativeName);
    final error = photoError;
    if (error != null) throw error;
    return photoOutput;
  }

  @override
  Future<XFile> applyToVideo(
    XFile video,
    FaceFilter filter, {
    required void Function(double) onProgress,
  }) {
    videoCalls.add(filter.nativeName);
    onProgress(.4);
    final pending = videoResult;
    if (pending != null) return pending.future;
    return Future.value(videoOutput);
  }
}

// `XFile.fromData` no necesita disco, así las pruebas siguen en la zona falsa de
// `testWidgets`. Por eso se comparan identidades y no nombres: en IO el nombre
// de un XFile en memoria queda vacío.
XFile _file(String mimeType) => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  mimeType: mimeType,
);

MediaPublisher _publisher(_Uploader uploader) => MediaPublisher(
  uploader: uploader,
  repository: VideoRepository(store: _Store()),
);

UploadedMedia _uploaded() => const UploadedMedia(
  secureUrl: 'https://res.cloudinary.com/demo/video/upload/test.mp4',
  publicId: 'test',
);

/// Abre el diálogo desde un botón, como lo hace la vista autenticada.
Future<void> _openDialog(WidgetTester tester, MediaUploadDialog dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => dialog,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _enterTitle(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(const Key('media-title')), title);
}

Future<void> _publish(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Publicar'));
  await tester.tap(find.text('Publicar'));
  await tester.pump();
}

void main() {
  testWidgets('la vista autenticada abre la publicación desde el botón flotante', (
    tester,
  ) async {
    final repository = VideoRepository(store: _Store());
    await tester.pumpWidget(
      MaterialApp(
        home: VideotecaHome(
          repository: repository,
          publisher: _publisher(_Uploader(Completer<UploadedMedia>())),
          likeRepository: LikeRepository(store: _LikeStore()),
          author: _Author(),
          pickPhoto: () async => _file('image/jpeg'),
          pickVideo: () async => _file('video/mp4'),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.text('Nueva publicación'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaUploadDialog), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.byKey(const Key('media-title')), findsOneWidget);
    expect(find.byKey(const Key('media-description')), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);
    expect(find.text('Autor'), findsNothing);
    expect(find.text('Fecha'), findsNothing);
  });

  testWidgets('cámara y filtros sólo aparecen si la plataforma los ofrece', (
    tester,
  ) async {
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(_Uploader(Completer<UploadedMedia>())),
        author: _Author(),
        pickPhoto: () async => _file('image/jpeg'),
      ),
    );
    expect(find.text('Cámara'), findsNothing);
    expect(find.text('Lentes'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(_Uploader(Completer<UploadedMedia>())),
        author: _Author(),
        pickPhoto: () async => _file('image/jpeg'),
        capture: (_) async => null,
        filters: _Filters(),
      ),
    );
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Lentes'), findsNothing, reason: 'sin archivo no hay filtros');

    await tester.tap(find.text('Foto'));
    await tester.pump();
    expect(find.text('Sin filtro'), findsOneWidget);
    expect(find.text('Lentes'), findsOneWidget);
    expect(find.text('Bigote'), findsOneWidget);
    expect(find.text('Corona'), findsOneWidget);
  });

  testWidgets('bloquea duplicados y conserva los datos tras un error', (
    tester,
  ) async {
    final pending = Completer<UploadedMedia>();
    final uploader = _Uploader(pending);
    final clip = _file('video/mp4');
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(uploader),
        author: _Author(),
        pickVideo: () async => clip,
      ),
    );

    await _publish(tester);
    expect(
      find.text('Selecciona una foto o un video para continuar.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Video'));
    await tester.pump();
    await _enterTitle(tester, 'Mi video');
    await tester.enterText(find.byKey(const Key('media-description')), 'Prueba');
    await _publish(tester);

    expect(uploader.uploaded, [clip]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar'))
          .onPressed,
      isNull,
    );

    pending.completeError(const MediaPublishException('Falló la subida'));
    await tester.pumpAndSettle();
    expect(find.text('Falló la subida'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('media-title')))
          .controller
          ?.text,
      'Mi video',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('media-description')))
          .controller
          ?.text,
      'Prueba',
    );
  });

  testWidgets('no permite cerrar el diálogo mientras sube', (tester) async {
    final pending = Completer<UploadedMedia>();
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(_Uploader(pending)),
        author: _Author(),
        pickVideo: () async => _file('video/mp4'),
      ),
    );
    await tester.tap(find.text('Video'));
    await tester.pump();
    await _enterTitle(tester, 'Mi video');
    await _publish(tester);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(MediaUploadDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaUploadDialog), findsOneWidget);

    pending.complete(_uploaded());
    await tester.pumpAndSettle();
  });

  testWidgets('cierra el diálogo al confirmar una publicación', (tester) async {
    final pending = Completer<UploadedMedia>();
    final repository = VideoRepository(store: _Store());
    await tester.pumpWidget(
      MaterialApp(
        home: VideotecaHome(
          repository: repository,
          publisher: _publisher(_Uploader(pending)),
          likeRepository: LikeRepository(store: _LikeStore()),
          author: _Author(),
          pickVideo: () async => _file('video/mp4'),
        ),
      ),
    );
    await tester.tap(find.text('Nueva publicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pump();
    await _enterTitle(tester, 'Mi video');
    await _publish(tester);

    pending.complete(_uploaded());
    await tester.pumpAndSettle();
    expect(find.byType(MediaUploadDialog), findsNothing);
    expect(find.text('Tu publicación se subió.'), findsOneWidget);
  });

  testWidgets('explica cuándo falta configuración de Cloudinary', (tester) async {
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: MediaPublisher(
          uploader: CloudinaryMediaUploader(cloudName: '', uploadPreset: ''),
          repository: VideoRepository(store: _Store()),
        ),
        author: _Author(),
      ),
    );

    expect(find.textContaining('Configura Cloudinary'), findsOneWidget);
  });

  testWidgets('aplica el filtro de foto antes de subir el resultado', (
    tester,
  ) async {
    final uploader = _Uploader(Completer<UploadedMedia>()..complete(_uploaded()));
    final filters = _Filters();
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(uploader),
        author: _Author(),
        pickPhoto: () async => _file('image/jpeg'),
        filters: filters,
      ),
    );
    await tester.tap(find.text('Foto'));
    await tester.pump();
    await tester.tap(find.text('Lentes'));
    await tester.pump();
    await _enterTitle(tester, 'Atardecer');
    await _publish(tester);
    await tester.pumpAndSettle();

    expect(filters.photoCalls, ['sunglasses']);
    expect(uploader.uploaded.single, same(filters.photoOutput));
    expect(find.byType(MediaUploadDialog), findsNothing);
  });

  testWidgets('sin rostro no publica y conserva la selección para reintentar', (
    tester,
  ) async {
    final uploader = _Uploader(Completer<UploadedMedia>()..complete(_uploaded()));
    final filters = _Filters(
      photoError: const FilterException(
        'No detectamos un rostro en la foto.',
        code: 'NO_FACE',
      ),
    );
    final photo = _file('image/jpeg');
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(uploader),
        author: _Author(),
        pickPhoto: () async => photo,
        filters: filters,
      ),
    );
    await tester.tap(find.text('Foto'));
    await tester.pump();
    await tester.tap(find.text('Corona'));
    await tester.pump();
    await _enterTitle(tester, 'Atardecer');
    await _publish(tester);
    await tester.pumpAndSettle();

    expect(find.text('No detectamos un rostro en la foto.'), findsOneWidget);
    expect(uploader.uploaded, isEmpty);
    expect(find.byType(MediaUploadDialog), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Corona')).selected,
      isTrue,
    );

    filters.photoError = null;
    await _publish(tester);
    await tester.pumpAndSettle();

    expect(filters.photoCalls, ['crown', 'crown']);
    expect(uploader.uploaded.single, same(filters.photoOutput));
  });

  testWidgets('muestra el progreso del filtro de video antes de subir', (
    tester,
  ) async {
    final result = Completer<XFile>();
    final uploader = _Uploader(Completer<UploadedMedia>()..complete(_uploaded()));
    final filters = _Filters(videoResult: result);
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(uploader),
        author: _Author(),
        pickVideo: () async => _file('video/mp4'),
        filters: filters,
      ),
    );
    await tester.tap(find.text('Video'));
    await tester.pump();
    await tester.tap(find.text('Bigote'));
    await tester.pump();
    await _enterTitle(tester, 'Clip');
    await _publish(tester);

    expect(find.text('Aplicando filtro 40 %'), findsOneWidget);
    expect(uploader.uploaded, isEmpty);

    final output = _file('video/mp4');
    result.complete(output);
    await tester.pumpAndSettle();
    expect(filters.videoCalls, ['mustache']);
    expect(uploader.uploaded.single, same(output));
  });

  testWidgets('publica la captura de cámara', (tester) async {
    final uploader = _Uploader(Completer<UploadedMedia>()..complete(_uploaded()));
    final captured = _file('image/jpeg');
    await _openDialog(
      tester,
      MediaUploadDialog(
        publisher: _publisher(uploader),
        author: _Author(),
        capture: (_) async => captured,
        filters: _Filters(),
      ),
    );
    await tester.tap(find.text('Cámara'));
    await tester.pump();
    await _enterTitle(tester, 'Desde la cámara');
    await _publish(tester);
    await tester.pumpAndSettle();

    expect(uploader.uploaded.single, same(captured));
  });

  testWidgets('el botón de publicar se alcanza completo en un móvil de 390x844', (
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
          body: MediaUploadDialog(
            publisher: _publisher(_Uploader(Completer<UploadedMedia>())),
            author: _Author(),
            filters: _Filters(),
            capture: (_) async => null,
          ),
        ),
      ),
    );

    // El diálogo es desplazable: el botón debe quedar completo en pantalla tras
    // desplazarse hasta él, sin desbordes de diseño.
    await tester.ensureVisible(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(find.text('Publicar')).dy, lessThan(844));
    expect(tester.getTopLeft(find.text('Publicar')).dy, greaterThan(0));
  });
}
