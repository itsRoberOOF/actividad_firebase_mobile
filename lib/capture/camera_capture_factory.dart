// En web no se importa el plugin `camera`; la captura sólo existe en Android.
export 'camera_capture_stub.dart' if (dart.library.io) 'camera_capture_io.dart';
