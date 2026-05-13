import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Converte qualquer erro de rede/HTTP em uma [AppException] tipada.
///
/// Uso nos repositories:
/// ```dart
/// try {
///   final res = await _dio.get(trpcUrl('auth.me'));
///   return UserModel.fromJson(res.data);
/// } catch (e) {
///   throw ErrorHandler.handle(e);
/// }
/// ```
abstract final class ErrorHandler {
  /// Transforma o erro em [AppException].
  /// Se já for uma [AppException], retorna sem alterar.
  static AppException handle(Object error) {
    if (error is AppException) return error;

    if (error is DioException) {
      return _fromDio(error);
    }

    return const UnknownException();
  }

  static AppException _fromDio(DioException e) {
    // Sem resposta do servidor — problema de rede
    if (e.response == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const NetworkException('Tempo limite excedido. Verifique sua internet.');
        case DioExceptionType.connectionError:
          return const NetworkException();
        default:
          return const NetworkException();
      }
    }

    final status = e.response!.statusCode ?? 0;
    final body   = e.response!.data;

    // Mensagem de erro retornada pelo tRPC/Express
    final serverMessage = _extractMessage(body);

    return switch (status) {
      401 || 403 => AuthException(serverMessage ?? 'Sessão expirada. Faça login novamente.'),
      404        => NotFoundException(serverMessage ?? 'Recurso não encontrado.'),
      400 || 422 => ValidationException(serverMessage ?? 'Dados inválidos.'),
      >= 500     => ServerException(serverMessage ?? 'Erro no servidor.'),
      _          => UnknownException(serverMessage ?? 'Erro inesperado ($status).'),
    };
  }

  /// Extrai a mensagem de erro de respostas tRPC ou Express.
  ///
  /// tRPC retorna: { "error": { "message": "..." } }
  ///   ou lista:   [{ "error": { "message": "..." } }]
  /// Express direto: { "error": "..." } ou { "message": "..." }
  static String? _extractMessage(dynamic body) {
    if (body == null) return null;

    try {
      // Resposta tRPC em lista (batch)
      if (body is List && body.isNotEmpty) {
        return _extractMessage(body.first);
      }

      if (body is Map<String, dynamic>) {
        // tRPC: { error: { message: "..." } }
        final trpcError = body['error'];
        if (trpcError is Map<String, dynamic>) {
          final msg = trpcError['message'];
          if (msg is String && msg.isNotEmpty) return msg;
        }

        // Express direto: { error: "..." }
        final directError = body['error'];
        if (directError is String && directError.isNotEmpty) {
          return directError;
        }

        // Express: { message: "..." }
        final message = body['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Corpo não é JSON — ignora
    }

    return null;
  }
}
