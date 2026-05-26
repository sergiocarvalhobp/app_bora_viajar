import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/router/trip_navigation.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_avatar.dart';
import '../../../core/ui/destination_image_resolver.dart';
import '../../../core/ui/interactive_organizer_rating.dart';
import '../../../core/ui/bv_forest_app_bar.dart';
import '../../../core/ui/forest_hero_background.dart';
import '../../../core/ui/organizer_rating_stars.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../profile/presentation/user_profile_preview_sheet.dart';
import '../domain/organizer_trip_review.dart';
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

class _TripDetailsBody extends ConsumerStatefulWidget {
  const _TripDetailsBody({required this.trip});
  final TripModel trip;

  @override
  ConsumerState<_TripDetailsBody> createState() => _TripDetailsBodyState();
}

class _TripDetailsBodyState extends ConsumerState<_TripDetailsBody> {
  late int _selectedStars;
  late final TextEditingController _testimonyController;
  final _snackMessengerKey = GlobalKey<ScaffoldMessengerState>();

  TripModel get trip => widget.trip;

  @override
  void initState() {
    super.initState();
    _selectedStars = widget.trip.myOrganizerRating ?? 0;
    _testimonyController =
        TextEditingController(text: widget.trip.myOrganizerTestimony ?? '');
  }

  @override
  void didUpdateWidget(covariant _TripDetailsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trip = ref.read(tripDetailsProvider(widget.trip.id)).value ?? widget.trip;
    if (trip.myOrganizerRating != null) {
      _selectedStars = trip.myOrganizerRating!;
    }
    if (trip.myOrganizerTestimony != null &&
        trip.myOrganizerTestimony != oldWidget.trip.myOrganizerTestimony) {
      _testimonyController.text = trip.myOrganizerTestimony!;
    }
  }

  @override
  void dispose() {
    _testimonyController.dispose();
    super.dispose();
  }


  bool _isConfirmedParticipant(TripModel trip, int? userId) {
    if (userId == null) return false;
    if (trip.isConfirmado) return true;
    final participants =
        ref.read(tripParticipantsProvider(widget.trip.id)).value;
    return participants?.any((p) => p.userId == userId && p.isConfirmado) ??
        false;
  }

  /// Formulário de avaliação (só antes de salvar).
  bool _reviewEditMode(TripModel trip, int? userId, bool isLider) {
    if (isLider || userId == null) return false;
    if (!trip.isTripEndedForReview) return false;
    if (trip.myOrganizerRating != null) return false;
    return trip.canRateOrganizerNow(userId);
  }

  /// Lista de testemunhos (organizador + participantes que já avaliaram).
  bool _showReviewsFeed(TripModel trip, int? userId, bool isLider) {
    if (!trip.isTripEndedForReview) return false;
    if (isLider) return true;
    if (userId == null) return false;
    if (trip.myOrganizerRating != null) return true;
    return _isConfirmedParticipant(trip, userId);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = _snackMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isError ? null : AppColors.forest,
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: isError ? 6 : 3),
      ),
    );
  }

  Future<void> _saveReview() async {
    if (_selectedStars < 1) {
      _showSnack('Escolha de 1 a 5 estrelas para avaliar a viagem.', isError: true);
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      _showSnack('Faça login para salvar a avaliação.', isError: true);
      return;
    }

    try {
      await ref.read(authRepositoryProvider).getMe();
      final freshTrip =
          await ref.refresh(tripDetailsProvider(widget.trip.id).future);
      if (!freshTrip.canRateOrganizerNow(currentUser.id)) {
        _showSnack(
          'Você ainda não pode avaliar esta viagem. Aguarde confirmação do '
          'organizador e o fim da viagem.',
          isError: true,
        );
        return;
      }

      await ref
          .read(organizerRatingNotifierProvider(widget.trip.id).notifier)
          .submit(_selectedStars, testemunho: _testimonyController.text);
      if (!mounted) return;
      _showSnack('Avaliação da viagem salva com sucesso!');
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppException
          ? e.message
          : ErrorHandler.handle(e).message;
      _showSnack(msg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripDetailsProvider(widget.trip.id)).value ??
        widget.trip;
    final currentUser   = ref.watch(currentUserProvider);
    final isLider       = ref.watch(isLiderDaViagemProvider(trip.id));
    final participationState = ref.watch(tripParticipationNotifierProvider(trip.id));
    final ratingState = ref.watch(organizerRatingNotifierProvider(trip.id));
    final reviewEditMode =
        _reviewEditMode(trip, currentUser?.id, isLider);
    final showReviewsFeed =
        _showReviewsFeed(trip, currentUser?.id, isLider);

    ref.listen(tripParticipationNotifierProvider(trip.id), (prev, next) {
      if (!mounted) return;
      if (next is AsyncError) {
        final msg = next.error is AppException
            ? (next.error as AppException).message
            : 'Não foi possível atualizar a participação.';
        _showSnack(msg, isError: true);
      } else if (prev is AsyncLoading && next is AsyncData) {
        _showSnack(
          isLider
              ? 'Participante confirmado!'
              : (trip.isParticipando
                  ? 'Interesse cancelado.'
                  : 'Interesse enviado! O organizador foi avisado.'),
        );
      }
    });

    return ScaffoldMessenger(
      key: _snackMessengerKey,
      child: Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── Hero expandido ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: _BackButton(),
            actions: [
              if (isLider) _EditButton(tripId: trip.id),
              _ShareButton(trip: trip),
            ],
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                const ForestHeroBackground(),
                FlexibleSpaceBar(
                  background: _HeroBackground(trip: trip),
                ),
              ],
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

                if (reviewEditMode) ...[
                  const _Divider(),
                  _TripReviewEditSection(
                    selectedStars: _selectedStars,
                    testimonyController: _testimonyController,
                    onStarsChanged: (s) => setState(() => _selectedStars = s),
                  ),
                ],

                if (showReviewsFeed) ...[
                  const _Divider(),
                  _TripOrganizerReviewsSection(tripId: trip.id),
                ],

                const _Divider(),

                // Participantes
                _ParticipantesSection(
                  tripId: trip.id,
                  isLider: isLider,
                  currentUserId: currentUser?.id,
                ),

                if (!isLider && trip.isAguardandoConfirmacao)
                  const _ChatPendingBanner(
                    message:
                        'O chat e a avaliação da viagem serão liberados quando o '
                        'organizador confirmar sua participação.',
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
        canAccessChat: trip.canAccessChat(currentUser?.id),
        participationState: participationState,
        reviewEditMode: reviewEditMode,
        reviewLoading: ratingState is AsyncLoading,
        canSaveReview: _selectedStars >= 1,
        onParticipar: () =>
            ref.read(tripParticipationNotifierProvider(trip.id).notifier)
               .participar(),
        onCancelar: () =>
            ref.read(tripParticipationNotifierProvider(trip.id).notifier)
               .cancelar(),
        onSaveReview: _saveReview,
        onChat: () => openTripChat(context, trip.id),
      ),
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
        const ForestHeroBackground(),
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            defaultDestinationAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackBackground(),
          ),
        ),
        const CustomPaint(painter: ForestDotPatternPainter()),

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
    final tt = context.appText;
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
              style: context.appText.titleLarge),
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
            label: trip.maxVagas != null ? 'Vagas confirmadas' : 'Participantes',
            value: trip.maxVagas != null
                ? '${trip.confirmadosOcupandoVaga} / ${trip.maxVagas}'
                : '${trip.pessoasNoGrupo} pessoas',
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
    final tt = context.appText;
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
    final tt = context.appText;
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

class _LiderSection extends ConsumerWidget {
  const _LiderSection({required this.lider});

  final UserModel lider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = context.appText;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Organizado por', style: tt.titleLarge),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  showUserProfilePreviewSheet(context, ref, user: lider),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
            children: [
              AppAvatar(
                foto: lider.foto,
                name: lider.name,
                initials: lider.initials,
                radius: 28,
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
              ),
            ),
          ),
          const SizedBox(height: 16),
          OrganizerRatingStars(
            rating: lider.organizerRating,
            ratingCount: lider.organizerRatingCount,
            filledLabelPrefix: 'Média das viagens que criou',
            emptyLabel: 'Ainda sem avaliações das viagens que criou',
          ),
        ],
      ),
    );
  }
}

class _TripOrganizerReviewsSection extends ConsumerWidget {
  const _TripOrganizerReviewsSection({required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripOrganizerReviewsProvider(tripId));
    final tt = context.appText;

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Não foi possível carregar as avaliações.',
          style: tt.bodySmall?.copyWith(color: AppColors.barkMuted),
        ),
      ),
      data: (page) {
        if (page.reviews.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Nenhuma avaliação publicada nesta viagem ainda.',
              style: tt.bodySmall?.copyWith(color: AppColors.barkMuted),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Avaliações da viagem',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (page.tripReviewCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${page.tripReviewCount} '
                  '${page.tripReviewCount == 1 ? 'participante avaliou' : 'participantes avaliaram'}',
                  style: tt.bodySmall?.copyWith(color: AppColors.barkMuted),
                ),
              ],
              const SizedBox(height: 16),
              ...page.reviews.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TripReviewCard(review: r),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TripReviewCard extends StatelessWidget {
  const _TripReviewCard({required this.review});

  final OrganizerTripReview review;

  @override
  Widget build(BuildContext context) {
    final tt = context.appText;
    final name = review.rater?.name ?? 'Participante';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: review.isMine ? AppColors.forest.withOpacity(0.35) : AppColors.sand,
          width: review.isMine ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                foto: review.rater?.foto,
                name: review.rater?.name,
                initials: review.rater?.initials,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.isMine ? 'Você' : name,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    OrganizerRatingStars(
                      rating: review.stars.toDouble(),
                      size: 16,
                      filledLabelPrefix: 'Nota',
                      emptyLabel: '',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.testemunho != null &&
              review.testemunho!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.testemunho!.trim(),
              style: tt.bodyMedium?.copyWith(color: AppColors.bark),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripReviewEditSection extends StatelessWidget {
  const _TripReviewEditSection({
    required this.selectedStars,
    required this.testimonyController,
    required this.onStarsChanged,
  });

  final int selectedStars;
  final TextEditingController testimonyController;
  final ValueChanged<int> onStarsChanged;

  @override
  Widget build(BuildContext context) {
    final tt = context.appText;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Avaliar a viagem',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Quem criou esta viagem recebe a nota. Só participantes confirmados '
            '(exceto o criador) podem avaliar após o fim da viagem.',
            style: tt.bodySmall?.copyWith(color: AppColors.barkMuted),
          ),
          const SizedBox(height: 14),
          InteractiveOrganizerRating(
            value: selectedStars,
            onChanged: onStarsChanged,
          ),
          const SizedBox(height: 16),
          Text('Testemunho da viagem',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: testimonyController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Como foi a viagem? Conte sobre o grupo e quem organizou…',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.sand),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.sand),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.forest, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aviso: chat após confirmação ─────────────────────────────────────────────

class _ChatPendingBanner extends StatelessWidget {
  const _ChatPendingBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.forest.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.forest.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 20, color: AppColors.forest),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.bark,
                ),
              ),
            ),
          ],
        ),
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
    final tripAsync = ref.watch(tripDetailsProvider(tripId));
    final podeConfirmarMais = tripAsync.maybeWhen(
      data: (t) => t.temVagasDisponiveis,
      orElse: () => false,
    );
    final tt = context.appText;

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
                    isLider
                        ? 'Ninguém demonstrou interesse ainda.'
                        : 'Nenhum participante ainda. Seja o primeiro!',
                    style: tt.bodyMedium?.copyWith(color: AppColors.barkMuted),
                  ),
                );
              }

              final pendentes =
                  isLider ? lista.where((p) => p.isInteressado).length : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pendentes > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.terra.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.terra.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          pendentes == 1
                              ? '1 pessoa aguardando sua confirmação'
                              : '$pendentes pessoas aguardando sua confirmação',
                          style: tt.bodySmall?.copyWith(
                            color: AppColors.terra,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ...lista.map((p) => _ParticipanteItem(
                  participante: p,
                  isLider: isLider,
                  isMe: p.userId == currentUserId,
                  onConfirmar: isLider && p.isInteressado && podeConfirmarMais
                      ? () => ref
                            .read(tripParticipationNotifierProvider(tripId).notifier)
                            .confirmarParticipante(p.id)
                      : null,
                  vagasLotadas: isLider && p.isInteressado && !podeConfirmarMais,
                )),
                ],
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
    this.vagasLotadas = false,
  });

  final ParticipantModel participante;
  final bool isLider;
  final bool isMe;
  final VoidCallback? onConfirmar;
  final bool vagasLotadas;

  @override
  Widget build(BuildContext context) {
    final tt = context.appText;
    final user = participante.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          AppAvatar(
            foto: user?.foto,
            name: user?.name,
            initials: user?.initials,
            radius: 22,
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
            )
          else if (vagasLotadas)
            Text(
              'Vagas lotadas',
              style: tt.labelSmall?.copyWith(
                color: AppColors.barkMuted,
                fontWeight: FontWeight.w600,
              ),
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
    required this.canAccessChat,
    required this.participationState,
    required this.reviewEditMode,
    required this.reviewLoading,
    required this.canSaveReview,
    required this.onParticipar,
    required this.onCancelar,
    required this.onSaveReview,
    required this.onChat,
  });

  final TripModel trip;
  final bool isLider;
  final bool canAccessChat;
  final AsyncValue<void> participationState;
  final bool reviewEditMode;
  final bool reviewLoading;
  final bool canSaveReview;
  final VoidCallback onParticipar;
  final VoidCallback onCancelar;
  final VoidCallback onSaveReview;
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
          // Chat: líder ou participante confirmado
          if (canAccessChat) ...[
            _ChatButton(onTap: onChat),
            const SizedBox(width: 12),
          ],

          // Botão principal
          Expanded(
            child: _MainActionButton(
              trip: trip,
              isLider: isLider,
              isLoading: isLoading,
              reviewEditMode: reviewEditMode,
              reviewLoading: reviewLoading,
              canSaveReview: canSaveReview,
              onParticipar: onParticipar,
              onCancelar: onCancelar,
              onSaveReview: onSaveReview,
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
    required this.reviewEditMode,
    required this.reviewLoading,
    required this.canSaveReview,
    required this.onParticipar,
    required this.onCancelar,
    required this.onSaveReview,
  });

  final TripModel trip;
  final bool isLider;
  final bool isLoading;
  final bool reviewEditMode;
  final bool reviewLoading;
  final bool canSaveReview;
  final VoidCallback onParticipar;
  final VoidCallback onCancelar;
  final VoidCallback onSaveReview;

  @override
  Widget build(BuildContext context) {
    if (reviewEditMode) {
      return ElevatedButton.icon(
        onPressed: reviewLoading || !canSaveReview ? null : onSaveReview,
        icon: reviewLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined, size: 20),
        label: const Text('Salvar avaliação da viagem'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    // Líder — confirma interessados na lista acima
    if (isLider) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.manage_accounts_outlined, size: 18),
        label: const Text('Confirme interessados na lista acima'),
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

    // Viagem encerrada — não aceita novos interessados
    if (trip.isTripFinished) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sand,
          foregroundColor: AppColors.barkMuted,
          minimumSize: const Size.fromHeight(52),
        ),
        child: const Text('Viagem encerrada'),
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
    final confirmados = trip.confirmadosOcupandoVaga;
    final max = trip.maxVagas!;
    final pct = max > 0 ? confirmados / max : 0.0;
    final color = pct >= 1.0
        ? AppColors.error
        : pct >= 0.8
            ? AppColors.terra
            : AppColors.forest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$confirmados/$max',
          style: TextStyle(
            fontFamily: 'DMSerifDisplay',
            fontSize: 28,
            color: color,
          ),
        ),
        Text(
          'vagas confirmadas',
          style: context.appText.labelSmall?.copyWith(color: AppColors.barkMuted),
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
      appBar: const BvForestAppBar(title: 'Viagem'),
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
                  style: context.appText.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: context.appText.bodySmall?.copyWith(color: AppColors.barkMuted),
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
