import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/trips_repository.dart';
import '../domain/trip_model.dart';
import '../domain/participant_model.dart';

part 'trip_details_provider.g.dart';

// ── Detalhes da viagem ─────────────────────────────────────────────────────────

@riverpod
Future<TripModel> tripDetails(Ref ref, int tripId) async {
  final repo = ref.watch(tripsRepositoryProvider);
  return repo.buscarPorId(tripId);
}

// ── Participantes da viagem ────────────────────────────────────────────────────

@riverpod
Future<List<ParticipantModel>> tripParticipants(Ref ref, int tripId) async {
  final repo = ref.watch(tripsRepositoryProvider);
  return repo.listarParticipantes(tripId);
}

// ── Ação de participar / cancelar ─────────────────────────────────────────────

@riverpod
class TripParticipationNotifier extends _$TripParticipationNotifier {
  @override
  AsyncValue<void> build(int tripId) => const AsyncData(null);

  Future<void> participar() async {
    state = const AsyncLoading();
    try {
      await ref.read(tripsRepositoryProvider).participar(tripId);
      state = const AsyncData(null);
      // Invalida detalhes e participantes para recarregar
      ref.invalidate(tripDetailsProvider(tripId));
      ref.invalidate(tripParticipantsProvider(tripId));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> cancelar() async {
    state = const AsyncLoading();
    try {
      await ref.read(tripsRepositoryProvider).cancelarParticipacao(tripId);
      state = const AsyncData(null);
      ref.invalidate(tripDetailsProvider(tripId));
      ref.invalidate(tripParticipantsProvider(tripId));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> confirmarParticipante(int participanteId) async {
    state = const AsyncLoading();
    try {
      await ref.read(tripsRepositoryProvider)
          .atualizarStatusParticipante(tripId, participanteId, 'confirmado');
      state = const AsyncData(null);
      ref.invalidate(tripParticipantsProvider(tripId));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ── Selector: o usuário atual é o líder desta viagem? ─────────────────────────

@riverpod
bool isLiderDaViagem(Ref ref, int tripId) {
  final user    = ref.watch(currentUserProvider);
  final tripAsync = ref.watch(tripDetailsProvider(tripId));
  return tripAsync.maybeWhen(
    data: (trip) => user?.id == trip.liderId,
    orElse: () => false,
  );
}
