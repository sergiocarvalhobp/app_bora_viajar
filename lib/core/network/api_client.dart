import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_constants.dart';
import '../app_env.dart';
import 'auth_interceptor.dart';

part 'api_client.g.dart';

/// Dio para o **Node** (Auth0, `/api/auth/token`, `/api/auth/logout`).
/// [AppEnv.effectiveBackendUrl] como `baseUrl`.
@riverpod
Dio authDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.effectiveBackendUrl,
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
  dio.interceptors.add(ref.watch(authInterceptorProvider));
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[Dio:auth] $obj'),
      ),
    );
    return true;
  }());
  return dio;
}

/// Dio para a **API REST Java** (`/api/v1/...`).
/// [AppEnv.effectiveApiBaseUrl] como `baseUrl`.
@riverpod
Dio apiClient(Ref ref) {
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
  dio.interceptors.add(ref.watch(authInterceptorProvider));
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[Dio:api] $obj'),
      ),
    );
    return true;
  }());
  return dio;
}
