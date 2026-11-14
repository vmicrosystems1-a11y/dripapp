// Android Firebase configuration from the supplied google-services.json.
// This application targets Android. For web/iOS, use flutterfire configure.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Only Android is configured. Run flutterfire configure for other platforms.');
    }
    return const FirebaseOptions(
      apiKey: 'AIzaSyB0l7pZWBXQss84nMXsz3tMhX-2ziMCYr4',
      appId: '1:360087596053:android:b0a436d3b73b2f920f321c',
      messagingSenderId: '360087596053',
      projectId: 'drip-f280e',
      databaseURL: 'https://drip-f280e-default-rtdb.firebaseio.com',
      storageBucket: 'drip-f280e.firebasestorage.app',
    );
  }
}
