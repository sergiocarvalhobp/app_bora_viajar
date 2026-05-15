import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app_constants.dart';
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

  static const _p = AppConstants.restApiPrefix;

  static void _throwIfHttpError(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  Future<List<TripModel>> listar(TripFilters filters) async {
    try {
      List<dynamic> rawList;
      if (filters.isEmpty) {
        final response = await _dio.get('$_p/trips');
        _throwIfHttpError(response);
        rawList = response.data as List<dynamic>? ?? [];
      } else {
        final qp = <String, dynamic>{};
        if (filters.query != null && filters.query!.isNotEmpty) {
          qp['destino'] = filters.query;
        }
        if (filters.estado != null) qp['estado'] = filters.estado;
        if (filters.dataInicio != null) {
          qp['dataInicio'] = filters.dataInicio!.toIso8601String().split('T').first;
        }
        if (filters.dataFim != null) {
          qp['dataFim'] = filters.dataFim!.toIso8601String().split('T').first;
        }
        final response = await _dio.get('$_p/trips/filter', queryParameters: qp);
        _throwIfHttpError(response);
        rawList = response.data as List<dynamic>? ?? [];
      }
      var list = rawList
          .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (filters.tipo != null) {
        list = list.where((t) => t.tipo == filters.tipo).toList();
      }
      if (filters.apenasComVagas) {
        list = list.where((t) => t.temVagasDisponiveis).toList();
      }
      return list;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<TripModel>> minhasViagens() async {
    try {
      final response = await _dio.get('$_p/historico/me');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return [];
      final criadas = data['criadas'] as List<dynamic>? ?? [];
      final participando = data['participando'] as List<dynamic>? ?? [];
      final seen = <int>{};
      final out = <TripModel>[];
      for (final e in [...criadas, ...participando]) {
        final m = TripModel.fromJson(e as Map<String, dynamic>);
        if (seen.add(m.id)) out.add(m);
      }
      return out;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<TripModel> buscarPorId(int id) async {
    try {
      final response = await _dio.get('$_p/trips/$id');
      return TripModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

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
      final body = <String, dynamic>{
        'destino': destino,
        'descricao': descricao,
        'tipo': tipo,
        'dataInicio': dataInicio.toIso8601String().split('T').first,
        'dataFim': dataFim.toIso8601String().split('T').first,
        if (estado != null) 'estado': estado,
        if (cidade != null) 'cidade': cidade,
        if (atrativo != null) 'atrativo': atrativo,
        if (maxVagas != null) 'maxVagas': maxVagas,
      };
      final response = await _dio.post('$_p/trips', data: body);
      return TripModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<ParticipantModel>> listarParticipantes(int viagemId) async {
    try {
      final response = await _dio.get('$_p/trips/$viagemId/details');
      final data = response.data as Map<String, dynamic>?;
      final parts = data?['participants'] as List<dynamic>? ?? [];
      return parts
          .map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> participar(int viagemId) async {
    try {
      await _dio.post('$_p/participantes/join', data: {'viagemId': viagemId});
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> cancelarParticipacao(int viagemId) async {
    try {
      await _dio.post('$_p/participantes/leave', data: {'viagemId': viagemId});
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> atualizarStatusParticipante(
      int _, int participanteId, String status) async {
    try {
      await _dio.patch(
        '$_p/participantes/$participanteId/status',
        data: {'status': status},
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
