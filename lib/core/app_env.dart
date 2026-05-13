/// Variáveis de ambiente do app (`--dart-define=...` no `flutter run` / build).
///
/// Os valores padrão de Auth0 espelham o `.env` do backend Bora Viajar em dev
/// (somente o que é público: domínio do tenant e conexão). **Nunca** coloque
/// `AUTH0_CLIENT_SECRET`, `JWT_SECRET` ou `DATABASE_URL` no app Flutter.
abstract final class AppEnv {
  /// URL base do backend (sem barra final).
  /// Emulador Android → host: `http://10.0.2.2:PORTA` (ajuste a porta se mudar).
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Tenant Auth0 (sem `https://`) — mesmo `AUTH0_DOMAIN` do `.env` do servidor.
  static const auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'dev-ke3vsuw11znodjp3.us.auth0.com',
  );

  /// Conexão Auth0 — mesmo `AUTH0_CONNECTION` do `.env` do servidor.
  static const auth0Connection = String.fromEnvironment(
    'AUTH0_CONNECTION',
    defaultValue: 'google-oauth2',
  );
}