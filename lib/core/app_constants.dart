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

  // ── Backend (API Java) ────────────────────────────────────────────────────
  static const httpTimeoutSeconds = 30;

  /// Prefixo da API REST Java (Spring Boot).
  static const restApiPrefix = '/api/v1';
}
