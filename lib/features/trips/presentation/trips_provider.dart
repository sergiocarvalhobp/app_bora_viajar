import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

// ── Provider de viagens ────────────────────────────────────────────────────────

/// Busca viagens reativas aos filtros atuais.
/// Rebusca automaticamente quando os filtros mudam.
@riverpod
Future<List<TripModel>> tripsSearch(Ref ref) async {
  final filters = ref.watch(tripsFiltersNotifierProvider);
  final repo    = ref.watch(tripsRepositoryProvider);

  // Debounce suave — evita chamada a cada tecla no campo de busca
  if (filters.query != null && filters.query!.length == 1) {
    await Future.delayed(const Duration(milliseconds: 400));
    // Cancela se o query mudou durante o debounce
    ref.keepAlive();
  }

  return repo.listar(filters);
}
