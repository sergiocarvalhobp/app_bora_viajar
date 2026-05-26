import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app_constants.dart';
import '../../../core/app_env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_exchange_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../auth_debug.dart';
import '../domain/user_model.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    dio: ref.watch(apiClientProvider),
    exchangeDio: ref.watch(authExchangeClientProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  );
}

class AuthRepository {
  AuthRepository({
    required Dio dio,
    required Dio exchangeDio,
    required SessionStorage sessionStorage,
  })  : _dio = dio,
        _exchangeDio = exchangeDio,
        _session = sessionStorage;

  final Dio _dio;
  final Dio _exchangeDio;
  final SessionStorage _session;

  /// Ordem de tentativas para troca Auth0 -> JWT de sessão.
  ///
  /// 1) API principal (`api.boraviajar.net`) em rotas v1
  /// 2) domínio raiz (fallback legado) caso a borda da API esteja a bloquear POST
  static const _sessionExchangePaths = [
    '${AppConstants.restApiPrefix}/public/session',
    '${AppConstants.restApiPrefix}/auth/token',
  ];
  static const _sessionExchangeAbsoluteFallbacks = [
    'https://boraviajar.net/api/auth/token',
    'https://www.boraviajar.net/api/auth/token',
    'https://boraviajar.net/api/v1/auth/token',
  ];
  static const _logoutPath = '${AppConstants.restApiPrefix}/auth/logout';

  static void _throwIfHttpError(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  static const _appAuth = FlutterAppAuth();

  Future<UserModel> loginWithGoogle() async {
    AuthDebug.log('repo', 'API=${AppEnv.effectiveApiBaseUrl}');
    AuthDebug.log('repo', 'Auth0=${AppEnv.auth0Domain} client=${AppConstants.auth0ClientId}');

    if (AppEnv.auth0Domain.isEmpty) {
      AuthDebug.log('repo', 'AUTH0_DOMAIN vazio');
      throw const AuthException(
        'Login indisponível no momento. Tente novamente mais tarde.',
      );
    }

    await _session.deleteToken();
    AuthDebug.log('repo', 'sessão local apagada');

    try {
      final connectionParams = AppEnv.auth0Connection.trim().isEmpty
          ? const <String, String>{}
          : {'connection': AppEnv.auth0Connection.trim()};

      AuthDebug.log('repo', 'a abrir Auth0 (browser)…');
      AuthDebug.log('repo', 'redirect=${AppConstants.auth0RedirectUri}');

      final AuthorizationTokenResponse result;
      try {
        result = await _appAuth
            .authorizeAndExchangeCode(
              AuthorizationTokenRequest(
                AppConstants.auth0ClientId,
                AppConstants.auth0RedirectUri,
                issuer: 'https://${AppEnv.auth0Domain}',
                scopes: const ['openid', 'profile', 'email'],
                additionalParameters: connectionParams,
              ),
            )
            .timeout(
              const Duration(minutes: 3),
              onTimeout: () {
                AuthDebug.log('repo', 'Auth0 timeout (3 min)');
                throw const AuthException(
                  'O login demorou demais. Feche o app e tente novamente.',
                );
              },
            );
      } on FlutterAppAuthUserCancelledException catch (e) {
        AuthDebug.log('repo', 'Auth0 cancelado (UserCancelled): $e');
        throw const AuthException('Login cancelado pelo usuário.');
      } on PlatformException catch (e) {
        AuthDebug.log(
          'repo',
          'Auth0 PlatformException code=${e.code} message=${e.message} details=${e.details}',
        );
        throw AuthException(_mapPlatformAuthError(e));
      }

      AuthDebug.log(
        'repo',
        'Auth0 retornou accessToken=${result.accessToken != null} '
        'idToken=${result.idToken != null}',
      );

      if (result.accessToken == null) {
        AuthDebug.log('repo', 'Auth0 sem accessToken no response');
        throw const AuthException('Login cancelado pelo usuário.');
      }

      if (kDebugMode) {
        AuthDebug.log('TOKEN Auth0 access_token', result.accessToken!);
      }
      AuthDebug.log(
        'repo',
        'Auth0 OK accessToken len=${result.accessToken!.length}',
      );

      final sessionToken = await _exchangeTokenWithBackend(result.accessToken!);
      await _session.saveToken(sessionToken);
      if (kDebugMode) {
        AuthDebug.log('TOKEN API sessionToken', sessionToken);
      }
      AuthDebug.log('repo', 'sessionToken guardado len=${sessionToken.length}');

      return await getMe();
    } on AuthException catch (e) {
      AuthDebug.log('repo', 'AuthException: ${e.message}');
      rethrow;
    } catch (e, st) {
      AuthDebug.log('repo', 'erro inesperado: $e');
      if (kDebugMode) AuthDebug.log('repo', '$st');
      throw ErrorHandler.handle(e);
    }
  }

  Future<String> _exchangeTokenWithBackend(String accessToken) async {
    DioException? lastError;
    final attempts = <String>[
      ..._sessionExchangePaths.map((p) => '${AppEnv.effectiveApiBaseUrl}$p'),
      ..._sessionExchangeAbsoluteFallbacks,
    ];

    for (final url in attempts) {
      AuthDebug.log('exchange', 'POST $url');
      try {
        final response = await _exchangeDio.post(
          url,
          data: {'access_token': accessToken},
        );
        final status = response.statusCode ?? 0;
        AuthDebug.log('exchange', '← $status $url body=${response.data}');

        _throwIfHttpError(response);

        final data = response.data;
        if (data is! Map) {
          AuthDebug.log('exchange', 'corpo não é Map em $url');
          throw const AuthException(_kLoginGeneric);
        }
        final token = data['sessionToken'] as String?;
        if (token == null || token.isEmpty) {
          AuthDebug.log('exchange', 'sem sessionToken no JSON em $url');
          throw const AuthException(_kLoginGeneric);
        }
        AuthDebug.log('exchange', 'sessionToken recebido via $url');
        return token;
      } on DioException catch (e) {
        lastError = e;
        final status = e.response?.statusCode;
        AuthDebug.log(
          'exchange',
          'DioException $url status=$status data=${e.response?.data}',
        );
        final isLast = url == attempts.last;
        // Borda/nginx costuma devolver 403/404/405/400 em rotas bloqueadas.
        if ((status == 400 || status == 403 || status == 404 || status == 405) &&
            !isLast) {
          AuthDebug.log('exchange', '$status → tentar próxima rota');
          continue;
        }
        throw AuthException(_loginFailureMessage(e));
      }
    }

    throw AuthException(
      lastError != null
          ? _loginFailureMessage(lastError)
          : _kLoginGeneric,
    );
  }

  static const _kLoginGeneric =
      'Não foi possível entrar. Verifique sua internet e tente novamente.';

  /// Mensagens curtas para a tela de login (sem detalhes técnicos).
  static String _loginFailureMessage(DioException e) {
    final status = e.response?.statusCode;
    final server = _extractServerError(e.response?.data);

    return switch (status) {
      401 => 'Não foi possível validar sua conta Google. Tente entrar novamente.',
      403 => 'Não foi possível concluir o login. Feche o app, abra de novo e tente outra vez.',
      404 => 'Serviço temporariamente indisponível. Tente em alguns minutos.',
      503 => server ??
          'Login temporariamente indisponível. Tente mais tarde.',
      null => _kLoginGeneric,
      _ => server ?? _kLoginGeneric,
    };
  }

  static String? _extractServerError(dynamic body) {
    if (body is Map) {
      final err = body['error'];
      if (err is String && err.isNotEmpty && !_looksTechnical(err)) {
        return err;
      }
    }
    return null;
  }

  static String _mapPlatformAuthError(PlatformException e) {
    final code = (e.code).toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    if (code.contains('cancel') || msg.contains('cancel')) {
      return 'Login cancelado pelo usuário.';
    }
    if (code.contains('null_intent') || msg.contains('null_intent')) {
      return 'Não foi possível voltar do login. Confira o redirect br.com.boraviajar://callback no Auth0.';
    }
    return 'Não foi possível concluir o login Google. Tente novamente.';
  }

  static bool _looksTechnical(String msg) {
    final m = msg.toLowerCase();
    return m.contains('redeploy') ||
        m.contains('/api/') ||
        m.contains('auth0_domain') ||
        m.contains('jwt_secret');
  }

  Future<UserModel> getMe() async {
    try {
      AuthDebug.log('repo', 'GET /auth/me…');
      final response = await _dio.get('${AppConstants.restApiPrefix}/auth/me');
      AuthDebug.log('repo', '/auth/me status=${response.statusCode}');
      if ((response.statusCode ?? 0) == 403) {
        final fallback = await _getMeViaRootDomainFallback();
        if (fallback != null) return fallback;
      }
      _throwIfHttpError(response);
      final data = response.data;
      if (data is! Map) {
        AuthDebug.log('repo', '/auth/me corpo inválido: $data');
        throw const AuthException('Resposta inválida de /api/v1/auth/me.');
      }
      final map = Map<String, dynamic>.from(data);
      final user = UserModel.fromJson(map);
      AuthDebug.log('repo', '/auth/me OK id=${user.id}');
      return user;
    } catch (e, st) {
      AuthDebug.log('repo', '/auth/me falhou: $e');
      if (kDebugMode) AuthDebug.log('repo', '$st');
      throw ErrorHandler.handle(e);
    }
  }

  /// Confirma que requisições POST chegam autenticadas ao servidor (proxy/nginx).
  Future<void> verifyPostSession() async {
    try {
      AuthDebug.log('repo', 'POST /auth/session-check…');
      final response =
          await _dio.post('${AppConstants.restApiPrefix}/auth/session-check');
      _throwIfHttpError(response);
      AuthDebug.log('repo', '/auth/session-check OK');
    } catch (e, st) {
      AuthDebug.log('repo', '/auth/session-check falhou: $e');
      if (kDebugMode) AuthDebug.log('repo', '$st');
      throw ErrorHandler.handle(e);
    }
  }

  Future<UserModel?> _getMeViaRootDomainFallback() async {
    final token = await _session.readToken();
    if (token == null || token.isEmpty) return null;

    const fallbackUrls = [
      'https://boraviajar.net/api/auth/me',
      'https://www.boraviajar.net/api/auth/me',
    ];

    for (final url in fallbackUrls) {
      try {
        AuthDebug.log('repo', 'fallback GET $url');
        final res = await _exchangeDio.get(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Cookie': 'app_session_id=$token',
            },
          ),
        );
        final status = res.statusCode ?? 0;
        AuthDebug.log('repo', 'fallback /auth/me status=$status');
        if (status >= 400) continue;
        final contentType = res.headers.value('content-type') ?? '';
        if (!contentType.toLowerCase().contains('application/json')) {
          AuthDebug.log(
            'repo',
            'fallback ignorado ($url): content-type=$contentType',
          );
          continue;
        }
        final body = res.data;
        if (body is! Map) {
          AuthDebug.log('repo', 'fallback ignorado ($url): body não é JSON Map');
          continue;
        }
        final user = UserModel.fromJson(Map<String, dynamic>.from(body));
        AuthDebug.log('repo', 'fallback /auth/me OK id=${user.id}');
        return user;
      } catch (e) {
        AuthDebug.log('repo', 'fallback falhou $url: $e');
      }
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await _dio.post(_logoutPath).timeout(const Duration(seconds: 5));
    } catch (_) {
      // best-effort
    }

    if (AppEnv.auth0Domain.trim().isNotEmpty) {
      try {
        final issuer = AppEnv.auth0Domain.startsWith('http')
            ? AppEnv.auth0Domain
            : 'https://${AppEnv.auth0Domain}';
        await _appAuth.endSession(
          EndSessionRequest(
            issuer: issuer,
            postLogoutRedirectUrl: AppConstants.auth0RedirectUri,
          ),
        );
      } catch (_) {
        // browser / sessão Auth0 — best-effort
      }
    }

    await _session.deleteToken();
  }

  Future<UserModel?> tryRestoreSession() async {
    final hasToken = await _session.hasToken();
    if (!hasToken) return null;

    try {
      return await getMe();
    } on AuthException {
      await _session.deleteToken();
      return null;
    } catch (_) {
      return null;
    }
  }
}
