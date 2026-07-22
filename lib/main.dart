import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CustomerApp()));
  unawaited(_initializeFirebase());
  unawaited(MobileAds.instance.initialize());
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    void open(RemoteMessage m) {
      final link = m.data['deepLink'];
      if (link != null) openCustomerDeepLink(link);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(open);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) open(initial);
  } catch (e, stackTrace) {
    debugPrint('Firebase init failed: $e\n$stackTrace');
  }
}
