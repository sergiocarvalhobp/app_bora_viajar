import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app_constants.dart';
import '../../../core/app_env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/user_model.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    authDio: ref.watch(authDioProvider),
    restDio: ref.watch(apiClientProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  );
}

class AuthRepository {
  AuthRepository({
    required Dio authDio,
    required Dio restDio,
    required SessionStorage sessionStorage,
  })  : _authDio = authDio,
        _restDio = restDio,
        _session = sessionStorage;

  final Dio _authDio;
  final Dio _restDio;
  final SessionStorage _session;

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
    if (AppEnv.auth0Domain.isEmpty) {
      throw const AuthException(
        'Defina AUTH0_DOMAIN (ex.: flutter run --dart-define=AUTH0_DOMAIN=seu-tenant.us.auth0.com).',
      );
    }

    try {
      final connectionParams = AppEnv.auth0Connection.trim().isEmpty
          ? const <String, String>{}
          : {'connection': AppEnv.auth0Connection.trim()};

      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppConstants.auth0ClientId,
          AppConstants.auth0RedirectUri,
          issuer: 'https://${AppEnv.auth0Domain}',
          scopes: const ['openid', 'profile', 'email'],
          additionalParameters: connectionParams,
        ),
      );

      if (result.accessToken == null) {
        throw const AuthException('Login cancelado pelo usuário.');
      }

      final sessionToken = await _exchangeTokenWithBackend(result.accessToken!);
      await _session.saveToken(sessionToken);

      return await getMe();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<String> _exchangeTokenWithBackend(String accessToken) async {
    try {
      final response = await _authDio.post(
        AppConstants.sessionTokenExchangePath,
        data: {'access_token': accessToken},
      );
      _throwIfHttpError(response);

      final data = response.data;
      if (data is! Map) {
        throw const AuthException(
          'Resposta inválida do servidor em ${AppConstants.sessionTokenExchangePath}.',
        );
      }
      final token = data['sessionToken'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthException('Backend não retornou sessionToken.');
      }
      return token;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const AuthException(
          'Rota ${AppConstants.sessionTokenExchangePath} não encontrada. '
          'Confirme que o servidor Node está acessível ou SESSION_TOKEN_EXCHANGE_PATH.',
        );
      }
      throw ErrorHandler.handle(e);
    }
  }

  /// Perfil via API REST Java (`GET /api/v1/auth/me`).
  Future<UserModel> getMe() async {
    try {
      final response = await _restDio.get('${AppConstants.restApiPrefix}/auth/me');
      _throwIfHttpError(response);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Resposta inválida de /api/v1/auth/me.');
      }
      return UserModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> logout() async {
    try {
      await _authDio
          .post('/api/auth/logout')
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // best-effort
    } finally {
      await _session.deleteToken();
    }
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
