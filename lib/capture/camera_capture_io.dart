import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'camera_capture_screen.dart';
import 'camera_capture_types.dart';

CameraCaptureLauncher? createCameraCaptureLauncher() =>
    defaultTargetPlatform == TargetPlatform.android
    ? (context) => Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => const CameraCaptureScreen(),
          fullscreenDialog: true,
        ),
      )
    : null;
