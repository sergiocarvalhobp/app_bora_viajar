import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/avatar_image_provider.dart';
import '../../../core/ui/destination_image_resolver.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/participant_model.dart';
import '../domain/trip_model.dart';
import '../presentation/trip_details_provider.dart';

class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({super.key, required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailsProvider(tripId));

    return tripAsync.when(
      loading: () => const _LoadingScaffold(),
      error:   (e, _) => _ErrorScaffold(message: e.toString()),
      data:    (trip) => _TripDetailsBody(trip: trip),
    );
  }
}

// ── Body principal ─────────────────────────────────────────────────────────────

class _TripDetailsBody extends ConsumerWidget {
  const _TripDetailsBody({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser   = ref.watch(currentUserProvider);
    final isLider       = ref.watch(isLiderDaViagemProvider(trip.id));
    final participationState = ref.watch(tripParticipationNotifierProvider(trip.id));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── Hero expandido ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.forest,
            elevation: 0,
            leading: _BackButton(),
            actions: [
              if (isLider) _EditButton(tripId: trip.id),
              _ShareButton(trip: trip),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroBackground(trip: trip),
            ),
          ),

          // ── Conteúdo scrollável ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                _TripHeader(trip: trip),

                const _Divider(),

                // Informações
                _InfoSection(trip: trip),

                const _Divider(),

                // Descrição
                _DescricaoSection(trip: trip),

                const _Divider(),

                // Líder
                if (trip.lider != null)
                  _LiderSection(lider: trip.lider!),

                const _Divider(),

                // Participantes
                _ParticipantesSection(
                  tripId: trip.id,
                  isLider: isLider,
                  currentUserId: currentUser?.id,
                ),

                // Espaço para o botão fixo no fundo
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),

      // ── Botão de ação fixo no fundo ────────────────────────────────────
      bottomNavigationBar: _BottomAction(
        trip: trip,
        isLider: isLider,
        currentUser: currentUser,
        participationState: participationState,
        onParticipar: () =>
            ref.read(tripParticipationNotifierProvider(trip.id).notifier)
               .participar(),
        onCancelar: () =>
            ref.read(tripParticipationNotifierProvider(trip.id).notifier)
               .cancelar(),
        onChat: () => context.push('/trips/${trip.id}/chat'),
      ),
    );
  }
}

// ── Hero background ────────────────────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.trip});
  final TripModel trip;

  static const _gradients = {
    'amazônia':  [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
    'pantanal':  [Color(0xFF4A7C59), Color(0xFF2D5A3D)],
    'nordeste':  [Color(0xFFC4622D), Color(0xFF8B3A14)],
    'cerrado':   [Color(0xFF8B6914), Color(0xFF5C4209)],
    'sul':       [Color(0xFF2D6A8F), Color(0xFF1A3F5C)],
    'litoral':   [Color(0xFF1A6B8F), Color(0xFF0D4A6B)],
    'serra':     [Color(0xFF5C7A3E), Color(0xFF3A5226)],
  };

  List<Color> _gradient() {
    final lower = trip.destino.toLowerCase();
    for (final entry in _gradients.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return [AppColors.forest, AppColors.forestDk];
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = resolveDestinationAsset(
      destino: trip.destino,
      estado: trip.estado,
      cidade: trip.cidade,
      atrativo: trip.atrativo,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (assetPath != null)
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackBackground(),
          )
        else
          _fallbackBackground(),

        if (assetPath != null)
          Container(color: Colors.black.withOpacity(0.22)),

        // Overlay escuro no fundo para legibilidade do título
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity( 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Destino centralizado no hero
        Positioned(
          bottom: 56, left: 20, right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.destino,
                style: const TextStyle(
                  fontFamily: 'DMSerifDisplay',
                  fontSize: 32,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                  height: 1.1,
                ),
              ),
              if (trip.atrativo != null) ...[
                const SizedBox(height: 4),
                Text(
                  trip.atrativo!,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: Colors.white.withOpacity( 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
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
          colors: _gradient(),
        ),
      ),
    );
  }
}

// ── Cabeçalho da viagem ────────────────────────────────────────────────────────

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo badge
                _TipoBadge(tipo: trip.tipo),
                const SizedBox(height: 10),
                // Período
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 15, color: AppColors.barkMuted),
                    const SizedBox(width: 6),
                    Text(
                      trip.periodoFormatado,
                      style: tt.bodyMedium?.copyWith(
                        color: AppColors.barkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '  ·  ${trip.duracaoDias} dia${trip.duracaoDias > 1 ? 's' : ''}',
                      style: tt.bodySmall?.copyWith(color: AppColors.barkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vagas
          if (trip.maxVagas != null)
            _VagasIndicator(trip: trip),
        ],
      ),
    );
  }
}

// ── Seção de informações ───────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informações',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),

          if (trip.estado != null)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Estado',
              value: trip.estado!,
            ),

          if (trip.cidade != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.location_city_outlined,
              label: 'Cidade',
              value: trip.cidade!,
            ),
          ],

          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.people_outline,
            label: 'Participantes',
            value: trip.maxVagas != null
                ? '${trip.participantesCount} / ${trip.maxVagas}'
                : '${trip.participantesCount} pessoas',
          ),

          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.event_available_outlined,
            label: 'Duração',
            value: '${trip.duracaoDias} dia${trip.duracaoDias > 1 ? 's' : ''}',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.sand,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.forest),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: tt.labelSmall?.copyWith(color: AppColors.barkMuted)),
            Text(value,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ── Seção de descrição ─────────────────────────────────────────────────────────

class _DescricaoSection extends StatefulWidget {
  const _DescricaoSection({required this.trip});
  final TripModel trip;

  @override
  State<_DescricaoSection> createState() => _DescricaoSectionState();
}

class _DescricaoSectionState extends State<_DescricaoSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final descricao = widget.trip.descricao;
    final isLonga = descricao.length > 200;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sobre a viagem', style: tt.titleLarge),
          const SizedBox(height: 10),

          AnimatedCrossFade(
            firstChild: Text(
              descricao,
              style: tt.bodyMedium?.copyWith(
                color: AppColors.barkMuted,
                height: 1.6,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              descricao,
              style: tt.bodyMedium?.copyWith(
                color: AppColors.barkMuted,
                height: 1.6,
              ),
            ),
            crossFadeState: _expanded || !isLonga
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          if (isLonga) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver mais',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Seção do líder ─────────────────────────────────────────────────────────────

class _LiderSection extends StatelessWidget {
  const _LiderSection({required this.lider});
  final UserModel lider;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Organizado por', style: tt.titleLarge),
          const SizedBox(height: 14),
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.sand,
                backgroundImage: lider.foto != null
                    ? CachedNetworkImageProvider(lider.foto!)
                    : null,
                child: lider.foto == null
                    ? Text(
                        lider.initials,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.bark,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          lider.name,
                          style: tt.titleMedium,
                        ),
                        const SizedBox(width: 6),
                        _BadgeLider(),
                      ],
                    ),
                    if (lider.bio != null && lider.bio!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        lider.bio!,
                        style: tt.bodySmall?.copyWith(
                            color: AppColors.barkMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (lider.estado != null || lider.cidade != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.barkMuted),
                          const SizedBox(width: 3),
                          Text(
                            [lider.cidade, lider.estado]
                                .whereType<String>()
                                .join(', '),
                            style: tt.labelSmall?.copyWith(
                                color: AppColors.barkMuted),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Seção de participantes ─────────────────────────────────────────────────────

class _ParticipantesSection extends ConsumerWidget {
  const _ParticipantesSection({
    required this.tripId,
    required this.isLider,
    required this.currentUserId,
  });

  final int tripId;
  final bool isLider;
  final int? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantesAsync = ref.watch(tripParticipantsProvider(tripId));
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          participantesAsync.when(
            loading: () => Text('Participantes', style: tt.titleLarge),
            error: (_, __) => Text('Participantes', style: tt.titleLarge),
            data: (lista) => Row(
              children: [
                Text('Participantes', style: tt.titleLarge),
                const SizedBox(width: 8),
                _CountBadge(count: lista.length),
              ],
            ),
          ),

          const SizedBox(height: 14),

          participantesAsync.when(
            loading: () => const _ParticipantesShimmer(),
            error: (e, _) => Text('Erro ao carregar: $e',
                style: tt.bodySmall?.copyWith(color: AppColors.barkMuted)),
            data: (lista) {
              if (lista.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nenhum participante ainda. Seja o primeiro!',
                    style: tt.bodyMedium?.copyWith(color: AppColors.barkMuted),
                  ),
                );
              }

              return Column(
                children: lista.map((p) => _ParticipanteItem(
                  participante: p,
                  isLider: isLider,
                  isMe: p.userId == currentUserId,
                  onConfirmar: isLider && p.isInteressado
                      ? () => ref
                            .read(tripParticipationNotifierProvider(tripId).notifier)
                            .confirmarParticipante(p.id)
                      : null,
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ParticipanteItem extends StatelessWidget {
  const _ParticipanteItem({
    required this.participante,
    required this.isLider,
    required this.isMe,
    this.onConfirmar,
  });

  final ParticipantModel participante;
  final bool isLider;
  final bool isMe;
  final VoidCallback? onConfirmar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final user = participante.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.sand,
            backgroundImage: avatarImageProvider(user?.foto),
            child: user?.foto == null
                ? Text(
                    user?.initials ?? '?',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bark,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Nome + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user?.name ?? 'Viajante',
                      style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text('(você)',
                          style: tt.labelSmall?.copyWith(
                              color: AppColors.barkMuted)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                _StatusBadge(status: participante.status),
              ],
            ),
          ),

          // Botão confirmar (só para o líder)
          if (onConfirmar != null)
            TextButton(
              onPressed: onConfirmar,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.forest,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.forest),
                ),
              ),
              child: const Text('Confirmar',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ── Botão de ação fixo no fundo ────────────────────────────────────────────────

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.trip,
    required this.isLider,
    required this.currentUser,
    required this.participationState,
    required this.onParticipar,
    required this.onCancelar,
    required this.onChat,
  });

  final TripModel trip;
  final bool isLider;
  final UserModel? currentUser;
  final AsyncValue<void> participationState;
  final VoidCallback onParticipar;
  final VoidCallback onCancelar;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final isLoading = participationState is AsyncLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.sand)),
        boxShadow: [
          BoxShadow(
            color: AppColors.bark.withOpacity( 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botão de chat — sempre visível para participantes e líder
          if (isLider || trip.isParticipando) ...[
            _ChatButton(onTap: onChat),
            const SizedBox(width: 12),
          ],

          // Botão principal
          Expanded(
            child: _MainActionButton(
              trip: trip,
              isLider: isLider,
              isLoading: isLoading,
              onParticipar: onParticipar,
              onCancelar: onCancelar,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  const _MainActionButton({
    required this.trip,
    required this.isLider,
    required this.isLoading,
    required this.onParticipar,
    required this.onCancelar,
  });

  final TripModel trip;
  final bool isLider;
  final bool isLoading;
  final VoidCallback onParticipar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    // Líder vê resumo de candidatos
    if (isLider) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.manage_accounts_outlined, size: 18),
        label: const Text('Você é o organizador'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sand,
          foregroundColor: AppColors.bark,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
        ),
      );
    }

    // Já participa — botão cancelar
    if (trip.isParticipando) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onCancelar,
        icon: isLoading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.close_rounded, size: 18),
        label: Text(
            trip.myStatus == 'confirmado' ? 'Confirmado ✓' : 'Cancelar interesse'),
        style: OutlinedButton.styleFrom(
          foregroundColor: trip.myStatus == 'confirmado'
              ? AppColors.forest
              : AppColors.terra,
          side: BorderSide(
            color: trip.myStatus == 'confirmado'
                ? AppColors.forest
                : AppColors.terra,
          ),
          minimumSize: const Size.fromHeight(52),
        ),
      );
    }

    // Sem vagas
    if (!trip.temVagasDisponiveis) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sand,
          foregroundColor: AppColors.barkMuted,
          minimumSize: const Size.fromHeight(52),
        ),
        child: const Text('Viagem lotada'),
      );
    }

    // Ação principal: participar
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onParticipar,
      icon: isLoading
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Icon(Icons.explore_outlined, size: 18),
      label: const Text('Quero participar'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.terra,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppColors.forest.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.forest.withOpacity( 0.3)),
        ),
        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: AppColors.forest,
          size: 22,
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity( 0.3),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity( 0.3),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: const Icon(Icons.edit_outlined,
            color: Colors.white, size: 16),
      ),
      onPressed: () {
        // TODO: context.push('/trips/$tripId/edit')
      },
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          // TODO: Share.share('Olha essa viagem para ${trip.destino}!')
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity( 0.3),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.share_outlined,
              color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _TipoBadge extends StatelessWidget {
  const _TipoBadge({required this.tipo});
  final TipoViagem tipo;

  @override
  Widget build(BuildContext context) {
    final isLider = tipo == TipoViagem.lider;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
            isLider ? Icons.star_rounded : Icons.explore_rounded,
            size: 13,
            color: isLider ? AppColors.forest : AppColors.terra,
          ),
          const SizedBox(width: 5),
          Text(
            tipo.label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isLider ? AppColors.forestDk : AppColors.terra,
            ),
          ),
        ],
      ),
    );
  }
}

class _VagasIndicator extends StatelessWidget {
  const _VagasIndicator({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final vagas = trip.vagasDisponiveis!;
    final pct   = vagas / trip.maxVagas!;
    final color = pct < 0.2
        ? AppColors.error
        : pct < 0.5
            ? AppColors.terra
            : AppColors.forest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$vagas',
          style: TextStyle(
            fontFamily: 'DMSerifDisplay',
            fontSize: 28,
            color: color,
          ),
        ),
        Text(
          'vagas',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.barkMuted),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final StatusParticipacao status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      StatusParticipacao.confirmado => (
          'Confirmado',
          const Color(0xFFDCFCE7),
          AppColors.forest,
        ),
      StatusParticipacao.interessado => (
          'Interessado',
          const Color(0xFFFEF9C3),
          const Color(0xFF854D0E),
        ),
      StatusParticipacao.recusado => (
          'Recusado',
          const Color(0xFFFEF2F2),
          AppColors.error,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _BadgeLider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.forest.withOpacity( 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Text(
        'Líder',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.forestDk,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.bark,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(color: AppColors.sand, height: 1),
    );
  }
}

// ── Telas de loading e erro ────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viagem')),
      backgroundColor: AppColors.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 64, color: AppColors.barkMuted),
              const SizedBox(height: 16),
              Text('Não foi possível carregar a viagem',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.barkMuted),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantesShimmer extends StatelessWidget {
  const _ParticipantesShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const CircleAvatar(
                  radius: 22, backgroundColor: AppColors.sand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14, width: 120,
                        decoration: BoxDecoration(
                            color: AppColors.sand,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(
                        height: 10, width: 60,
                        decoration: BoxDecoration(
                            color: AppColors.sand,
                            borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
