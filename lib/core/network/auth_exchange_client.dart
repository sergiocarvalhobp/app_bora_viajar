import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_constants.dart';
import '../app_env.dart';

part 'auth_exchange_client.g.dart';

/// HTTP só para troca Auth0 → JWT — sem interceptor de sessão (evita 403 na borda).
@riverpod
Dio authExchangeClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.effectiveApiBaseUrl,
      connectTimeout: const Duration(seconds: AppConstants.httpTimeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConstants.httpTimeoutSeconds),
      sendTimeout: const Duration(seconds: AppConstants.httpTimeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: true,
        logPrint: (obj) => debugPrint('[Auth:exchange] $obj'),
      ),
    );
  }
  return dio;
}
