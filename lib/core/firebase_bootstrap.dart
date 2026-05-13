import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Inicializa o Firebase (FCM).
///
/// Sem configuração nativa (`android/app/google-services.json`) ou sem
/// `lib/firebase_options.dart` (gerado por `flutterfire configure`), o
/// [Firebase.initializeApp] sem argumentos falha no Android. Nesse caso o app
/// segue sem push até você configurar o projeto no Firebase Console.
Future<void> bootstrapFirebase() async {
  try {
    await Firebase.initializeApp();
  } on PlatformException catch (e, st) {
    _logFirebaseSkip(e.message, e, st);
  } catch (e, st) {
    _logFirebaseSkip(null, e, st);
  }
}

void _logFirebaseSkip(String? message, Object error, StackTrace stack) {
  if (kDebugMode) {
    debugPrint(
      '[Firebase] Inicialização ignorada (FCM indisponível). '
      'Adicione o app no Firebase e rode `flutterfire configure` '
      '(gera lib/firebase_options.dart) ou inclua google-services.json em android/app. '
      'Detalhe: $message — $error',
    );
    debugPrintStack(stackTrace: stack);
  }
}
