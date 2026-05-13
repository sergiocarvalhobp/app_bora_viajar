import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_storage.dart';

part 'auth_interceptor.g.dart';

/// Interceptor Dio que:
///   1. Lê o JWT do SecureStorage antes de cada requisição.
///   2. Injeta o token no header Authorization (Bearer) E como cookie
///      "app_session_id" — o backend aceita ambos os formatos.
///   3. Em respostas 401, limpa o token local (sessão expirada no servidor).
@riverpod
AuthInterceptor authInterceptor(Ref ref) {
  final storage = ref.watch(sessionStorageProvider);
  return AuthInterceptor(storage);
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessionStorage);
  final SessionStorage _sessionStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _sessionStorage.readToken();

    if (token != null && token.isNotEmpty) {
      // Header Authorization (padrão REST)
      options.headers['Authorization'] = 'Bearer $token';

      // Cookie "app_session_id" — forma que o backend Node valida a sessão.
      // O sdk.authenticateRequest() lê os cookies do header Cookie.
      final existing = options.headers['Cookie'] as String?;
      final cookieHeader = existing != null
          ? '$existing; app_session_id=$token'
          : 'app_session_id=$token';
      options.headers['Cookie'] = cookieHeader;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Sessão expirada ou inválida — apaga o token local para forçar re-login
    if (err.response?.statusCode == 401) {
      _sessionStorage.deleteToken();
      // Não bloqueia a propagação do erro — a UI decide o que mostrar
    }
    handler.next(err);
  }
}
