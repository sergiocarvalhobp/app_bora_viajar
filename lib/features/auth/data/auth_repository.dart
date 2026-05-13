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
    dio:            ref.watch(apiClientProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  );
}

class AuthRepository {
  AuthRepository({
    required Dio dio,
    required SessionStorage sessionStorage,
  })  : _dio = dio,
        _session = sessionStorage;

  final Dio _dio;
  final SessionStorage _session;

  /// O cliente Dio não lança em respostas 4xx (`validateStatus`); exige sucesso explícito.
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

  // flutter_appauth é stateless — instanciamos direto
  static const _appAuth = FlutterAppAuth();

  // ── Login via Auth0 ────────────────────────────────────────────────────────

  /// Abre o browser nativo para o fluxo Auth0/Google (PKCE), igual ao web
  /// (`/api/auth/login` + callback no servidor), mas com redirect nativo.
  ///
  /// Fluxo:
  ///   1. flutter_appauth → Auth0 (PKCE), redirect para [auth0RedirectUri]
  ///   2. `POST` em [AppConstants.sessionTokenExchangePath] troca o access_token Auth0 pelo JWT de sessão
  ///   3. JWT salvo no SecureStorage; o interceptor envia cookie/header (ver [AuthInterceptor])
  ///   4. `trpc.auth.me` carrega o perfil
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

      // Passo 5: busca o perfil completo
      return await getMe();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Troca o access token Auth0 pelo JWT de sessão do backend (`POST` em [AppConstants.sessionTokenExchangePath]).
  Future<String> _exchangeTokenWithBackend(String accessToken) async {
    try {
      final response = await _dio.post(
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
          'Confirme que o servidor está atualizado (POST troca Auth0 → JWT) ou SESSION_TOKEN_EXCHANGE_PATH.',
        );
      }
      throw ErrorHandler.handle(e);
    }
  }

  // ── Usuário atual ──────────────────────────────────────────────────────────

  /// Busca o perfil do usuário autenticado no backend.
  /// Equivalente ao `trpc.auth.me.useQuery()` do site.
  Future<UserModel> getMe() async {
    try {
      final response = await _dio.get(trpcUrl('auth.me'));
      _throwIfHttpError(response);

      // tRPC GET retorna: { result: { data: { json: { ...user } } } }
      final data = _extractTrpcData(response.data);
      return UserModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Apaga o token local e invalida a sessão no backend.
  Future<void> logout() async {
    try {
      // Tenta invalidar no servidor (best-effort — não falha se offline)
      await _dio.post('/api/auth/logout').timeout(const Duration(seconds: 5));
    } catch (_) {
      // Silencioso
    } finally {
      await _session.deleteToken();
    }
  }

  // ── Verificação rápida de sessão ───────────────────────────────────────────

  /// Verifica se há token salvo E se o backend ainda o aceita.
  /// Usado na inicialização do app (splash screen).
  Future<UserModel?> tryRestoreSession() async {
    final hasToken = await _session.hasToken();
    if (!hasToken) return null;

    try {
      return await getMe();
    } on AuthException {
      await _session.deleteToken();
      return null;
    } catch (_) {
      // Erro de rede — mantém o token, tenta de novo depois
      return null;
    }
  }

  // ── Helper tRPC ────────────────────────────────────────────────────────────

  /// Extrai o payload de uma resposta tRPC.
  ///
  /// tRPC GET retorna:
  ///   { result: { data: { json: <payload> } } }
  ///   ou em lista (batch):
  ///   [{ result: { data: { json: <payload> } } }]
  static dynamic _extractTrpcData(dynamic raw) {
    if (raw is List) raw = raw.first;
    if (raw is Map<String, dynamic>) {
      final result = raw['result'];
      if (result is Map<String, dynamic>) {
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          return data['json'] ?? data;
        }
        return data;
      }
    }
    return raw;
  }
}
