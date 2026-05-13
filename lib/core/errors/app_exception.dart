/// Hierarquia de exceções do app.
///
/// Converte erros crus de rede/HTTP em tipos com significado de negócio,
/// para que a UI possa reagir de forma adequada a cada caso.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => 'AppException: $message';
}

/// Sessão expirada ou usuário não autenticado (HTTP 401 / 403).
final class AuthException extends AppException {
  const AuthException([super.message = 'Sessão expirada. Faça login novamente.']);
}

/// Recurso não encontrado (HTTP 404).
final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Recurso não encontrado.']);
}

/// Erro de validação / regra de negócio (HTTP 400 / 422).
final class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Sem conexão com a internet ou servidor inacessível.
final class NetworkException extends AppException {
  const NetworkException([super.message = 'Sem conexão. Verifique sua internet.']);
}

/// Erro inesperado do servidor (HTTP 500+).
final class ServerException extends AppException {
  const ServerException([super.message = 'Erro no servidor. Tente novamente.']);
}

/// Erro genérico não classificado.
final class UnknownException extends AppException {
  const UnknownException([super.message = 'Ocorreu um erro inesperado.']);
}
