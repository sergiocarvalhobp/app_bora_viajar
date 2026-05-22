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
    this.tripFinished,
    this.canRateOrganizer,
    this.myOrganizerRating,
    this.myOrganizerTestimony,
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

  /// Viagem já terminou (data fim anterior a hoje).
  final bool? tripFinished;
  /// Participante confirmado pode avaliar quem criou a viagem (após o fim).
  final bool? canRateOrganizer;
  /// Nota 1–5 que o usuário logado deu nesta viagem, se houver.
  final int? myOrganizerRating;
  /// Testemunho do participante sobre a viagem / quem a criou.
  final String? myOrganizerTestimony;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime get _todayLocal => _dateOnly(DateTime.now());

  /// Viagem já passou (data fim anterior a hoje).
  bool get isTripFinished {
    return _dateOnly(dataFim).isBefore(_todayLocal);
  }

  /// Home / explorar: data fim ainda é hoje ou futura.
  bool get isValidForHome => !_dateOnly(dataFim).isBefore(_todayLocal);

  /// Último dia da viagem ou depois — pode avaliar.
  bool get isTripEndedForReview {
    if (tripFinished == true) return true;
    final today = DateTime.now();
    final end = DateTime(dataFim.year, dataFim.month, dataFim.day);
    final now = DateTime(today.year, today.month, today.day);
    return !end.isAfter(now);
  }

  /// Viagem ainda em andamento ou futura (exibir na home / explorar).
  bool get isActiveForExplore => isValidForHome;

  bool canRateOrganizerNow(int? currentUserId) {
    if (canRateOrganizer != null) return canRateOrganizer!;
    if (currentUserId == null) return false;
    return isTripEndedForReview &&
        isConfirmado &&
        currentUserId != liderId;
  }

  /// Vagas disponíveis. null = sem limite.
  int? get vagasDisponiveis =>
      maxVagas != null ? (maxVagas! - participantesCount).clamp(0, maxVagas!) : null;

  bool get temVagasDisponiveis =>
      vagasDisponiveis == null || vagasDisponiveis! > 0;

  bool get isParticipando =>
      myStatus == 'interessado' || myStatus == 'confirmado';

  bool get isConfirmado => myStatus == 'confirmado';

  bool get isAguardandoConfirmacao => myStatus == 'interessado';

  /// Chat: organizador sempre; viajante só após confirmação.
  bool canAccessChat(int? currentUserId) {
    if (currentUserId == null) return false;
    if (currentUserId == liderId) return true;
    return myStatus == 'confirmado';
  }

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

  static DateTime _parseDate(dynamic v) {
    if (v == null) throw FormatException('data ausente');
    if (v is String) {
      return DateTime.parse(v.split('T').first);
    }
    if (v is List && v.length >= 3) {
      return DateTime(_int(v[0]), _int(v[1]), _int(v[2]));
    }
    if (v is Map) {
      final y = v['year'] ?? v['Year'];
      final m = v['month'] ?? v['Month'] ?? v['monthValue'];
      final d = v['day'] ?? v['Day'] ?? v['dayOfMonth'];
      if (y != null && m != null && d != null) {
        return DateTime(_int(y), _int(m), _int(d));
      }
    }
    throw FormatException('formato de data inválido: $v');
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id:                 _int(json['id']),
      liderId:            _int(json['liderId'] ?? json['lider_id']),
      destino:            json['destino'] as String,
      dataInicio:         _parseDate(json['dataInicio'] ?? json['data_inicio']),
      dataFim:            _parseDate(json['dataFim'] ?? json['data_fim']),
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
      tripFinished:       json['tripFinished'] as bool?,
      canRateOrganizer:   json['canRateOrganizer'] as bool?,
      myOrganizerRating:  json['myOrganizerRating'] != null
          ? _int(json['myOrganizerRating'])
          : null,
      myOrganizerTestimony: json['myOrganizerTestimony'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id, liderId, destino, dataInicio, dataFim,
        descricao, tipo, estado, cidade, atrativo,
        maxVagas, participantesCount, myStatus,
        tripFinished, canRateOrganizer, myOrganizerRating, myOrganizerTestimony,
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
    this.apenasAtivas = true,
  });

  final String? query;
  final TipoViagem? tipo;
  final String? estado;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool apenasComVagas;
  /// Oculta viagens já encerradas (home / explorar).
  final bool apenasAtivas;

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
    bool? apenasAtivas,
  }) {
    return TripFilters(
      query:          query         ?? this.query,
      tipo:           tipo          ?? this.tipo,
      estado:         estado        ?? this.estado,
      dataInicio:     dataInicio    ?? this.dataInicio,
      dataFim:        dataFim       ?? this.dataFim,
      apenasComVagas: apenasComVagas ?? this.apenasComVagas,
      apenasAtivas:   apenasAtivas   ?? this.apenasAtivas,
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
      apenasAtivas:   apenasAtivas,
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
    if (apenasAtivas) params['apenasAtivas'] = 'true';
    return params;
  }

  @override
  List<Object?> get props =>
      [query, tipo, estado, dataInicio, dataFim, apenasComVagas, apenasAtivas];
}
