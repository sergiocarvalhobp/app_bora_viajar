import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/avatar_image_provider.dart';
import '../../../core/ui/destination_image_resolver.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/trip_model.dart';
import '../presentation/trip_details_provider.dart';

/// Card de viagem — usado na SearchTripsScreen e MyHistoryScreen.
class TripCard extends ConsumerWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.showActions = false,
  });

  final TripModel trip;
  final VoidCallback onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;

    return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sand),
          boxShadow: [
            BoxShadow(
              color: AppColors.bark.withOpacity( 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(20),
                  bottom: Radius.circular(showActions ? 0 : 20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // ── Imagem do destino ───────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _DestinationImage(
                  destino: trip.destino,
                  estado: trip.estado,
                  cidade: trip.cidade,
                  atrativo: trip.atrativo,
                ),
              ),
            ),

            // ── Conteúdo ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge tipo + vagas
                  Row(
                    children: [
                      _TipoBadge(tipo: trip.tipo),
                      const Spacer(),
                      if (trip.maxVagas != null)
                        _VagasBadge(trip: trip),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Destino
                  Text(
                    trip.destino,
                    style: tt.titleLarge?.copyWith(
                      fontFamily: 'DMSerifDisplay',
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (trip.atrativo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      trip.atrativo!,
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.terra,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Datas + duração
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.barkMuted),
                      const SizedBox(width: 6),
                      Text(
                        trip.periodoFormatado,
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.barkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${trip.duracaoDias}d',
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.barkMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Descrição
                  Text(
                    trip.descricao,
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.barkMuted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Rodapé: líder + participantes
                  Row(
                    children: [
                      if (trip.lider != null) ...[
                        _LiderAvatar(lider: trip.lider!),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.lider!.name,
                            style: tt.labelMedium?.copyWith(
                              color: AppColors.bark,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(Icons.people_outline,
                          size: 14, color: AppColors.barkMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.participantesCount}',
                        style: tt.labelMedium?.copyWith(
                          color: AppColors.barkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
                  ],
                ),
              ),
            ),
            if (showActions)
              _TripCardActions(trip: trip),
          ],
        ),
      );
  }
}

// ── Ações: chat + participar (home) ───────────────────────────────────────────

class _TripCardActions extends ConsumerWidget {
  const _TripCardActions({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final participation =
        ref.watch(tripParticipationNotifierProvider(trip.id));

    ref.listen(tripParticipationNotifierProvider(trip.id), (prev, next) {
      if (next is AsyncError) {
        final msg = next.error is AppException
            ? (next.error as AppException).message
            : 'Não foi possível atualizar sua participação.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      } else if (prev is AsyncLoading && next is AsyncData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trip.isParticipando
                  ? 'Interesse cancelado.'
                  : 'Interesse enviado! O organizador foi avisado.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final isLider = user?.id == trip.liderId;
    final isLoading = participation is AsyncLoading;
    final canChat = isLider || trip.isParticipando;
    final canParticipar =
        !isLider && !trip.isParticipando && trip.temVagasDisponiveis;
    final isLotado = !isLider && !trip.isParticipando && !trip.temVagasDisponiveis;

    if (!canChat && !canParticipar && !isLotado && !isLider) {
      return const SizedBox.shrink();
    }

    final notif =
        ref.read(tripParticipationNotifierProvider(trip.id).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1, color: AppColors.sand),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              if (canChat) ...[
                _CardChatButton(
                  tooltip: 'Abrir chat',
                  onTap: () => context.push('/trips/${trip.id}/chat'),
                ),
                const SizedBox(width: 10),
              ],
              if (isLider)
                const Expanded(
                  child: _CardStatusChip(
                    label: 'Você organiza',
                    icon: Icons.star_rounded,
                    variant: _CardActionVariant.muted,
                  ),
                )
              else if (canParticipar)
                Expanded(
                  child: _CardActionButton(
                    label: 'Quero participar',
                    icon: Icons.explore_outlined,
                    variant: _CardActionVariant.primary,
                    isLoading: isLoading,
                    onTap: isLoading ? null : () => notif.participar(),
                  ),
                )
              else if (trip.isParticipando)
                Expanded(
                  child: _CardParticipatingBar(
                    confirmed: trip.myStatus == 'confirmado',
                    isLoading: isLoading,
                    onCancel: () => _confirmCancelInterest(context, notif),
                  ),
                )
              else if (isLotado)
                const Expanded(
                  child: _CardStatusChip(
                    label: 'Viagem lotada',
                    icon: Icons.event_busy_rounded,
                    variant: _CardActionVariant.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmCancelInterest(
    BuildContext context,
    TripParticipationNotifier notif,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar interesse?',
            style: TextStyle(fontFamily: 'DMSerifDisplay')),
        content: const Text(
          'Você deixará de aparecer como interessado nesta viagem.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Manter'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar interesse',
                style: TextStyle(color: AppColors.terra)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await notif.cancelar();
    }
  }
}

enum _CardActionVariant { primary, success, muted }

class _CardChatButton extends StatelessWidget {
  const _CardChatButton({required this.onTap, this.tooltip});
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.forest.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.forest.withOpacity(0.35)),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.forest,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.variant,
    this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final _CardActionVariant variant;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = switch (variant) {
      _CardActionVariant.primary => (
        bg: AppColors.terra,
        fg: Colors.white,
        border: AppColors.terra,
      ),
      _CardActionVariant.success => (
        bg: const Color(0xFFE8F5EE),
        fg: AppColors.forest,
        border: AppColors.forest.withOpacity(0.35),
      ),
      _CardActionVariant.muted => (
        bg: AppColors.sand,
        fg: AppColors.barkMuted,
        border: AppColors.sand,
      ),
    };

    return Material(
      color: colors.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colors.fg),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 17, color: colors.fg),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: colors.fg,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CardStatusChip extends StatelessWidget {
  const _CardStatusChip({
    required this.label,
    required this.icon,
    required this.variant,
  });

  final String label;
  final IconData icon;
  final _CardActionVariant variant;

  @override
  Widget build(BuildContext context) {
    return _CardActionButton(
      label: label,
      icon: icon,
      variant: variant,
    );
  }
}

class _CardParticipatingBar extends StatelessWidget {
  const _CardParticipatingBar({
    required this.confirmed,
    required this.isLoading,
    required this.onCancel,
  });

  final bool confirmed;
  final bool isLoading;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final title = confirmed ? 'Confirmado pelo líder' : 'Interesse enviado';
    final subtitle = confirmed
        ? 'Você faz parte desta viagem'
        : 'Aguardando resposta do organizador';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.forest.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            confirmed ? Icons.verified_rounded : Icons.check_circle_rounded,
            color: AppColors.forest,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.forest,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    color: AppColors.forest.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          if (!confirmed)
            TextButton(
              onPressed: isLoading ? null : onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.terra,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Imagem do destino ──────────────────────────────────────────────────────────

class _DestinationImage extends StatelessWidget {
  const _DestinationImage({
    required this.destino,
    this.estado,
    this.cidade,
    this.atrativo,
  });

  final String destino;
  final String? estado;
  final String? cidade;
  final String? atrativo;

  // Gradientes por bioma brasileiro (fallback visual sem depender de API)
  static const _gradients = {
    'amazônia':  [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
    'pantanal':  [Color(0xFF4A7C59), Color(0xFF2D5A3D)],
    'nordeste':  [Color(0xFFC4622D), Color(0xFF8B3A14)],
    'cerrado':   [Color(0xFF8B6914), Color(0xFF5C4209)],
    'sul':       [Color(0xFF2D6A8F), Color(0xFF1A3F5C)],
    'serra':     [Color(0xFF5C7A3E), Color(0xFF3A5226)],
  };

  List<Color> get _gradient {
    final lower = destino.toLowerCase();
    for (final entry in _gradients.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return [AppColors.forest, AppColors.forestDk];
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = resolveDestinationAsset(
      destino: destino,
      estado: estado,
      cidade: cidade,
      atrativo: atrativo,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            defaultDestinationAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackBackground(),
          ),
        ),

        // Overlay para legibilidade
        Container(
          color: Colors.black.withOpacity(0.20),
        ),

        // Overlay escuro suave na base para legibilidade
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity( 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Nome do destino
        Positioned(
          left: 14,
          right: 14,
          bottom: 10,
          child: Text(
            destino,
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'DMSerifDisplay',
              fontSize: 20,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
      ),
    );
  }
}

// ── Badges ─────────────────────────────────────────────────────────────────────

class _TipoBadge extends StatelessWidget {
  const _TipoBadge({required this.tipo});
  final TipoViagem tipo;

  @override
  Widget build(BuildContext context) {
    final isLider = tipo == TipoViagem.lider;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLider
            ? AppColors.forest.withOpacity( 0.12)
            : AppColors.terra.withOpacity( 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLider ? Icons.star_outline_rounded : Icons.explore_outlined,
            size: 12,
            color: isLider ? AppColors.forest : AppColors.terra,
          ),
          const SizedBox(width: 4),
          Text(
            tipo.label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isLider ? AppColors.forestDk : AppColors.terra,
            ),
          ),
        ],
      ),
    );
  }
}

class _VagasBadge extends StatelessWidget {
  const _VagasBadge({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final vagas = trip.vagasDisponiveis!;
    final semVagas = vagas == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: semVagas
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: semVagas
              ? const Color(0xFFFCA5A5)
              : const Color(0xFF86EFAC),
        ),
      ),
      child: Text(
        semVagas ? 'Lotado' : '$vagas vagas',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: semVagas ? AppColors.error : AppColors.forest,
        ),
      ),
    );
  }
}

// ── Avatar do líder ────────────────────────────────────────────────────────────

class _LiderAvatar extends StatelessWidget {
  const _LiderAvatar({required this.lider});
  final dynamic lider;

  @override
  Widget build(BuildContext context) {
    final foto = lider.foto as String?;
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.sand,
      backgroundImage: avatarImageProvider(foto),
      child: foto == null
          ? Text(
              lider.initials as String,
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
