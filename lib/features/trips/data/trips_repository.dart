import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/network/api_client.dart';
import '../domain/participant_model.dart';
import '../domain/trip_model.dart';

part 'trips_repository.g.dart';

@riverpod
TripsRepository tripsRepository(Ref ref) {
  return TripsRepository(dio: ref.watch(apiClientProvider));
}

class TripsRepository {
  TripsRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  // ── Listagem ───────────────────────────────────────────────────────────────

  Future<List<TripModel>> listar(TripFilters filters) async {
    try {
      final response = await _dio.get(
        trpcUrl('viagens.listar'),
        queryParameters: {'input': _encodeInput(filters.toQueryParams())},
      );
      final data = _extractTrpcData(response.data);
      if (data is! List) return [];
      return data
          .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Retorna as viagens do usuário autenticado
  Future<List<TripModel>> minhasViagens() async {
    try {
      final response = await _dio.get(trpcUrl('viagens.minhasViagens'));
      final data = _extractTrpcData(response.data);
      if (data is! List) return [];
      return data
          .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ── Detalhes ───────────────────────────────────────────────────────────────

  Future<TripModel> buscarPorId(int id) async {
    try {
      final response = await _dio.get(
        trpcUrl('viagens.buscarPorId'),
        queryParameters: {'input': _encodeInput({'id': id})},
      );
      final data = _extractTrpcData(response.data);
      return TripModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Cria uma nova viagem
  Future<TripModel> criar({
    required String destino,
    String? estado,
    String? cidade,
    String? atrativo,
    required String descricao,
    required String tipo,
    required DateTime dataInicio,
    required DateTime dataFim,
    int? maxVagas,
  }) async {
    try {
      final data = {
        'destino': destino,
        if (estado != null) 'estado': estado,
        if (cidade != null) 'cidade': cidade,
        if (atrativo != null) 'atrativo': atrativo,
        'descricao': descricao,
        'tipo': tipo,
        'dataInicio': dataInicio.toIso8601String(),
        'dataFim': dataFim.toIso8601String(),
        if (maxVagas != null) 'maxVagas': maxVagas,
      };
      final response = await _dio.post(
        trpcUrl('viagens.criar'),
        data: _encodeInput(data),
      );
      final responseData = _extractTrpcData(response.data);
      return TripModel.fromJson(responseData as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ── Participantes ──────────────────────────────────────────────────────────

  Future<List<ParticipantModel>> listarParticipantes(int viagemId) async {
    try {
      final response = await _dio.get(
        trpcUrl('viagens.listarParticipantes'),
        queryParameters: {'input': _encodeInput({'viagemId': viagemId})},
      );
      final data = _extractTrpcData(response.data);
      if (data is! List) return [];
      return data
          .map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> participar(int viagemId) async {
    try {
      await _dio.post(
        trpcUrl('viagens.participar'),
        data: {'0': {'json': {'viagemId': viagemId}}},
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> cancelarParticipacao(int viagemId) async {
    try {
      await _dio.post(
        trpcUrl('viagens.cancelarParticipacao'),
        data: {'0': {'json': {'viagemId': viagemId}}},
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Líder confirma ou recusa um participante.
  Future<void> atualizarStatusParticipante(
      int viagemId, int participanteId, String status) async {
    try {
      await _dio.post(
        trpcUrl('viagens.atualizarParticipante'),
        data: {
          '0': {
            'json': {
              'viagemId': viagemId,
              'participanteId': participanteId,
              'status': status,
            }
          }
        },
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _encodeInput(Map<String, dynamic> params) {
    final buffer = StringBuffer('{"json":{');
    var first = true;
    for (final entry in params.entries) {
      if (!first) buffer.write(',');
      final v = entry.value;
      if (v is String) {
        buffer.write('"${entry.key}":"$v"');
      } else {
        buffer.write('"${entry.key}":$v');
      }
      first = false;
    }
    buffer.write('}}');
    return buffer.toString();
  }

  static dynamic _extractTrpcData(dynamic raw) {
    if (raw is List) raw = raw.first;
    if (raw is Map<String, dynamic>) {
      final result = raw['result'];
      if (result is Map<String, dynamic>) {
        final data = result['data'];
        if (data is Map<String, dynamic>) return data['json'] ?? data;
        return data;
      }
    }
    return raw;
  }
}
