import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/trip_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_avatar.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../trips/domain/trip_model.dart';
import '../../trips/presentation/trip_details_provider.dart';
import '../domain/message_model.dart';
import '../presentation/chat_provider.dart';

class ChatTripScreen extends ConsumerStatefulWidget {
  const ChatTripScreen({super.key, required this.tripId});
  final int tripId;

  @override
  ConsumerState<ChatTripScreen> createState() => _ChatTripScreenState();
}

class _ChatTripScreenState extends ConsumerState<ChatTripScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final can = _inputController.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        pos,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(pos);
    }
  }

  Future<void> _send({required bool chatReadOnly}) async {
    if (chatReadOnly) return;
    final texto = _inputController.text.trim();
    if (texto.isEmpty) return;
    _inputController.clear();
    setState(() => _canSend = false);
    await ref.read(chatNotifierProvider(widget.tripId).notifier).enviar(texto);
    // Scroll para a última mensagem após envio
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailsProvider(widget.tripId));
    final currentUser = ref.watch(currentUserProvider);

    return tripAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text('Erro ao carregar viagem: $e')),
      ),
      data: (trip) {
        if (!trip.canAccessChat(currentUser?.id)) {
          return _ChatLockedScreen(trip: trip, tripId: widget.tripId);
        }
        return _ChatBody(
          tripId: widget.tripId,
          trip: trip,
          currentUser: currentUser,
          inputController: _inputController,
          scrollController: _scrollController,
          focusNode: _focusNode,
          canSend: _canSend,
          onSend: _send,
        );
      },
    );
  }
}

class _ChatBody extends ConsumerWidget {
  const _ChatBody({
    required this.tripId,
    required this.trip,
    required this.currentUser,
    required this.inputController,
    required this.scrollController,
    required this.focusNode,
    required this.canSend,
    required this.onSend,
  });

  final int tripId;
  final TripModel trip;
  final UserModel? currentUser;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool canSend;
  final Future<void> Function({required bool chatReadOnly}) onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatNotifierProvider(tripId));
    final chatReadOnly = trip.isTripFinished;

    if (chatReadOnly) {
      focusNode.unfocus();
    }

    ref.listen(chatNotifierProvider(tripId), (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8), // tom levemente texturizado
      appBar: _ChatAppBar(
        tripAsync: AsyncData(trip),
        tripId: tripId,
      ),
      body: Column(
        children: [
          Expanded(
            child: _MessageList(
              messages: chatState.messages,
              currentUser: currentUser,
              scrollController: scrollController,
              tripId: tripId,
              chatReadOnly: chatReadOnly,
            ),
          ),
          if (chatState.sendError != null && !chatReadOnly)
            _ErrorBanner(
              message: chatState.sendError!,
              onDismiss: () =>
                  ref.read(chatNotifierProvider(tripId).notifier).clearSendError(),
            ),
          if (chatReadOnly)
            const _ChatReadOnlyBar()
          else
            _MessageInput(
              controller: inputController,
              focusNode: focusNode,
              canSend: canSend,
              isSending: chatState.isSending,
              onSend: () => onSend(chatReadOnly: false),
            ),
        ],
      ),
    );
  }
}

class _ChatLockedScreen extends StatelessWidget {
  const _ChatLockedScreen({required this.trip, required this.tripId});
  final TripModel trip;
  final int tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          trip.destino,
          style: const TextStyle(
            fontFamily: 'DMSerifDisplay',
            fontSize: 17,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.forest.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chat ainda não liberado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DMSerifDisplay',
                  fontSize: 22,
                  color: AppColors.bark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                trip.isAguardandoConfirmacao
                    ? 'Aguarde o organizador confirmar sua participação para conversar com o grupo.'
                    : 'Participe da viagem e aguarde a confirmação do organizador.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.barkMuted,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => openTripDetails(context, tripId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.forest),
                ),
                child: const Text('Voltar aos detalhes da viagem'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppBar do chat ─────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.tripAsync, required this.tripId});
  final AsyncValue<TripModel> tripAsync;
  final int tripId;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.forest,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => context.pop(),
      ),
      title: tripAsync.when(
        loading: () => const Text('Chat',
            style:
                TextStyle(fontFamily: 'DMSerifDisplay', color: Colors.white)),
        error: (_, __) => const Text('Chat',
            style:
                TextStyle(fontFamily: 'DMSerifDisplay', color: Colors.white)),
        data: (trip) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.destino,
              style: const TextStyle(
                fontFamily: 'DMSerifDisplay',
                fontSize: 17,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              trip.isTripFinished
                  ? 'Viagem encerrada · somente leitura'
                  : '${trip.participantesCount} participante${trip.participantesCount != 1 ? 's' : ''}',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Botão para ver detalhes da viagem
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, size: 22),
          onPressed: () => openTripDetails(context, tripId),
        ),
      ],
    );
  }
}

// ── Lista de mensagens ─────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentUser,
    required this.scrollController,
    required this.tripId,
    required this.chatReadOnly,
  });

  final List<MessageModel> messages;
  final UserModel? currentUser;
  final ScrollController scrollController;
  final int tripId;
  final bool chatReadOnly;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyChatState();
    }

    // Agrupa mensagens por data para exibir separadores de dia
    final groups = _groupByDate(messages);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final item = groups[i];

        if (item is _DateSeparator) {
          return _DateDivider(label: item.label);
        }

        final msg = item as MessageModel;
        final isMinha = currentUser != null && msg.isMinha(currentUser!.id);
        final isOtimista = msg is OptimisticMessage;

        // Verifica se deve mostrar o avatar (primeiro de uma sequência)
        final showAvatar = !isMinha &&
            (i == 0 ||
                groups[i - 1] is _DateSeparator ||
                (groups[i - 1] is MessageModel &&
                    (groups[i - 1] as MessageModel).senderId != msg.senderId));

        return _MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          isMinha: isMinha,
          showAvatar: showAvatar,
          isPending: isOtimista && (msg).pending,
          isFailed: isOtimista && (msg).failed && !chatReadOnly,
          tripId: tripId,
          chatReadOnly: chatReadOnly,
        );
      },
    );
  }

  List<dynamic> _groupByDate(List<MessageModel> msgs) {
    final result = <dynamic>[];
    String? lastDate;

    for (final msg in msgs) {
      final dateStr = _formatDate(msg.timestamp);
      if (dateStr != lastDate) {
        result.add(_DateSeparator(dateStr));
        lastDate = dateStr;
      }
      result.add(msg);
    }

    return result;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);

    if (d == today) return 'Hoje';
    if (d == today.subtract(const Duration(days: 1))) return 'Ontem';
    return DateFormat("d 'de' MMMM", 'pt_BR').format(dt);
  }
}

class _DateSeparator {
  const _DateSeparator(this.label);
  final String label;
}

// ── Bolha de mensagem ──────────────────────────────────────────────────────────

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMinha,
    required this.showAvatar,
    required this.isPending,
    required this.isFailed,
    required this.tripId,
    required this.chatReadOnly,
  });

  final MessageModel message;
  final bool isMinha;
  final bool showAvatar;
  final bool isPending;
  final bool isFailed;
  final int tripId;
  final bool chatReadOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Padding(
      padding: EdgeInsets.only(
        bottom: 2,
        left: isMinha ? 48 : 0,
        right: isMinha ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMinha ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (lado esquerdo, só para mensagens alheias)
          if (!isMinha)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: showAvatar
                  ? _SenderAvatar(sender: message.sender)
                  : const SizedBox(width: 30),
            ),

          // Bolha
          Flexible(
            child: GestureDetector(
              onLongPress: isMinha ? () => _onLongPress(context) : null,
              child: Column(
                crossAxisAlignment:
                    isMinha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Nome do remetente (mensagens alheias, apenas primeiro da sequência)
                  if (!isMinha && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.barkMuted,
                        ),
                      ),
                    ),

                  // Bolha propriamente dita
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMinha ? AppColors.forest : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMinha ? 18 : 4),
                        bottomRight: Radius.circular(isMinha ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.conteudo,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        height: 1.45,
                        color: isMinha ? Colors.white : AppColors.bark,
                      ),
                    ),
                  ),

                  // Horário + status
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            color: AppColors.barkMuted,
                          ),
                        ),
                        if (isMinha) ...[
                          const SizedBox(width: 4),
                          _StatusIcon(
                            isPending: isPending,
                            isFailed: isFailed,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Botão reenviar (mensagem falhou; não disponível com viagem encerrada)
                  if (isFailed && !chatReadOnly)
                    TextButton.icon(
                      onPressed: () {
                        if (message is OptimisticMessage) {
                          ref
                              .read(chatNotifierProvider(tripId).notifier)
                              .reenviar(message as OptimisticMessage);
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Reenviar',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.terra,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onLongPress(BuildContext context) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: message.conteudo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensagem copiada'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.isPending, required this.isFailed});
  final bool isPending;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    if (isFailed) {
      return const Icon(Icons.error_outline_rounded,
          size: 12, color: AppColors.terra);
    }
    if (isPending) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(AppColors.barkMuted),
        ),
      );
    }
    // Enviado com sucesso
    return const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70);
  }
}

// ── Avatar do remetente ────────────────────────────────────────────────────────

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.sender});
  final UserModel? sender;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      foto: sender?.foto,
      name: sender?.name,
      initials: sender?.initials,
      radius: 15,
    );
  }
}

// ── Separador de data ──────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.sand)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.barkMuted,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.sand)),
        ],
      ),
    );
  }
}

// ── Barra de chat encerrado (somente leitura) ─────────────────────────────────

class _ChatReadOnlyBar extends StatelessWidget {
  const _ChatReadOnlyBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: const Border(top: BorderSide(color: AppColors.sand)),
        boxShadow: [
          BoxShadow(
            color: AppColors.bark.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: AppColors.barkMuted.withOpacity(0.9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta viagem já encerrou. O chat está em modo de visualização.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                height: 1.35,
                color: AppColors.barkMuted.withOpacity(0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input de mensagem ──────────────────────────────────────────────────────────

OutlineInputBorder _chatInputBorder({Color? color, double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide(
      color: color ?? AppColors.sand,
      width: width,
    ),
  );
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: const Border(top: BorderSide(color: AppColors.sand)),
        boxShadow: [
          BoxShadow(
            color: AppColors.bark.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Campo de texto — borda e fundo só no InputDecoration (evita retângulo interno)
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: AppColors.forest,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppColors.bark,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Mensagem...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppColors.barkMuted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: _chatInputBorder(),
                  enabledBorder: _chatInputBorder(),
                  focusedBorder: _chatInputBorder(
                    color: AppColors.forest,
                    width: 1.5,
                  ),
                ),
                onSubmitted: (_) => canSend ? onSend() : null,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Botão enviar
          AnimatedScale(
            scale: canSend ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: canSend && !isSending ? onSend : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSend ? AppColors.forest : AppColors.cream,
                  shape: BoxShape.circle,
                  border: canSend
                      ? null
                      : Border.all(
                          color: AppColors.barkMuted.withOpacity(0.35)),
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: canSend ? Colors.white : AppColors.barkMuted,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estado vazio ───────────────────────────────────────────────────────────────

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.forest.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma mensagem ainda',
              style: TextStyle(
                fontFamily: 'DMSerifDisplay',
                fontSize: 20,
                color: AppColors.bark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seja o primeiro a dizer olá\npara os companheiros de viagem!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: AppColors.barkMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner de erro ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.terra),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AppColors.terra,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onDismiss,
            color: AppColors.terra,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
