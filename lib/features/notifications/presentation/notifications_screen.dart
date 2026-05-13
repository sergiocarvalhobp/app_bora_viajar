import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/notification_model.dart';

part 'notifications_screen.g.dart';

// ── Repository inline (simples o suficiente) ───────────────────────────────────

@riverpod
Future<List<NotificationModel>> notifications(Ref ref) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get(
      trpcUrl('notificacoes.listar'),
      queryParameters: {'input': '{"json":{}}'},
    );
    dynamic raw = res.data;
    if (raw is List) raw = raw.first;
    if (raw is Map<String, dynamic>) {
      final data = raw['result']?['data']?['json'] ?? raw['result']?['data'];
      if (data is List) {
        return data
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  } catch (e) {
    throw ErrorHandler.handle(e);
  }
}

@riverpod
class NotificationsNotifier extends _$NotificationsNotifier {
  @override
  AsyncValue<List<NotificationModel>> build() {
    final data = ref.watch(notificationsProvider);
    return data.when(
      data: AsyncData.new,
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    );
  }

  Future<void> marcarLida(int id) async {
    final dio = ref.read(apiClientProvider);
    try {
      await dio.post(trpcUrl('notificacoes.marcarLida'),
          data: {'0': {'json': {'id': id}}});
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  Future<void> marcarTodasLidas() async {
    final dio = ref.read(apiClientProvider);
    try {
      await dio.post(trpcUrl('notificacoes.marcarTodasLidas'),
          data: {'0': {'json': {}}});
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }
}

// ── Tela ───────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async  = ref.watch(notificationsProvider);
    final notif  = ref.read(notificationsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notificações',
            style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 20)),
        actions: [
          async.maybeWhen(
            data: (list) => list.any((n) => !n.lida)
                ? TextButton(
                    onPressed: notif.marcarTodasLidas,
                    child: const Text('Marcar todas',
                        style: TextStyle(color: Colors.white70,
                            fontFamily: 'Nunito', fontSize: 12)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.forest)),
        error: (e, _) => _ErrorState(
            onRetry: () => ref.invalidate(notificationsProvider)),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.forest,
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.sand,
                      indent: 72, endIndent: 16),
              itemBuilder: (context, i) => _NotificationItem(
                notification: list[i],
                onTap: () {
                  if (!list[i].lida) notif.marcarLida(list[i].id);
                  if (list[i].viagemId != null) {
                    context.push('/trips/${list[i].viagemId}');
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Item de notificação ────────────────────────────────────────────────────────

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });
  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n  = notification;
    final tt = Theme.of(context).textTheme;
    final isNew = !n.lida;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isNew
            ? AppColors.forest.withOpacity( 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone do tipo
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _iconBg(n.tipo),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconData(n.tipo),
                  color: _iconColor(n.tipo), size: 22),
            ),
            const SizedBox(width: 12),

            // Conteúdo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.titulo,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: isNew
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            )),
                      ),
                      if (isNew)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.terra,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(n.mensagem,
                      style: tt.bodySmall?.copyWith(
                          color: AppColors.barkMuted, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_timeAgo(n.createdAt),
                      style: tt.labelSmall?.copyWith(
                          color: AppColors.barkMuted.withOpacity( 0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconData(TipoNotificacao tipo) => switch (tipo) {
    TipoNotificacao.participante => Icons.person_add_outlined,
    TipoNotificacao.mensagem     => Icons.chat_bubble_outline_rounded,
    TipoNotificacao.sistema      => Icons.notifications_outlined,
  };

  Color _iconBg(TipoNotificacao tipo) => switch (tipo) {
    TipoNotificacao.participante => AppColors.forest.withOpacity( 0.12),
    TipoNotificacao.mensagem     => AppColors.terra.withOpacity( 0.12),
    TipoNotificacao.sistema      => AppColors.sand,
  };

  Color _iconColor(TipoNotificacao tipo) => switch (tipo) {
    TipoNotificacao.participante => AppColors.forest,
    TipoNotificacao.mensagem     => AppColors.terra,
    TipoNotificacao.sistema      => AppColors.barkMuted,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Agora';
    if (diff.inMinutes < 60)  return 'Há ${diff.inMinutes}min';
    if (diff.inHours < 24)    return 'Há ${diff.inHours}h';
    if (diff.inDays == 1)     return 'Ontem';
    if (diff.inDays < 7)      return 'Há ${diff.inDays} dias';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.notifications_none_rounded,
          size: 64, color: AppColors.sand),
      const SizedBox(height: 16),
      Text('Nenhuma notificação',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Fique por dentro de novas viagens e pedidos.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              color: AppColors.barkMuted)),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.barkMuted),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Tentar novamente'),
      ),
    ]),
  );
}
