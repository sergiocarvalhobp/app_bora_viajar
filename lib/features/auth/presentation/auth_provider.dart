import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
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
  @override
  AuthState build() {
    // Inicia verificação de sessão assim que o provider é criado
    _restoreSession();
    return const AuthLoading();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Tenta restaurar sessão salva no SecureStorage.
  /// Chamado automaticamente no build().
  Future<void> _restoreSession() async {
    final user = await _repo.tryRestoreSession();
    if (user != null) {
      state = AuthAuthenticated(user);
    } else {
      state = const AuthUnauthenticated();
    }
  }

  /// Inicia o fluxo de login com Google via Auth0.
  Future<void> loginWithGoogle() async {
    state = const AuthLoading();
    try {
      final user = await _repo.loginWithGoogle();
      state = AuthAuthenticated(user);
    } catch (e) {
      final message = e is AppException
          ? e.message
          : ErrorHandler.handle(e).message;
      state = AuthError(message);
    }
  }

  /// Desloga o usuário — limpa sessão local e no servidor.
  Future<void> logout() async {
    state = const AuthLoading();
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  /// Recarrega o perfil do usuário (após editar perfil, por exemplo).
  Future<void> refreshUser() async {
    try {
      final user = await _repo.getMe();
      state = AuthAuthenticated(user);
    } catch (_) {
      // Mantém estado atual se falhar
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
