// Firebase configuration — generated from Firebase Console project "rep-ai-app".
// Do not commit changes to this file without updating the corresponding
// google-services.json and GoogleService-Info.plist.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAUi-v1ul3HM9RweVKYwhEEcX3_Bc0SLwc',
    appId: '1:1056534037851:android:f469a8a4ea5b17ede8467e',
    messagingSenderId: '1056534037851',
    projectId: 'rep-ai-app',
    storageBucket: 'rep-ai-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA1dTG6WgBXKCibskiKW8KNpqIfcincG18',
    appId: '1:1056534037851:ios:ce0332e2ce87d92de8467e',
    messagingSenderId: '1056534037851',
    projectId: 'rep-ai-app',
    storageBucket: 'rep-ai-app.firebasestorage.app',
    iosClientId: '1056534037851-rtsr94ua66bv5pss8ds5cu137lceo683.apps.googleusercontent.com',
    iosBundleId: 'com.ohmaiden.repai',
  );
}
