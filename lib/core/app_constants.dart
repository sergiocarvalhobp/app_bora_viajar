/// Caminhos e constantes do app.
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

  /// `POST` relativo à base URL **Node**: troca `access_token` (Auth0) por `sessionToken` (JWT).
  static const sessionTokenExchangePath = String.fromEnvironment(
    'SESSION_TOKEN_EXCHANGE_PATH',
    defaultValue: '/api/auth/token',
  );

  // ── Backend ───────────────────────────────────────────────────────────────
  static const httpTimeoutSeconds = 30;

  /// Prefixo da API REST Java (Spring Boot).
  static const restApiPrefix = '/api/v1';
}
