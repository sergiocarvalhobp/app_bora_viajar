import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Origem HTTP padrão quando `BACKEND_URL` não é passado no build.
///
/// Espelha o dev do monorepo: um único servidor Express serve Vite + `/api/*`
/// (`server/_core/index.ts`). No browser isso vira `window.location.origin`.
///
/// - **Android emulator** → `10.0.2.2` mapeia para o localhost da máquina host.
/// - **iOS simulator** → `127.0.0.1` na máquina host.
/// - **Desktop / testes** → `localhost`.
String defaultBackendOriginForPlatform() {
  if (kIsWeb) return '';
  if (Platform.isAndroid) return 'http://10.0.2.2:3000';
  if (Platform.isIOS) return 'http://127.0.0.1:3000';
  return 'http://localhost:3000';
}

String stripTrailingSlash(String url) {
  var u = url.trim();
  while (u.length > 1 && u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}
