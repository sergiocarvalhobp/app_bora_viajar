import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_storage.dart';

part 'auth_interceptor.g.dart';

/// Interceptor Dio que:
///   1. Lê o JWT do SecureStorage antes de cada requisição.
///   2. Injeta `Authorization: Bearer` e o cookie de sessão (`AppConstants.sessionKey`).
///   3. Em 401, apaga o token local para forçar novo login.
@riverpod
AuthInterceptor authInterceptor(Ref ref) {
  final storage = ref.watch(sessionStorageProvider);
  return AuthInterceptor(storage);
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessionStorage);
  final SessionStorage _sessionStorage;

  /// Rotas de login que não devem levar JWT/cookie antigo (evita 403 no servidor).
  static bool _shouldSkipAuth(RequestOptions options) {
    if (options.extra['skipAuth'] == true) return true;
    final path = options.uri.path;
    return path.endsWith('/auth/token');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_shouldSkipAuth(options)) {
      handler.next(options);
      return;
    }

    final token = await _sessionStorage.readToken();

    if (token != null && token.isNotEmpty) {
      // Header Authorization (padrão REST)
      options.headers['Authorization'] = 'Bearer $token';

      // Cookie de sessão — o backend costuma ler o header `Cookie`.
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
    final status = err.response?.statusCode;
    final path = err.requestOptions.uri.path;
    // 401 ou 403 em viagens = sessão inválida na API (lista exige JWT em produção).
    if (status == 401) {
      _sessionStorage.deleteToken();
    }
    handler.next(err);
  }
}
