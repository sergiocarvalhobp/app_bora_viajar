import 'backend_origin.dart';

/// Variáveis de ambiente (`--dart-define=...`).
///
/// O app fala **apenas** com a API REST Java (`/api/v1/...`).
/// Para dev local no emulador: `--dart-define=API_BASE_URL=http://10.0.2.2:8081`
///
/// **Segurança:** nunca coloque `AUTH0_CLIENT_SECRET`, `JWT_SECRET` ou `DATABASE_URL` no app.
abstract final class AppEnv {
  /// Origem da API REST Java **sem** barra final.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.boraviajar.net',
  );

  static String get effectiveApiBaseUrl {
    final raw = apiBaseUrl.trim();
    if (raw.isNotEmpty) return stripTrailingSlash(raw);
    return stripTrailingSlash(defaultApiOriginForPlatform());
  }

  /// Tenant Auth0 (sem `https://`) — mesmo `AUTH0_DOMAIN` do backend.
  static const auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'dev-ke3vsuw11znodjp3.us.auth0.com',
  );

  /// Mesmo `AUTH0_CONNECTION` do backend.
  static const auth0Connection = String.fromEnvironment(
    'AUTH0_CONNECTION',
    defaultValue: 'google-oauth2',
  );
}
