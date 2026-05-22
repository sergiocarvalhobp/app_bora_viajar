import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_constants.dart';

part 'secure_storage.g.dart';

/// Opções de armazenamento seguro.
/// Android: AES256_CBC no Keystore.
/// iOS: Keychain com acessibilidade afterFirstUnlock (app funciona em background).
const _androidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);

const _iosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock,
);

/// Provider do SecureStorage — singleton para o app todo.
@riverpod
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}

/// Serviço de alto nível para salvar/ler/apagar o token de sessão JWT.
///
/// O token é o mesmo cookie "app_session_id" que o backend seta após o
/// callback Auth0 — no app, apenas armazenamos o valor bruto do JWT.
@riverpod
SessionStorage sessionStorage(Ref ref) {
  final storage = ref.watch(secureStorageProvider);
  return SessionStorage(storage);
}

class SessionStorage {
  const SessionStorage(this._storage);
  final FlutterSecureStorage _storage;

  /// Lê o JWT de sessão. Retorna null se não houver sessão ou dados corrompidos.
  ///
  /// No Android, reinstalação ou mudança de Keystore pode gerar
  /// [PlatformException] (BadPaddingException) — nesse caso apagamos a chave.
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: AppConstants.sessionKey);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SessionStorage] leitura falhou (${e.code}): ${e.message} — limpando token',
        );
      }
      await _purgeSessionKey();
      return null;
    }
  }

  Future<void> _purgeSessionKey() async {
    try {
      await _storage.delete(key: AppConstants.sessionKey);
    } catch (_) {
      // best-effort
    }
  }

  /// Persiste o JWT de sessão recebido após o login.
  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.sessionKey, value: token);
  }

  /// Remove o JWT — chamado no logout.
  Future<void> deleteToken() async {
    await _storage.delete(key: AppConstants.sessionKey);
  }

  /// Verifica rapidamente se há uma sessão salva (sem validar o JWT).
  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }
}
