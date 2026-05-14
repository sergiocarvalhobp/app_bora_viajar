import 'package:equatable/equatable.dart';
import '../../auth/domain/user_model.dart';

/// Tipos de viagem — espelha o campo `tipo` da tabela `viagens`.
/// 'Lider'    → quem criou já sabe o destino e procura companhia
/// 'Viajante' → quer ir a algum lugar mas precisa de um líder
enum TipoViagem {
  lider('Lider', 'Líder de grupo'),
  viajante('Viajante', 'Procuro grupo');

  const TipoViagem(this.valor, this.label);
  final String valor;
  final String label;

  static TipoViagem fromString(String s) =>
      TipoViagem.values.firstWhere(
        (t) => t.valor.toLowerCase() == s.toLowerCase(),
        orElse: () => TipoViagem.viajante,
      );
}

/// Model completo de uma viagem.
/// Espelha a tabela `viagens` + campos extras retornados pela API
/// (lider, participantesCount, vagas disponíveis, myStatus).
class TripModel extends Equatable {
  const TripModel({
    required this.id,
    required this.liderId,
    required this.destino,
    required this.dataInicio,
    required this.dataFim,
    required this.descricao,
    required this.tipo,
    this.estado,
    this.cidade,
    this.atrativo,
    this.maxVagas,
    this.lider,
    this.participantesCount = 0,
    this.myStatus,
    this.createdAt,
  });

  final int id;
  final int liderId;
  final String destino;
  final DateTime dataInicio;
  final DateTime dataFim;
  final String descricao;
  final TipoViagem tipo;
  final String? estado;
  final String? cidade;
  final String? atrativo;
  final int? maxVagas;

  // Campos extras que a API retorna junto
  final UserModel? lider;
  final int participantesCount;
  final String? myStatus; // 'interessado' | 'confirmado' | null
  final DateTime? createdAt;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Vagas disponíveis. null = sem limite.
  int? get vagasDisponiveis =>
      maxVagas != null ? (maxVagas! - participantesCount).clamp(0, maxVagas!) : null;

  bool get temVagasDisponiveis =>
      vagasDisponiveis == null || vagasDisponiveis! > 0;

  bool get isParticipando =>
      myStatus == 'interessado' || myStatus == 'confirmado';

  /// Duração em dias.
  int get duracaoDias => dataFim.difference(dataInicio).inDays + 1;

  /// Ex: "15 a 20 jun" ou "28 dez a 3 jan"
  String get periodoFormatado {
    final meses = [
      '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    final inicio = '${dataInicio.day} ${meses[dataInicio.month]}';
    final fim = dataFim.month == dataInicio.month
        ? '${dataFim.day}'
        : '${dataFim.day} ${meses[dataFim.month]}';
    return '$inicio a $fim';
  }

  // ── JSON ───────────────────────────────────────────────────────────────────

  static int _int(dynamic v) => (v is num) ? v.toInt() : int.parse('$v');

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id:                 _int(json['id']),
      liderId:            _int(json['liderId'] ?? json['lider_id']),
      destino:            json['destino'] as String,
      dataInicio:         DateTime.parse(json['dataInicio'] ?? json['data_inicio'] as String),
      dataFim:            DateTime.parse(json['dataFim'] ?? json['data_fim'] as String),
      descricao:          json['descricao'] as String,
      tipo:               TipoViagem.fromString(json['tipo'] as String),
      estado:             json['estado'] as String?,
      cidade:             json['cidade'] as String?,
      atrativo:           json['atrativo'] as String?,
      maxVagas:           json['maxVagas'] != null
                            ? _int(json['maxVagas'])
                            : (json['max_vagas'] != null ? _int(json['max_vagas']) : null),
      lider:              json['lider'] != null
                            ? UserModel.fromJson(json['lider'] as Map<String, dynamic>)
                            : null,
      participantesCount: json['participantesCount'] != null
          ? _int(json['participantesCount'])
          : (json['participantes_count'] != null
              ? _int(json['participantes_count'])
              : (json['participantCount'] != null ? _int(json['participantCount']) : 0)),
      myStatus:           json['myStatus'] as String?,
      createdAt:          json['createdAt'] != null
                            ? DateTime.tryParse(json['createdAt'] as String)
                            : null,
    );
  }

  @override
  List<Object?> get props => [
        id, liderId, destino, dataInicio, dataFim,
        descricao, tipo, estado, cidade, atrativo,
        maxVagas, participantesCount, myStatus,
      ];
}

/// Filtros de busca — espelha os parâmetros do endpoint `viagens.listar`.
class TripFilters extends Equatable {
  const TripFilters({
    this.query,
    this.tipo,
    this.estado,
    this.dataInicio,
    this.dataFim,
    this.apenasComVagas = false,
  });

  final String? query;
  final TipoViagem? tipo;
  final String? estado;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool apenasComVagas;

  bool get isEmpty =>
      query == null &&
      tipo == null &&
      estado == null &&
      dataInicio == null &&
      dataFim == null &&
      !apenasComVagas;

  TripFilters copyWith({
    String? query,
    TipoViagem? tipo,
    String? estado,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool? apenasComVagas,
  }) {
    return TripFilters(
      query:          query         ?? this.query,
      tipo:           tipo          ?? this.tipo,
      estado:         estado        ?? this.estado,
      dataInicio:     dataInicio    ?? this.dataInicio,
      dataFim:        dataFim       ?? this.dataFim,
      apenasComVagas: apenasComVagas ?? this.apenasComVagas,
    );
  }

  TripFilters clearFiltro(String campo) {
    return TripFilters(
      query:          campo == 'query'      ? null : query,
      tipo:           campo == 'tipo'       ? null : tipo,
      estado:         campo == 'estado'     ? null : estado,
      dataInicio:     campo == 'dataInicio' ? null : dataInicio,
      dataFim:        campo == 'dataFim'    ? null : dataFim,
      apenasComVagas: campo == 'vagas'      ? false : apenasComVagas,
    );
  }

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (query != null && query!.isNotEmpty) params['q'] = query!;
    if (tipo != null) params['tipo'] = tipo!.valor;
    if (estado != null) params['estado'] = estado!;
    if (dataInicio != null) params['dataInicio'] = dataInicio!.toIso8601String().substring(0, 10);
    if (dataFim != null) params['dataFim'] = dataFim!.toIso8601String().substring(0, 10);
    if (apenasComVagas) params['comVagas'] = 'true';
    return params;
  }

  @override
  List<Object?> get props =>
      [query, tipo, estado, dataInicio, dataFim, apenasComVagas];
}
