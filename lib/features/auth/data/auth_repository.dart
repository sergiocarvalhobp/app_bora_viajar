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

  // flutter_appauth é stateless — instanciamos direto
  static const _appAuth = FlutterAppAuth();

  // ── Login via Auth0 ────────────────────────────────────────────────────────

  /// Abre o browser nativo para o fluxo Auth0/Google (PKCE).
  ///
  /// Retorna o [UserModel] do usuário autenticado ou lança [AuthException].
  ///
  /// Fluxo:
  ///   1. flutter_appauth abre o Universal Login do Auth0
  ///   2. Auth0 redireciona para /api/oauth/callback no backend
  ///   3. Backend seta o cookie de sessão E retorna um JSON com o JWT
  ///   4. Salvamos o JWT no SecureStorage
  ///   5. Buscamos o perfil em trpc.auth.me
  Future<UserModel> loginWithGoogle() async {
    try {
      // Passo 1-2: abre Auth0 no browser do sistema
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppConstants.auth0ClientId,
          AppConstants.auth0RedirectUri,
          issuer: 'https://${AppEnv.auth0Domain}',
          scopes: ['openid', 'profile', 'email'],
          // Força conexão Google (mesmo que o Auth0 tenha outras opções)
          additionalParameters: {'connection': 'google-oauth2'},
        ),
      );

      if (result.accessToken == null) {
        throw const AuthException('Login cancelado pelo usuário.');
      }

      // Passo 3-4: troca o access token Auth0 pelo JWT de sessão do backend
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

  /// Troca o access token Auth0 pelo JWT de sessão do backend Bora Viajar.
  ///
  /// O backend em /api/auth/token recebe o access_token e:
  ///   - Busca/cria o usuário no banco
  ///   - Retorna { sessionToken: "eyJ..." }
  ///
  /// NOTA: Se o backend não tiver esta rota ainda, use a alternativa abaixo.
  Future<String> _exchangeTokenWithBackend(String accessToken) async {
    try {
      final response = await _dio.post(
        '/api/auth/token',
        data: {'access_token': accessToken},
      );

      final token = response.data['sessionToken'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthException('Backend não retornou o token de sessão.');
      }
      return token;
    } on DioException catch (e) {
      // Fallback: se /api/auth/token não existir (404), usa o access token
      // diretamente como sessão temporária até o backend ser atualizado.
      if (e.response?.statusCode == 404) {
        return accessToken;
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
