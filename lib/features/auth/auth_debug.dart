import 'package:flutter/foundation.dart';

/// Logs do fluxo de login — filtrar no Logcat/Console por `[Auth]`.
abstract final class AuthDebug {
  static void log(String step, [Object? detail]) {
    if (!kDebugMode) return;
    final extra = detail == null ? '' : ' | $detail';
    debugPrint('[Auth] $step$extra');
  }
}
