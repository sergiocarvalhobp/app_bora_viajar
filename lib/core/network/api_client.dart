import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_constants.dart';
import '../app_env.dart';
import 'auth_interceptor.dart';

part 'api_client.g.dart';

/// Instância global do Dio, configurada para o backend Bora Viajar.
///
/// Todas as requisições partem daqui — features nunca criam Dio diretamente.
@riverpod
Dio apiClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.backendUrl,
      connectTimeout: const Duration(seconds: AppConstants.httpTimeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConstants.httpTimeoutSeconds),
      sendTimeout: const Duration(seconds: AppConstants.httpTimeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // O backend retorna erros HTTP como JSON — não lançar DioException
      // para status >= 400 automaticamente (tratamos no interceptor).
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // Injeta o JWT de sessão em cada requisição
  dio.interceptors.add(ref.watch(authInterceptorProvider));

  // Log em modo debug
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[Dio] $obj'),
      ),
    );
    return true;
  }());

  return dio;
}

/// Helper para construir a URL de um procedure tRPC.
///
/// tRPC via HTTP:
///   GET  /api/trpc/auth.me
///   POST /api/trpc/viagens.criar   (body: { "0": { json: payload } })
///
/// Uso:
///   final url = trpcUrl('auth.me');          // '/api/trpc/auth.me'
///   final url = trpcUrl('viagens.listar');   // '/api/trpc/viagens.listar'
String trpcUrl(String procedure) =>
    '${AppConstants.trpcPrefix}/$procedure';
