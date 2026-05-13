/// Constantes globais — valores compatíveis com o backend web Bora Viajar
/// (cookie `app_session_id`, Auth0, tRPC em `/api/trpc`).
abstract final class AppConstants {
  // ── Sessão ────────────────────────────────────────────────────────────────
  /// Nome do cookie / chave no SecureStorage (JWT de sessão do backend).
  static const sessionKey = 'app_session_id';

  // ── Auth0 ─────────────────────────────────────────────────────────────────
  /// Client ID público (Native / SPA no Auth0).
  static const auth0ClientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'KVD6WjOMtKAm0gYZNJz3MshXV28CxYna',
  );

  /// Redirect nativo (flutter_appauth). Registrar no Auth0 em Allowed Callback URLs.
  static const auth0RedirectUri = 'br.com.boraviajar://callback';

  /// `POST` relativo à base URL: troca `access_token` (Auth0) por `sessionToken` (JWT).
  /// Ajuste com `--dart-define=SESSION_TOKEN_EXCHANGE_PATH=/seu/caminho` se usar BFF/gateway.
  static const sessionTokenExchangePath = String.fromEnvironment(
    'SESSION_TOKEN_EXCHANGE_PATH',
    defaultValue: '/api/auth/token',
  );

  // ── Backend ───────────────────────────────────────────────────────────────
  static const httpTimeoutSeconds = 30;

  static const trpcPrefix = '/api/trpc';
}