/// Constantes globais — espelham os valores do backend Node.
///
/// COOKIE_NAME vem de @shared/const no site ("app_session_id").
/// AUTH0_CLIENT_ID é o valor público já configurado no backend.
abstract final class AppConstants {
  // ── Sessão ────────────────────────────────────────────────────────────────
  /// Nome da chave no SecureStorage onde o JWT de sessão é salvo.
  /// Deve bater com o COOKIE_NAME do backend (@shared/const).
  static const sessionKey = 'app_session_id';

  // ── Auth0 ─────────────────────────────────────────────────────────────────
  static const auth0ClientId = 'KVD6WjOMtKAm0gYZNJz3MshXV28CxYna';
  // AUTH0_DOMAIN é definido em app_env.dart (variável de ambiente)

  /// Redirect URI registrado no Auth0 para o app Android/iOS.
  /// Formato: <package_name>://callback
  static const auth0RedirectUri = 'br.com.boraviajar://callback';

  // ── Backend ───────────────────────────────────────────────────────────────
  /// Timeout padrão para requisições HTTP (segundos).
  static const httpTimeoutSeconds = 30;

  /// Prefixo de todas as rotas tRPC.
  static const trpcPrefix = '/api/trpc';
}
