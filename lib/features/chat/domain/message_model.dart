import 'package:equatable/equatable.dart';
import '../../auth/domain/user_model.dart';

class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.viagemId,
    required this.senderId,
    required this.conteudo,
    required this.timestamp,
    this.sender,
  });

  final int id;
  final int viagemId;
  final int senderId;
  final String conteudo;
  final DateTime timestamp;
  final UserModel? sender;

  /// Verifica se a mensagem foi enviada pelo usuário com [myId].
  bool isMinha(int myId) => senderId == myId;

  /// Nome curto do remetente para exibição no grupo.
  String get senderName => sender?.name.split(' ').first ?? 'Viajante';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id:        json['id'] as int,
      viagemId:  (json['viagemId']  ?? json['viagem_id'])  as int,
      senderId:  (json['senderId']  ?? json['sender_id'])  as int,
      conteudo:  json['conteudo']   as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      sender:    json['sender'] != null
                   ? UserModel.fromJson(json['sender'] as Map<String, dynamic>)
                   : null,
    );
  }

  @override
  List<Object?> get props => [id, viagemId, senderId, conteudo, timestamp];
}

/// Mensagem otimista — criada localmente antes do ACK do servidor.
class OptimisticMessage extends MessageModel {
  const OptimisticMessage({
    required super.id,
    required super.viagemId,
    required super.senderId,
    required super.conteudo,
    required super.timestamp,
    super.sender,
    this.pending = true,
    this.failed  = false,
  });

  final bool pending;
  final bool failed;

  OptimisticMessage copyWithState({bool? pending, bool? failed}) {
    return OptimisticMessage(
      id:        id,
      viagemId:  viagemId,
      senderId:  senderId,
      conteudo:  conteudo,
      timestamp: timestamp,
      sender:    sender,
      pending:   pending ?? this.pending,
      failed:    failed  ?? this.failed,
    );
  }
}
