import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Videoteca solo está configurada para Android y web.');
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyAQs-ElK8A2EgZPpZcH_NIilpnv7YVdkIw',
    appId: '1:75221581759:web:5a86ed9530b05e475dab0a',
    messagingSenderId: '75221581759',
    projectId: 'listasuper-75ab3',
    authDomain: 'listasuper-75ab3.firebaseapp.com',
    storageBucket: 'listasuper-75ab3.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDB-6fZwY02H5H7BMnlMqionpXtPq30sLs',
    appId: '1:75221581759:android:88e6f8a45e5cfe675dab0a',
    messagingSenderId: '75221581759',
    projectId: 'listasuper-75ab3',
    storageBucket: 'listasuper-75ab3.firebasestorage.app',
  );
}
