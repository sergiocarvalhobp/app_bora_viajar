import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/ui/avatar_image_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/trip_model.dart';
import '../presentation/trips_provider.dart';
import '../widgets/trip_card.dart';

class SearchTripsScreen extends ConsumerStatefulWidget {
  const SearchTripsScreen({super.key});

  @override
  ConsumerState<SearchTripsScreen> createState() => _SearchTripsScreenState();
}

class _SearchTripsScreenState extends ConsumerState<SearchTripsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 280) return;
    ref.read(tripsSearchProvider.notifier).loadMore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters      = ref.watch(tripsFiltersNotifierProvider);
    final tripsAsync   = ref.watch(tripsSearchProvider);
    final filtersNotif = ref.read(tripsFiltersNotifierProvider.notifier);
    final user         = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── App Bar expansível ──────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.forest,
            expandedHeight: 188,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: const Text(
                'Explorar viagens',
                style: TextStyle(
                  fontFamily: 'DMSerifDisplay',
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.forest),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 10,
                    left: 16,
                    right: 16,
                    child: _LoggedHeaderRow(user: user),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 54,
                    left: 20,
                    child: Text(
                      'Encontre companheiros pelo Brasil',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: Colors.white.withOpacity( 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Barra de busca + filtros ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  // Campo de busca
                  _SearchField(
                    controller: _searchController,
                    onChanged: filtersNotif.setQuery,
                    onClear: () {
                      _searchController.clear();
                      filtersNotif.setQuery(null);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Chips de filtro horizontal
                  _FilterChipsRow(
                    filters: filters,
                    onTipoChanged: filtersNotif.setTipo,
                    onFiltrosAvancados: () => _showFiltrosSheet(context, ref),
                    onClearFiltro: filtersNotif.limparFiltro,
                  ),
                ],
              ),
            ),
          ),

          // ── Resultados ──────────────────────────────────────────────────
          tripsAsync.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const _TripCardSkeleton(),
                  childCount: 4,
                ),
              ),
            ),

            error: (err, _) => SliverFillRemaining(
              child: _ErrorState(
                message: err.toString(),
                onRetry: () => ref.invalidate(tripsSearchProvider),
              ),
            ),

            data: (searchState) {
              final trips = searchState.trips;
              if (trips.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    hasFilters: !filters.isEmpty,
                    onClearFilters: filtersNotif.limparTudo,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= trips.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TripCard(
                          trip: trips[i],
                          showActions: true,
                          onTap: () => context.push('/trips/${trips[i].id}'),
                        ),
                      );
                    },
                    childCount:
                        trips.length + (searchState.isLoadingMore ? 1 : 0),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFiltrosSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltrosSheet(ref: ref),
    );
  }
}

class _LoggedHeaderRow extends StatelessWidget {
  const _LoggedHeaderRow({required this.user});
  final dynamic user;

  String _firstName(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'Viajante';
    return n.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName(user?.name as String?);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Olá, $firstName',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 21,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: () => context.go('/notifications'),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 24,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.15),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.go('/profile/edit'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                key: ValueKey(user?.foto ?? 'no-avatar'),
                radius: 19,
                backgroundColor: Colors.white24,
                backgroundImage: avatarImageProvider(user?.foto as String?),
                child: (user?.foto as String?) == null
                    ? Text(
                        _firstName(user?.name as String?).substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -1,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.terra,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.forest, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Campo de busca ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 15,
        color: AppColors.bark,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar destino, estado...',
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.barkMuted, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.barkMuted, size: 18),
                onPressed: onClear,
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }
}

// ── Chips de filtro ────────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.filters,
    required this.onTipoChanged,
    required this.onFiltrosAvancados,
    required this.onClearFiltro,
  });

  final TripFilters filters;
  final ValueChanged<TipoViagem?> onTipoChanged;
  final VoidCallback onFiltrosAvancados;
  final ValueChanged<String> onClearFiltro;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filtros avançados
          _FilterChip(
            label: 'Filtros',
            icon: Icons.tune_rounded,
            isActive: !filters.isEmpty,
            onTap: onFiltrosAvancados,
          ),

          const SizedBox(width: 8),

          // Tipo: Líder
          _FilterChip(
            label: 'Líder de grupo',
            icon: Icons.star_outline_rounded,
            isActive: filters.tipo == TipoViagem.lider,
            onTap: () => onTipoChanged(
              filters.tipo == TipoViagem.lider ? null : TipoViagem.lider,
            ),
          ),

          const SizedBox(width: 8),

          // Tipo: Viajante
          _FilterChip(
            label: 'Procuro grupo',
            icon: Icons.explore_outlined,
            isActive: filters.tipo == TipoViagem.viajante,
            onTap: () => onTipoChanged(
              filters.tipo == TipoViagem.viajante ? null : TipoViagem.viajante,
            ),
          ),

          // Chip de estado (quando selecionado)
          if (filters.estado != null) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: filters.estado!,
              icon: Icons.location_on_outlined,
              isActive: true,
              onRemove: () => onClearFiltro('estado'),
              onTap: () {},
            ),
          ],

          // Chip de datas (quando selecionadas)
          if (filters.dataInicio != null) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Com datas',
              icon: Icons.calendar_today_outlined,
              isActive: true,
              onRemove: () {
                onClearFiltro('dataInicio');
                onClearFiltro('dataFim');
              },
              onTap: () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: onRemove != null ? 10 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? AppColors.forest : AppColors.sand,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppColors.barkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.bark,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: isActive ? Colors.white70 : AppColors.barkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet de filtros avançados ─────────────────────────────────────────

class _FiltrosSheet extends ConsumerWidget {
  const _FiltrosSheet({required this.ref});
  final WidgetRef ref;

  static const _estados = [
    'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR',
    'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters  = ref.watch(tripsFiltersNotifierProvider);
    final notifier = ref.read(tripsFiltersNotifierProvider.notifier);
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 20, 20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filtros', style: tt.headlineSmall),
              TextButton(
                onPressed: notifier.limparTudo,
                child: const Text('Limpar tudo'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Estado
          Text('Estado', style: tt.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _estados.map((uf) {
              final selected = filters.estado == uf;
              return GestureDetector(
                onTap: () => notifier.setEstado(selected ? null : uf),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.forest : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.forest : AppColors.sand,
                    ),
                  ),
                  child: Text(
                    uf,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.bark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Apenas com vagas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apenas com vagas', style: tt.titleMedium),
                  Text(
                    'Ocultar viagens lotadas',
                    style: tt.bodySmall?.copyWith(color: AppColors.barkMuted),
                  ),
                ],
              ),
              Switch(
                value: filters.apenasComVagas,
                onChanged: (_) => notifier.toggleApenasComVagas(),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.forest;
                  }
                  return null;
                }),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Botão aplicar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ver resultados'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estados vazios ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined,
                size: 64, color: AppColors.sand),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'Nenhuma viagem com esses filtros'
                  : 'Nenhuma viagem encontrada',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Tente remover alguns filtros para ver mais resultados.'
                  : 'Seja o primeiro a criar uma viagem!',
              style: tt.bodyMedium?.copyWith(color: AppColors.barkMuted),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text('Limpar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 64, color: AppColors.barkMuted),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar as viagens',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loader ────────────────────────────────────────────────────────────

class _TripCardSkeleton extends StatelessWidget {
  const _TripCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Shimmer.fromColors(
        baseColor: AppColors.sand,
        highlightColor: Colors.white,
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
