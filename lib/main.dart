import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'capture/camera_capture_factory.dart';
import 'capture/camera_capture_types.dart';
import 'filters/face_filter_factory.dart';
import 'filters/face_filter_service.dart';
import 'firebase_options.dart';
import 'videos/like_repository.dart';
import 'videos/media_publisher.dart';
import 'videos/media_upload_dialog.dart';
import 'videos/media_uploader.dart';
import 'videos/video_list.dart';
import 'videos/video_repository.dart';

const ink = Color(0xFF102B3C);
const sky = Color(0xFF37BCE8);
const canvas = Color(0xFFF6FAFC);
const muted = Color(0xFF5A7180);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VideotecaApp());
}

class VideotecaApp extends StatelessWidget {
  const VideotecaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Videoteca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: sky),
        scaffoldBackgroundColor: canvas,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD5E3E9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF087EAA), width: 2),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.hasData ? const VideotecaHome() : const AuthScreen();
        },
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool register = false;
  bool busy = false;
  bool resetting = false;
  bool revealPassword = false;
  bool revealConfirmation = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  void switchMode() {
    setState(() {
      register = !register;
      error = null;
      formKey.currentState?.reset();
      password.clear();
      confirmation.clear();
    });
  }

  Future<void> submit() async {
    if (busy || resetting || !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        final result = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: email.text.trim(),
              password: password.text,
            );
        await result.user?.updateDisplayName(name.text.trim());
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = authMessage(e.code));
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No pudimos conectar. Revisa tu conexión e inténtalo otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (busy || resetting) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) {
      setState(
        () => error = 'Escribe tu correo arriba para enviarte el enlace.',
      );
      return;
    }
    setState(() {
      resetting = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si el correo existe, recibirás un enlace para restablecer tu contraseña.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = authMessage(e.code));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No pudimos enviar el enlace. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => resetting = false);
    }
  }

  String authMessage(String code) => switch (code) {
    'email-already-in-use' => 'Este correo ya tiene una cuenta. Inicia sesión.',
    'weak-password' => 'Usa una contraseña de al menos 6 caracteres.',
    'invalid-email' => 'El correo no tiene un formato válido.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Correo o contraseña incorrectos. Revisa tus datos.',
    'too-many-requests' =>
      'Demasiados intentos. Espera un momento y vuelve a probar.',
    'network-request-failed' =>
      'No hay conexión. Revisa tu internet e inténtalo otra vez.',
    _ => 'Ocurrió un error. Inténtalo de nuevo.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, size) {
          if (size.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(
                  flex: 11,
                  child: SingleChildScrollView(
                    child: BrandPanel(
                      wide: true,
                      compact: size.maxHeight < 720,
                    ),
                  ),
                ),
                Expanded(
                  flex: 9,
                  child: Center(
                    child: SingleChildScrollView(child: form(430, true)),
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [const BrandPanel(wide: false), form(500, false)],
            ),
          );
        },
      ),
    );
  }

  Widget form(double width, bool wide) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 38),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) ...[
              const Wordmark(dark: true),
              const SizedBox(height: 56),
            ],
            Text(
              register ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
              style: const TextStyle(
                color: ink,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              register
                  ? 'Guarda lo que te inspira y descubre qué sigue.'
                  : 'Entra para seguir viendo lo que te gusta.',
              style: const TextStyle(color: muted, fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 30),
            if (register) ...[
              label('Tu nombre'),
              TextFormField(
                controller: name,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: '¿Cómo te llamas?'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe tu nombre.' : null,
              ),
              const SizedBox(height: 18),
            ],
            label('Correo electrónico'),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'tu@correo.com'),
              validator: (v) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Escribe un correo válido.',
            ),
            const SizedBox(height: 18),
            label('Contraseña'),
            TextFormField(
              controller: password,
              obscureText: !revealPassword,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              textInputAction: register
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!register) submit();
              },
              decoration: InputDecoration(
                hintText: register ? 'Mínimo 6 caracteres' : 'Tu contraseña',
                suffixIcon: IconButton(
                  tooltip: revealPassword
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                  icon: Icon(
                    revealPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => revealPassword = !revealPassword),
                ),
              ),
              validator: (v) =>
                  (v?.length ?? 0) < 6 ? 'Usa al menos 6 caracteres.' : null,
            ),
            if (register) ...[
              const SizedBox(height: 18),
              label('Repite tu contraseña'),
              TextFormField(
                controller: confirmation,
                obscureText: !revealConfirmation,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  hintText: 'Confirma tu contraseña',
                  suffixIcon: IconButton(
                    tooltip: revealConfirmation
                        ? 'Ocultar confirmación'
                        : 'Mostrar confirmación',
                    icon: Icon(
                      revealConfirmation
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(
                      () => revealConfirmation = !revealConfirmation,
                    ),
                  ),
                ),
                validator: (v) =>
                    v != password.text ? 'Las contraseñas no coinciden.' : null,
              ),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy || resetting ? null : resetPassword,
                  child: Text(
                    resetting
                        ? 'Enviando enlace…'
                        : '¿Olvidaste tu contraseña?',
                  ),
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDEA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFA7352B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(color: Color(0xFF86291F)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: busy || resetting ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            register ? 'Crear cuenta' : 'Iniciar sesión',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  register ? '¿Ya tienes cuenta?' : '¿Aún no tienes cuenta?',
                  style: const TextStyle(color: muted),
                ),
                TextButton(
                  onPressed: busy || resetting ? null : switchMode,
                  child: Text(register ? 'Inicia sesión' : 'Regístrate'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: dark ? sky : Colors.white,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: dark ? ink : const Color(0xFF087DA8),
          size: 25,
        ),
      ),
      const SizedBox(width: 11),
      Text(
        'videoteca',
        style: TextStyle(
          color: dark ? ink : Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.3,
        ),
      ),
    ],
  );
}

class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key, required this.wide, this.compact = false});
  final bool wide;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: BoxConstraints(
      minHeight: wide ? MediaQuery.sizeOf(context).height : 292,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF118DBB), Color(0xFF40C2EA)],
      ),
    ),
    child: SafeArea(
      bottom: !wide,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 62 : 28,
          vertical: compact ? 30 : (wide ? 44 : 28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Wordmark(dark: false),
            if (wide) ...[
              SizedBox(height: compact ? 18 : 48),
              compact
                  ? const SizedBox(
                      height: 205,
                      child: VideoArtwork(compact: true),
                    )
                  : const VideoArtwork(),
              SizedBox(height: compact ? 18 : 38),
            ] else
              const SizedBox(height: 43),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encuentra algo que te mueva.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 38 : (wide ? 46 : 32),
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Videos, ideas y voces nuevas. Todo empieza con darle play.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .93),
                      fontSize: wide ? 17 : 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class VideoArtwork extends StatelessWidget {
  const VideoArtwork({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: AspectRatio(
        aspectRatio: 1.4,
        child: Stack(
          children: [
            Positioned.fill(
              left: 34,
              right: 22,
              top: 16,
              bottom: 27,
              child: Transform.rotate(
                angle: -.08,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B668B),
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              left: 15,
              right: 34,
              top: 30,
              bottom: 15,
              child: Transform.rotate(
                angle: .055,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF164968),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44005276),
                        blurRadius: 30,
                        offset: Offset(0, 17),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: ScenePainter()),
                      ),
                      Center(
                        child: Container(
                          width: compact ? 60 : 78,
                          height: compact ? 60 : 78,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: ink,
                            size: compact ? 36 : 46,
                          ),
                        ),
                      ),
                      if (!compact)
                        const Positioned(
                          left: 24,
                          bottom: 49,
                          child: Text(
                            'Una nueva perspectiva',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (!compact)
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 24,
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: .38,
                                    color: sky,
                                    backgroundColor: Colors.white54,
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                '04:28',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF225D81),
    );
    canvas.drawCircle(
      Offset(size.width * .73, size.height * .30),
      size.width * .13,
      Paint()..color = const Color(0xFFF7D883),
    );
    final far = Path()
      ..moveTo(0, size.height * .78)
      ..lineTo(size.width * .27, size.height * .43)
      ..lineTo(size.width * .52, size.height * .73)
      ..lineTo(size.width * .79, size.height * .44)
      ..lineTo(size.width, size.height * .69)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF3D97A7));
    final near = Path()
      ..moveTo(0, size.height * .86)
      ..lineTo(size.width * .27, size.height * .70)
      ..lineTo(size.width * .53, size.height * .83)
      ..lineTo(size.width * .79, size.height * .61)
      ..lineTo(size.width, size.height * .79)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF164A66));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VideotecaHome extends StatelessWidget {
  const VideotecaHome({
    super.key,
    this.repository,
    this.publisher,
    this.likeRepository,
    this.author,
    this.pickPhoto,
    this.pickVideo,
    this.capture,
    this.filters,
  });

  final VideoRepository? repository;
  final MediaPublisher? publisher;
  final LikeRepository? likeRepository;
  final User? author;
  final MediaPicker? pickPhoto;
  final MediaPicker? pickVideo;

  /// Por defecto, sólo Android tiene cámara y filtros faciales.
  final CameraCaptureLauncher? capture;
  final FaceFilterService? filters;

  @override
  Widget build(BuildContext context) {
    final videoRepository = repository ?? VideoRepository();
    final videoPublisher =
        publisher ??
        MediaPublisher(
          uploader: CloudinaryMediaUploader(),
          repository: videoRepository,
        );
    final currentUser = author ?? FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        title: const Wordmark(dark: false),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: sky,
        foregroundColor: ink,
        icon: const Icon(Icons.upload_rounded),
        label: const Text('Nueva publicación'),
        onPressed: () async {
          final published = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => MediaUploadDialog(
              publisher: videoPublisher,
              author: currentUser,
              pickPhoto: pickPhoto,
              pickVideo: pickVideo,
              capture: capture ?? createCameraCaptureLauncher(),
              filters: filters ?? createFaceFilterService(),
            ),
          );
          if (published == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tu publicación se subió.')),
            );
          }
        },
      ),
      body: VideoList(
        repository: videoRepository,
        likeRepository: likeRepository ?? LikeRepository(),
        viewerId: currentUser?.uid,
      ),
    );
  }
}
