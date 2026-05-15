import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Origem HTTP padrão da API Java quando `API_BASE_URL` não é passado no build.
///
/// - **Android emulator** → `10.0.2.2` mapeia para o localhost da máquina host.
/// - **iOS simulator** → `127.0.0.1` na máquina host.
/// - **Desktop / testes** → `localhost`.
String defaultApiOriginForPlatform() {
  if (kIsWeb) return '';
  if (Platform.isAndroid) return 'http://10.0.2.2:8081';
  if (Platform.isIOS) return 'http://127.0.0.1:8081';
  return 'http://localhost:8081';
}

String stripTrailingSlash(String url) {
  var u = url.trim();
  while (u.length > 1 && u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}
