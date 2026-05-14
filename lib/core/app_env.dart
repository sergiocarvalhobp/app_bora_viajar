import 'backend_origin.dart';

/// Variáveis de ambiente (`--dart-define=...`).
///
/// Por defeito **dev e prod** apontam para o VPS (HTTPS). Para testar só no PC,
/// usa por exemplo `--dart-define=BACKEND_URL=http://10.0.2.2:3000`
/// e `--dart-define=API_BASE_URL=http://10.0.2.2:8081`.
///
/// - **Node (Express):** Auth0, `POST /api/auth/token`, `POST /api/auth/logout`
///   → [effectiveBackendUrl].
/// - **API REST Java:** `/api/v1/...` → [effectiveApiBaseUrl].
///
/// **Segurança:** nunca coloque `AUTH0_CLIENT_SECRET`, `JWT_SECRET` ou `DATABASE_URL` no app.
abstract final class AppEnv {
  /// Origem do backend Node **sem** barra final (site + sessão).
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://boraviajar.net',
  );

  /// Origem da API REST Java **sem** barra final.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.boraviajar.net',
  );

  static String get effectiveBackendUrl {
    final raw = backendUrl.trim();
    if (raw.isNotEmpty) return stripTrailingSlash(raw);
    return stripTrailingSlash(defaultBackendOriginForPlatform());
  }

  /// Base da API Spring (`/api/v1/...`).
  static String get effectiveApiBaseUrl {
    final raw = apiBaseUrl.trim();
    if (raw.isNotEmpty) return stripTrailingSlash(raw);
    return effectiveBackendUrl;
  }

  /// Tenant Auth0 (sem `https://`) — mesmo `AUTH0_DOMAIN` do `.env` na raiz do `bora_viajar`.
  static const auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'dev-ke3vsuw11znodjp3.us.auth0.com',
  );

  /// Mesmo `AUTH0_CONNECTION` do `.env` do `bora_viajar`.
  static const auth0Connection = String.fromEnvironment(
    'AUTH0_CONNECTION',
    defaultValue: 'google-oauth2',
  );
}
