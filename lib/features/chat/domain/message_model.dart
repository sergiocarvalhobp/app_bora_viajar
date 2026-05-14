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

  bool isMinha(int myId) => senderId == myId;

  String get senderName => sender?.name.split(' ').first ?? 'Viajante';

  static int _int(dynamic v) => (v is num) ? v.toInt() : int.parse('$v');

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final sid = _int(json['senderId'] ?? json['sender_id']);
    UserModel? sender;
    if (json['sender'] != null) {
      sender = UserModel.fromJson(json['sender'] as Map<String, dynamic>);
    } else {
      final name = json['senderName'] as String?;
      final avatar = json['senderAvatar'] as String?;
      if (name != null || avatar != null) {
        sender = UserModel(
          id: sid,
          openId: '',
          name: name ?? 'Viajante',
          foto: avatar,
        );
      }
    }
    return MessageModel(
      id: _int(json['id']),
      viagemId: _int(json['viagemId'] ?? json['viagem_id']),
      senderId: sid,
      conteudo: json['conteudo'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      sender: sender,
    );
  }

  @override
  List<Object?> get props => [id, viagemId, senderId, conteudo, timestamp];
}

class OptimisticMessage extends MessageModel {
  const OptimisticMessage({
    required super.id,
    required super.viagemId,
    required super.senderId,
    required super.conteudo,
    required super.timestamp,
    super.sender,
    this.pending = true,
    this.failed = false,
  });

  final bool pending;
  final bool failed;

  OptimisticMessage copyWithState({bool? pending, bool? failed}) {
    return OptimisticMessage(
      id: id,
      viagemId: viagemId,
      senderId: senderId,
      conteudo: conteudo,
      timestamp: timestamp,
      sender: sender,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
    );
  }
}
