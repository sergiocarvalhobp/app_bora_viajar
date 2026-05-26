import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_constants.dart';
import '../storage/secure_storage.dart';

part 'auth_interceptor.g.dart';

/// Interceptor Dio que:
///   1. Lê o JWT do SecureStorage antes de cada requisição.
///   2. Injeta `Authorization`, `X-App-Session`, `Cookie` e, em POST/PUT/PATCH,
///      também `sessionToken` no JSON + `app_session_id` na query (nginx às vezes
///      remove headers de sessão em mutações).
///   3. Só apaga token em 401 de `/auth/me` (sessão realmente inválida).
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
      options.headers['Authorization'] = 'Bearer $token';
      options.headers[AppConstants.sessionHeader] = token;
      options.headers['Cookie'] = '${AppConstants.sessionKey}=$token';

      if (_isMutatingMethod(options.method)) {
        options.queryParameters = {
          ...options.queryParameters,
          AppConstants.sessionKey: token,
        };
        _injectSessionTokenIntoBody(options, token);
      }
    }

    handler.next(options);
  }

  static bool _isMutatingMethod(String? method) {
    final m = method?.toUpperCase();
    return m == 'POST' || m == 'PUT' || m == 'PATCH';
  }

  static void _injectSessionTokenIntoBody(RequestOptions options, String token) {
    final data = options.data;
    if (data is Map<String, dynamic>) {
      options.data = {...data, 'sessionToken': token};
    } else if (data is Map) {
      options.data = Map<String, dynamic>.from(data)
        ..putIfAbsent('sessionToken', () => token);
    }
  }

  /// Apaga o token só quando a sessão é invalidada de fato — não em 401 de
  /// endpoints isolados (ex.: POST organizer-rating bloqueado no proxy).
  static bool _shouldClearSessionOnError(DioException err) {
    final status = err.response?.statusCode;
    if (status != 401) return false;

    final path = err.requestOptions.uri.path;
    return path.endsWith('/auth/me') || path.endsWith('/auth/token');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_shouldClearSessionOnError(err)) {
      _sessionStorage.deleteToken();
    }
    handler.next(err);
  }
}
