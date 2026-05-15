import 'dart:io' show File, Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Inicializa o Firebase (FCM) só se o projeto tiver config nativa.
///
/// Sem `android/app/google-services.json` ou `flutterfire configure`, o app
/// funciona normalmente — apenas push notifications ficam desativadas.
Future<void> bootstrapFirebase() async {
  if (kIsWeb) return;

  if (!_hasNativeFirebaseConfig()) {
    if (kDebugMode) {
      debugPrint(
        '[Firebase] Push desativado — adicione google-services.json em '
        'android/app ou rode `flutterfire configure`.',
      );
    }
    return;
  }

  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      debugPrint('[Firebase] Inicializado (FCM disponível).');
    }
  } on PlatformException catch (e) {
    if (kDebugMode) {
      debugPrint(
        '[Firebase] Falha ao iniciar (${e.code}): ${e.message ?? e}. '
        'Push desativado; login e API não são afetados.',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Firebase] Falha ao iniciar: $e. Push desativado.');
    }
  }
}

bool _hasNativeFirebaseConfig() {
  try {
    if (Platform.isAndroid) {
      return File('android/app/google-services.json').existsSync();
    }
    if (Platform.isIOS) {
      return File('ios/Runner/GoogleService-Info.plist').existsSync();
    }
  } catch (_) {
    // Testes / plataformas sem dart:io
  }
  return false;
}
