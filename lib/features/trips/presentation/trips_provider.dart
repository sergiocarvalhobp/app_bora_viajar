import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/trips_repository.dart';
import '../domain/trip_model.dart';

part 'trips_provider.g.dart';

// ── Provider de filtros ────────────────────────────────────────────────────────

@riverpod
class TripsFiltersNotifier extends _$TripsFiltersNotifier {
  @override
  TripFilters build() => const TripFilters();

  void setQuery(String? q) =>
      state = state.copyWith(query: q?.isEmpty == true ? null : q);

  void setTipo(TipoViagem? tipo) => state = state.copyWith(tipo: tipo);

  void setEstado(String? estado) => state = state.copyWith(estado: estado);

  void setDatas(DateTime? inicio, DateTime? fim) =>
      state = state.copyWith(dataInicio: inicio, dataFim: fim);

  void toggleApenasComVagas() =>
      state = state.copyWith(apenasComVagas: !state.apenasComVagas);

  void limparFiltro(String campo) => state = state.clearFiltro(campo);

  void limparTudo() => state = const TripFilters();
}

// ── Estado da lista paginada (home) ─────────────────────────────────────────────

class TripsSearchState {
  const TripsSearchState({
    this.trips = const [],
    this.serverOffset = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<TripModel> trips;
  final int serverOffset;
  final bool hasMore;
  final bool isLoadingMore;

  TripsSearchState copyWith({
    List<TripModel>? trips,
    int? serverOffset,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return TripsSearchState(
      trips: trips ?? this.trips,
      serverOffset: serverOffset ?? this.serverOffset,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

// ── Provider de viagens (paginação) ───────────────────────────────────────────

/// Primeira página: 10 viagens. Scroll no fim: +5 por vez.
@riverpod
class TripsSearch extends _$TripsSearch {
  static const _initialLimit = 10;
  static const _loadMoreLimit = 5;

  @override
  Future<TripsSearchState> build() async {
    final authState = ref.watch(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return const TripsSearchState();
    }

    final filters = ref.watch(tripsFiltersNotifierProvider).copyWith(
      apenasAtivas: true,
    );
    final repo = ref.watch(tripsRepositoryProvider);

    if (filters.query != null && filters.query!.length == 1) {
      await Future.delayed(const Duration(milliseconds: 400));
    }

    final page = await repo.listarPaginado(
      filters: filters,
      offset: 0,
      limit: _initialLimit,
    );

    final active = page.items.where((t) => t.isValidForHome).toList();

    return TripsSearchState(
      trips: active,
      serverOffset: page.fetchedCount,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final filters = ref.read(tripsFiltersNotifierProvider).copyWith(
        apenasAtivas: true,
      );
      final repo = ref.read(tripsRepositoryProvider);
      final page = await repo.listarPaginado(
        filters: filters,
        offset: current.serverOffset,
        limit: _loadMoreLimit,
      );

      final more = page.items.where((t) => t.isValidForHome).toList();
      state = AsyncData(
        current.copyWith(
          trips: [...current.trips, ...more],
          serverOffset: current.serverOffset + page.fetchedCount,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}
