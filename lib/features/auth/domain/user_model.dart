import 'package:equatable/equatable.dart';

/// Espelha a tabela `users` do banco MySQL / resposta JSON da API Java.
class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.openId,
    required this.name,
    this.email,
    this.foto,
    this.bio,
    this.instagram,
    this.estado,
    this.cidade,
    this.role = 'user',
  });

  final int id;
  final String openId;
  final String name;
  final String? email;
  final String? foto;
  final String? bio;
  final String? instagram;
  final String? estado;
  final String? cidade;
  final String role;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool get isAdmin => role == 'admin';

  static int _id(dynamic v) => (v is num) ? v.toInt() : int.parse('$v');

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final foto = json['foto'] as String? ?? json['avatarUrl'] as String?;
    final cidade =
        json['cidade'] as String? ?? json['cidadeResidencia'] as String?;
    final estado =
        json['estado'] as String? ?? json['estadoResidencia'] as String?;
    return UserModel(
      id: _id(json['id']),
      openId: (json['openId'] ?? json['open_id'] ?? '') as String,
      name: (json['name'] as String?) ?? 'Viajante',
      email: json['email'] as String?,
      foto: foto,
      bio: json['bio'] as String?,
      instagram: json['instagram'] as String?,
      estado: estado,
      cidade: cidade,
      role: (json['role'] as String?) ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'openId': openId,
        'name': name,
        'email': email,
        'foto': foto,
        'bio': bio,
        'instagram': instagram,
        'estado': estado,
        'cidade': cidade,
        'role': role,
      };

  UserModel copyWith({
    int? id,
    String? openId,
    String? name,
    String? email,
    String? foto,
    String? bio,
    String? instagram,
    String? estado,
    String? cidade,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      openId: openId ?? this.openId,
      name: name ?? this.name,
      email: email ?? this.email,
      foto: foto ?? this.foto,
      bio: bio ?? this.bio,
      instagram: instagram ?? this.instagram,
      estado: estado ?? this.estado,
      cidade: cidade ?? this.cidade,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props =>
      [id, openId, name, email, foto, bio, instagram, estado, cidade, role];
}
