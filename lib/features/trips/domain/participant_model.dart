import 'package:equatable/equatable.dart';
import '../../auth/domain/user_model.dart';

/// Status de participação — espelha o campo `status` da tabela `participantes`.
enum StatusParticipacao {
  interessado('interessado', 'Interessado'),
  confirmado('confirmado', 'Confirmado'),
  recusado('recusado', 'Recusado');

  const StatusParticipacao(this.valor, this.label);
  final String valor;
  final String label;

  static StatusParticipacao fromString(String s) =>
      StatusParticipacao.values.firstWhere(
        (e) => e.valor == s,
        orElse: () => StatusParticipacao.interessado,
      );
}

class ParticipantModel extends Equatable {
  const ParticipantModel({
    required this.id,
    required this.viagemId,
    required this.userId,
    required this.status,
    this.user,
    this.createdAt,
  });

  final int id;
  final int viagemId;
  final int userId;
  final StatusParticipacao status;
  final UserModel? user;
  final DateTime? createdAt;

  bool get isConfirmado  => status == StatusParticipacao.confirmado;
  bool get isInteressado => status == StatusParticipacao.interessado;

  static int _int(dynamic v) => (v is num) ? v.toInt() : int.parse('$v');

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id:       _int(json['id']),
      viagemId: _int(json['viagemId'] ?? json['viagem_id']),
      userId:   _int(json['userId'] ?? json['user_id']),
      status:   StatusParticipacao.fromString(
                  (json['status'] as String?) ?? 'interessado'),
      user:     json['user'] != null
                  ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
                  : null,
      createdAt: json['createdAt'] != null
                  ? DateTime.tryParse(json['createdAt'] as String)
                  : null,
    );
  }

  @override
  List<Object?> get props => [id, viagemId, userId, status];
}
