import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase_bootstrap.dart';
import 'features/auth/auth_debug.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    FlutterError.onError = (details) {
      AuthDebug.log('CRASH', details.exceptionAsString());
      AuthDebug.log('CRASH', details.stack?.toString() ?? '');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AuthDebug.log('CRASH async', '$error\n$stack');
      return true;
    };
  }

  await bootstrapFirebase();

  // Força orientação portrait — app de viagens faz mais sentido vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar transparente para o splash/header ter full-bleed
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    // ProviderScope é o container raiz de todo estado Riverpod
    const ProviderScope(
      child: BoraViajarApp(),
    ),
  );
}
