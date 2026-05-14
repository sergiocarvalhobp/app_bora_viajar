import 'package:equatable/equatable.dart';

enum TipoNotificacao {
  participante('participante'),
  sistema('sistema'),
  mensagem('mensagem');

  const TipoNotificacao(this.valor);
  final String valor;

  static TipoNotificacao fromString(String s) =>
      TipoNotificacao.values.firstWhere(
        (e) => e.valor == s,
        orElse: () => TipoNotificacao.sistema,
      );
}

class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    required this.lida,
    required this.createdAt,
    this.viagemId,
  });

  final int id;
  final int userId;
  final TipoNotificacao tipo;
  final String titulo;
  final String mensagem;
  final bool lida;
  final DateTime createdAt;
  final int? viagemId;

  static int _int(dynamic v) => (v is num) ? v.toInt() : int.parse('$v');

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id:        _int(json['id']),
      userId:    _int(json['userId'] ?? json['user_id']),
      tipo:      TipoNotificacao.fromString(
                   (json['tipo'] as String?) ?? 'sistema'),
      titulo:    json['titulo'] as String,
      mensagem:  json['mensagem'] as String,
      lida:      ((json['lida'] is bool) ? (json['lida'] as bool) : _int(json['lida'] ?? 0) == 1),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      viagemId:  json['viagemId'] != null
          ? _int(json['viagemId'])
          : (json['viagem_id'] != null ? _int(json['viagem_id']) : null),
    );
  }

  @override
  List<Object?> get props => [id, userId, tipo, titulo, lida, createdAt];
}
