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
    this.organizerRating,
    this.organizerRatingCount,
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

  /// Média 0–5 das viagens que o usuário criou (`organizerRating` / `mediaOrganizador` na API).
  final double? organizerRating;

  /// Quantidade de avaliações recebidas nas viagens que criou.
  final int? organizerRatingCount;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool get isAdmin => role == 'admin';

  static int _id(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static double? _organizerRating(dynamic v) {
    if (v == null) return null;
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n == null) return null;
    return n.clamp(0.0, 5.0);
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final foto = json['foto'] as String? ?? json['avatarUrl'] as String?;
    final cidade =
        json['cidade'] as String? ?? json['cidadeResidencia'] as String?;
    final estado =
        json['estado'] as String? ?? json['estadoResidencia'] as String?;
    final openIdRaw = json['openId'] ?? json['open_id'];
    return UserModel(
      id: _id(json['id']),
      openId: openIdRaw?.toString() ?? '',
      name: (json['name']?.toString()) ?? 'Viajante',
      email: json['email'] as String?,
      foto: foto,
      bio: json['bio'] as String?,
      instagram: json['instagram'] as String?,
      estado: estado,
      cidade: cidade,
      role: (json['role'] as String?) ?? 'user',
      organizerRating: _organizerRating(
        json['organizerRating'] ??
            json['mediaOrganizador'] ??
            json['media_organizador'] ??
            json['organizerAverageRating'] ??
            json['rating'] ??
            json['ratingMedia'] ??
            json['estrelas'],
      ),
      organizerRatingCount: _organizerRatingCount(
        json['organizerRatingCount'] ??
            json['totalAvaliacoesOrganizador'] ??
            json['total_avaliacoes_organizador'] ??
            json['ratingCount'],
      ),
    );
  }

  static int? _organizerRatingCount(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
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
        if (organizerRating != null) 'organizerRating': organizerRating,
        if (organizerRatingCount != null)
          'organizerRatingCount': organizerRatingCount,
      };

  /// Handle para exibir ao lado do ícone @ (sem duplicar o símbolo).
  String? get instagramHandle {
    final ig = instagram?.trim();
    if (ig == null || ig.isEmpty) return null;
    return ig.startsWith('@') ? ig.substring(1) : ig;
  }

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
    double? organizerRating,
    int? organizerRatingCount,
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
      organizerRating: organizerRating ?? this.organizerRating,
      organizerRatingCount: organizerRatingCount ?? this.organizerRatingCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        openId,
        name,
        email,
        foto,
        bio,
        instagram,
        estado,
        cidade,
        role,
        organizerRating,
        organizerRatingCount,
      ];
}
