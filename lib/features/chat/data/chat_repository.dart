import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app_constants.dart';
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

  static const _p = AppConstants.restApiPrefix;

  Future<List<MessageModel>> listar(int viagemId) async {
    try {
      final response = await _dio.get('$_p/messages/viagem/$viagemId');
      final rawList = response.data as List<dynamic>? ?? [];
      return rawList
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// A API Java lista todas as mensagens; filtramos localmente por [afterId].
  Future<List<MessageModel>> listarDesde(int viagemId, int afterId) async {
    final all = await listar(viagemId);
    return all.where((m) => m.id > afterId).toList();
  }

  Future<MessageModel> enviar(int viagemId, String conteudo) async {
    try {
      final response = await _dio.post(
        '$_p/messages',
        data: {'viagemId': viagemId, 'conteudo': conteudo},
      );
      return MessageModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
