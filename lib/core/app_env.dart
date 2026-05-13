/// Variáveis de ambiente do app.
///
/// No Flutter, são passadas via --dart-define em tempo de build:
///   flutter run --dart-define=BACKEND_URL=https://boraviajar.com.br
///
/// Para desenvolvimento local:
///   flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000
///   (10.0.2.2 é o localhost da máquina host visto pelo emulador Android)
abstract final class AppEnv {
  /// URL base do backend Node/Express.
  /// Produção:    https://boraviajar.com.br
  /// Android emu: http://10.0.2.2:3000
  /// iOS sim:     http://localhost:3000
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Tenant do Auth0 (sem https://).
  /// Exemplo: meutenant.us.auth0.com
  static const auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: '',
  );
}
