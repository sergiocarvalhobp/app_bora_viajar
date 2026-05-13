import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/network/api_client.dart';
import '../domain/message_model.dart';

part 'chat_repository.g.dart';

@riverpod
ChatRepository chatRepository(Ref ref) {
  return ChatRepository(dio: ref.watch(apiClientProvider));
}

class ChatRepository {
  ChatRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  // ── Listagem de mensagens ──────────────────────────────────────────────────

  /// Busca todas as mensagens de uma viagem.
  /// Equivale a `trpc.mensagens.listar` no site.
  Future<List<MessageModel>> listar(int viagemId) async {
    try {
      final response = await _dio.get(
        trpcUrl('mensagens.listar'),
        queryParameters: {
          'input': '{"json":{"viagemId":$viagemId}}',
        },
      );
      final data = _extractTrpcData(response.data);
      if (data is! List) return [];
      return data
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Busca mensagens mais novas que [afterId] — usado pelo polling incremental.
  Future<List<MessageModel>> listarDesde(int viagemId, int afterId) async {
    try {
      final response = await _dio.get(
        trpcUrl('mensagens.listar'),
        queryParameters: {
          'input': '{"json":{"viagemId":$viagemId,"afterId":$afterId}}',
        },
      );
      final data = _extractTrpcData(response.data);
      if (data is! List) return [];
      return data
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ── Envio ──────────────────────────────────────────────────────────────────

  /// Envia uma mensagem e retorna a mensagem persistida com ID real.
  Future<MessageModel> enviar(int viagemId, String conteudo) async {
    try {
      final response = await _dio.post(
        trpcUrl('mensagens.enviar'),
        data: {
          '0': {
            'json': {
              'viagemId': viagemId,
              'conteudo': conteudo,
            }
          }
        },
      );
      final data = _extractTrpcData(response.data);
      return MessageModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ── Helper tRPC ────────────────────────────────────────────────────────────

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
