import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/network/api_client.dart';
import '../domain/participant_model.dart';
import '../domain/trip_model.dart';
import '../domain/trips_page.dart';

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

  Future<TripsPage> listarPaginado({
    required TripFilters filters,
    required int offset,
    required int limit,
  }) async {
    try {
      final qp = <String, dynamic>{
        'offset': offset,
        'limit': limit,
      };
      final Response<dynamic> response;
      if (filters.isEmpty) {
        response = await _dio.get('$_p/trips', queryParameters: qp);
      } else {
        if (filters.query != null && filters.query!.isNotEmpty) {
          qp['destino'] = filters.query;
        }
        if (filters.estado != null) qp['estado'] = filters.estado;
        if (filters.dataInicio != null) {
          qp['dataInicio'] =
              filters.dataInicio!.toIso8601String().split('T').first;
        }
        if (filters.dataFim != null) {
          qp['dataFim'] = filters.dataFim!.toIso8601String().split('T').first;
        }
        response = await _dio.get('$_p/trips/filter', queryParameters: qp);
      }
      _throwIfHttpError(response);
      return _parseTripsPage(response.data, filters);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  TripsPage _parseTripsPage(dynamic data, TripFilters filters) {
    List<dynamic> rawList;
    int fetchedCount;
    bool hasMore;
    int total;

    if (data is List<dynamic>) {
      rawList = data;
      fetchedCount = rawList.length;
      hasMore = false;
      total = rawList.length;
    } else {
      final map = data as Map<String, dynamic>? ?? {};
      rawList = map['items'] as List<dynamic>? ?? [];
      fetchedCount = rawList.length;
      hasMore = map['hasMore'] as bool? ?? false;
      total = (map['total'] as num?)?.toInt() ?? fetchedCount;
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
    return TripsPage(
      items: list,
      fetchedCount: fetchedCount,
      hasMore: hasMore,
      total: total,
    );
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
      final response = await _dio.post(
        '$_p/participantes/join',
        data: {'viagemId': viagemId},
      );
      _throwIfHttpError(response);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Remove a participação na tabela `participantes` (API Java POST /leave).
  Future<void> cancelarParticipacao(int viagemId) async {
    try {
      final response = await _dio.post(
        '$_p/participantes/leave',
        data: {'viagemId': viagemId},
      );
      _throwIfHttpError(response);
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
