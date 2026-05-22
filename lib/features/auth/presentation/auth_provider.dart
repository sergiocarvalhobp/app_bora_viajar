import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../auth_debug.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

part 'auth_provider.g.dart';

// ── Estado de autenticação ─────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

/// App ainda verificando se há sessão salva (splash/startup).
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Usuário autenticado com perfil carregado.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserModel user;
}

/// Nenhuma sessão ativa — deve ir para LoginScreen.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Erro durante login ou verificação de sessão.
final class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

// ── Notifier ───────────────────────────────────────────────────────────────────

@riverpod
class AuthNotifier extends _$AuthNotifier {
  /// Invalida resultado tardio de [_restoreSession] após o utilizador tocar em login.
  int _restoreGeneration = 0;

  @override
  AuthState build() {
    AuthDebug.log('build', 'início → AuthLoading');
    _restoreSession();
    return const AuthLoading();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void _logState(String from, AuthState next) {
    AuthDebug.log('state', '$from → ${next.runtimeType}');
  }

  /// Tenta restaurar sessão salva no SecureStorage.
  /// Chamado automaticamente no build().
  Future<void> _restoreSession() async {
    final gen = ++_restoreGeneration;
    AuthDebug.log('restore', 'a verificar SecureStorage…');
    try {
      final user = await _repo.tryRestoreSession();
      if (gen != _restoreGeneration) {
        AuthDebug.log('restore', 'ignorado (login em curso)');
        return;
      }
      if (user != null) {
        AuthDebug.log('restore', 'sessão OK userId=${user.id}');
        _logState('restore', state = AuthAuthenticated(user));
      } else {
        AuthDebug.log('restore', 'sem sessão');
        _logState('restore', state = const AuthUnauthenticated());
      }
    } catch (e, st) {
      AuthDebug.log('restore', 'falhou: $e');
      if (kDebugMode) AuthDebug.log('restore', 'stack: $st');
      if (gen != _restoreGeneration) return;
      _logState('restore', state = const AuthUnauthenticated());
    }
  }

  /// Inicia o fluxo de login com Google via Auth0.
  Future<void> loginWithGoogle() async {
    _restoreGeneration++;
    AuthDebug.log('login', 'botão Google → AuthLoading');
    _logState('login', state = const AuthLoading());
    try {
      final user = await _repo.loginWithGoogle();
      AuthDebug.log('login', 'sucesso userId=${user.id} name=${user.name}');
      _logState('login', state = AuthAuthenticated(user));
    } catch (e, st) {
      final message = e is AppException
          ? e.message
          : ErrorHandler.handle(e).message;
      AuthDebug.log('login', 'falhou: $message');
      AuthDebug.log('login', 'tipo=${e.runtimeType}');
      if (kDebugMode) AuthDebug.log('login', 'stack: $st');
      _logState('login', state = AuthError(message));
    }
  }

  /// Desloga o usuário — limpa sessão local e no servidor.
  Future<void> logout() async {
    state = const AuthLoading();
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  /// Atualiza o usuário em memória (ex.: resposta do PATCH /profile/me).
  void applyUserProfile(UserModel user) {
    if (state is AuthAuthenticated) {
      _logState('applyUserProfile', state = AuthAuthenticated(user));
    }
  }

  /// Recarrega o perfil do usuário (após editar perfil, por exemplo).
  Future<void> refreshUser() async {
    try {
      final user = await _repo.getMe();
      applyUserProfile(user);
    } catch (e) {
      AuthDebug.log('refreshUser', 'falhou: $e');
    }
  }
}

// ── Selectors convenientes ─────────────────────────────────────────────────────

/// Retorna o usuário autenticado ou null.
/// Ideal para widgets que só precisam saber se tem usuário logado.
@riverpod
UserModel? currentUser(Ref ref) {
  final authState = ref.watch(authNotifierProvider);
  return switch (authState) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };
}

/// Retorna true se o usuário está autenticado.
@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(currentUserProvider) != null;
}
