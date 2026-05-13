import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
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

  Future<void> _send() async {
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
    final tripAsync   = ref.watch(tripDetailsProvider(widget.tripId));
    final chatState   = ref.watch(chatNotifierProvider(widget.tripId));
    final currentUser = ref.watch(currentUserProvider);

    // Scroll ao receber novas mensagens
    ref.listen(chatNotifierProvider(widget.tripId), (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8), // tom levemente texturizado
      appBar: _ChatAppBar(
        tripAsync: tripAsync,
        tripId: widget.tripId,
      ),
      body: Column(
        children: [
          // ── Lista de mensagens ─────────────────────────────────────────
          Expanded(
            child: _MessageList(
              messages:       chatState.messages,
              currentUser:    currentUser,
              scrollController: _scrollController,
              tripId:         widget.tripId,
            ),
          ),

          // Banner de erro de envio
          if (chatState.sendError != null)
            _ErrorBanner(
              message: chatState.sendError!,
              onDismiss: () => ref
                  .read(chatNotifierProvider(widget.tripId).notifier)
                  // Limpa o erro invalidando o state
                  .enviar(''), // chamada vazia — não envia nada, só limpa
            ),

          // ── Input de mensagem ──────────────────────────────────────────
          _MessageInput(
            controller:  _inputController,
            focusNode:   _focusNode,
            canSend:     _canSend,
            isSending:   chatState.isSending,
            onSend:      _send,
          ),
        ],
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
            style: TextStyle(fontFamily: 'DMSerifDisplay', color: Colors.white)),
        error: (_, __) => const Text('Chat',
            style: TextStyle(fontFamily: 'DMSerifDisplay', color: Colors.white)),
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
              '${trip.participantesCount} participante${trip.participantesCount != 1 ? 's' : ''}',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Botão para ver detalhes da viagem
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, size: 22),
          onPressed: () => context.go('/trips/$tripId'),
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
  });

  final List<MessageModel> messages;
  final UserModel? currentUser;
  final ScrollController scrollController;
  final int tripId;

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

        final msg     = item as MessageModel;
        final isMinha = currentUser != null && msg.isMinha(currentUser!.id);
        final isOtimista = msg is OptimisticMessage;

        // Verifica se deve mostrar o avatar (primeiro de uma sequência)
        final showAvatar = !isMinha && (i == 0 ||
            groups[i - 1] is _DateSeparator ||
            (groups[i - 1] is MessageModel &&
                (groups[i - 1] as MessageModel).senderId != msg.senderId));

        return _MessageBubble(
          key: ValueKey(msg.id),
          message:      msg,
          isMinha:      isMinha,
          showAvatar:   showAvatar,
          isPending:    isOtimista && (msg).pending,
          isFailed:     isOtimista && (msg).failed,
          onReenviar:   isOtimista && (msg).failed
              ? () {} // será conectado via Consumer
              : null,
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
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);

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
    this.onReenviar,
  });

  final MessageModel message;
  final bool isMinha;
  final bool showAvatar;
  final bool isPending;
  final bool isFailed;
  final VoidCallback? onReenviar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripId = message.viagemId;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 2,
        left:  isMinha ? 48 : 0,
        right: isMinha ? 0  : 48,
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
              onLongPress: isMinha
                  ? () => _onLongPress(context)
                  : null,
              child: Column(
                crossAxisAlignment: isMinha
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
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
                      color: isMinha
                          ? AppColors.forest
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(18),
                        topRight:    const Radius.circular(18),
                        bottomLeft:  Radius.circular(isMinha ? 18 : 4),
                        bottomRight: Radius.circular(isMinha ? 4  : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
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
                            isFailed:  isFailed,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Botão reenviar (mensagem falhou)
                  if (isFailed)
                    TextButton.icon(
                      onPressed: () {
                        if (message is OptimisticMessage) {
                          ref.read(chatNotifierProvider(tripId).notifier)
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
        width: 10, height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(AppColors.barkMuted),
        ),
      );
    }
    // Enviado com sucesso
    return const Icon(Icons.done_all_rounded,
        size: 12, color: Colors.white70);
  }
}

// ── Avatar do remetente ────────────────────────────────────────────────────────

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.sender});
  final UserModel? sender;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: AppColors.sand,
      backgroundImage: sender?.foto != null
          ? CachedNetworkImageProvider(sender!.foto!)
          : null,
      child: sender?.foto == null
          ? Text(
              sender?.initials ?? '?',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.bark,
              ),
            )
          : null,
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

// ── Input de mensagem ──────────────────────────────────────────────────────────

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
        12, 10, 12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.sand)),
        boxShadow: [
          BoxShadow(
            color: AppColors.bark.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Campo de texto
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.sand),
              ),
              child: TextField(
                controller:  controller,
                focusNode:   focusNode,
                maxLines:    null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppColors.bark,
                ),
                decoration: const InputDecoration(
                  hintText: 'Mensagem...',
                  hintStyle: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppColors.barkMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
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
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: canSend ? AppColors.forest : AppColors.sand,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
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
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.1),
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
