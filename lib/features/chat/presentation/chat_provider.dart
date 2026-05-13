import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/chat_repository.dart';
import '../domain/message_model.dart';

part 'chat_provider.g.dart';

// ── Estado do chat ─────────────────────────────────────────────────────────────

class ChatState {
  const ChatState({
    this.messages    = const [],
    this.isSending   = false,
    this.sendError,
    this.isPolling   = false,
  });

  final List<MessageModel> messages;
  final bool isSending;
  final String? sendError;
  final bool isPolling;

  /// Último ID real (não otimista) — usado pelo polling incremental.
  int? get lastRealId {
    for (final m in messages.reversed) {
      if (m is! OptimisticMessage) return m.id;
    }
    return null;
  }

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isSending,
    String? sendError,
    bool clearError = false,
    bool? isPolling,
  }) {
    return ChatState(
      messages:  messages  ?? this.messages,
      isSending: isSending ?? this.isSending,
      sendError: clearError ? null : sendError ?? this.sendError,
      isPolling: isPolling ?? this.isPolling,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

@riverpod
class ChatNotifier extends _$ChatNotifier {
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 4);

  @override
  ChatState build(int tripId) {
    // Carrega mensagens iniciais e inicia polling ao criar o provider
    Future.microtask(_init);

    // Cancela timer quando o provider é descartado (tela fechada)
    ref.onDispose(() => _pollTimer?.cancel());

    return const ChatState();
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  // ── Inicialização ──────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _carregarMensagens();
    _iniciarPolling();
  }

  Future<void> _carregarMensagens() async {
    state = state.copyWith(isPolling: true);
    try {
      final msgs = await _repo.listar(tripId);
      state = state.copyWith(messages: msgs, isPolling: false);
    } catch (_) {
      state = state.copyWith(isPolling: false);
    }
  }

  // ── Polling incremental ────────────────────────────────────────────────────
  // Busca apenas mensagens novas (afterId) a cada 4s.
  // Quando o backend tiver WebSocket, basta substituir este bloco.

  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    final lastId = state.lastRealId;
    try {
      final novas = lastId != null
          ? await _repo.listarDesde(tripId, lastId)
          : await _repo.listar(tripId);

      if (novas.isEmpty) return;

      // Remove otimistas que já chegaram do servidor e anexa novas mensagens
      final msgs = List<MessageModel>.from(state.messages)
        ..removeWhere((m) =>
            m is OptimisticMessage && novas.any((n) => n.id == m.id))
        ..addAll(novas);

      state = state.copyWith(messages: msgs);
    } catch (_) {
      // Polling silencioso — não exibe erro para não interromper o UX
    }
  }

  // ── Envio com mensagem otimista ────────────────────────────────────────────

  Future<void> enviar(String conteudo) async {
    final texto = conteudo.trim();
    if (texto.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isSending: true, clearError: true);

    // Mensagem otimista: aparece imediatamente na lista
    final otimista = OptimisticMessage(
      id:        -DateTime.now().millisecondsSinceEpoch, // ID temporário negativo
      viagemId:  tripId,
      senderId:  user.id,
      conteudo:  texto,
      timestamp: DateTime.now(),
      sender:    user,
      pending:   true,
    );

    state = state.copyWith(
      messages: [...state.messages, otimista],
      isSending: true,
    );

    try {
      final real = await _repo.enviar(tripId, texto);

      // Substitui a otimista pela mensagem real do servidor
      final msgs = state.messages.map((m) {
        if (m is OptimisticMessage && m.id == otimista.id) return real;
        return m;
      }).toList();

      state = state.copyWith(messages: msgs, isSending: false);
    } catch (e) {
      // Marca a otimista como falhou
      final msgs = state.messages.map((m) {
        if (m is OptimisticMessage && m.id == otimista.id) {
          return m.copyWithState(pending: false, failed: true);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages:  msgs,
        isSending: false,
        sendError: 'Não foi possível enviar a mensagem.',
      );
    }
  }

  /// Reenvia uma mensagem que falhou.
  Future<void> reenviar(OptimisticMessage msg) async {
    // Remove a falha da lista e tenta enviar de novo
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != msg.id).toList(),
    );
    await enviar(msg.conteudo);
  }
}
