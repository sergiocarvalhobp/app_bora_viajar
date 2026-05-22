import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/router/trip_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_notch_shell.dart';
import '../domain/trip_model.dart';
import '../data/trips_repository.dart';

part 'create_trip_screen.g.dart';

// ── Estado do formulário ───────────────────────────────────────────────────────

class CreateTripForm {
  const CreateTripForm({
    this.destino       = '',
    this.estado,
    this.cidade        = '',
    this.atrativo      = '',
    this.descricao     = '',
    this.tipo          = TipoViagem.lider,
    this.dataInicio,
    this.dataFim,
    this.maxVagas,
    this.isSubmitting  = false,
    this.error,
  });

  final String destino;
  final String? estado;
  final String cidade;
  final String atrativo;
  final String descricao;
  final TipoViagem tipo;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final int? maxVagas;
  final bool isSubmitting;
  final String? error;

  bool get isValid =>
      destino.trim().isNotEmpty &&
      descricao.trim().isNotEmpty &&
      dataInicio != null &&
      dataFim != null &&
      (dataFim!.isAfter(dataInicio!) || dataFim!.isAtSameMomentAs(dataInicio!));

  CreateTripForm copyWith({
    String? destino,
    String? estado,
    String? cidade,
    String? atrativo,
    String? descricao,
    TipoViagem? tipo,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? maxVagas,
    bool clearMaxVagas = false,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return CreateTripForm(
      destino:      destino      ?? this.destino,
      estado:       estado       ?? this.estado,
      cidade:       cidade       ?? this.cidade,
      atrativo:     atrativo     ?? this.atrativo,
      descricao:    descricao    ?? this.descricao,
      tipo:         tipo         ?? this.tipo,
      dataInicio:   dataInicio   ?? this.dataInicio,
      dataFim:      dataFim      ?? this.dataFim,
      maxVagas:     clearMaxVagas ? null : maxVagas ?? this.maxVagas,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error:        clearError   ? null : error ?? this.error,
    );
  }
}

@riverpod
class CreateTripNotifier extends _$CreateTripNotifier {
  @override
  CreateTripForm build() => const CreateTripForm();

  void setDestino(String v)    => state = state.copyWith(destino: v);
  void setEstado(String? v)    => state = state.copyWith(estado: v);
  void setCidade(String v)     => state = state.copyWith(cidade: v);
  void setAtrativo(String v)   => state = state.copyWith(atrativo: v);
  void setDescricao(String v)  => state = state.copyWith(descricao: v);
  void setTipo(TipoViagem v)   => state = state.copyWith(tipo: v);
  void setDatas(DateTime? inicio, DateTime? fim) =>
      state = state.copyWith(dataInicio: inicio, dataFim: fim);
  void setMaxVagas(int? v)     => state = state.copyWith(
    maxVagas: v, clearMaxVagas: v == null);

  Future<void> submit(BuildContext context) async {
    if (!state.isValid) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(tripsRepositoryProvider);
      final trip = await repo.criar(
        destino:    state.destino.trim(),
        estado:     state.estado,
        cidade:     state.cidade.trim().isEmpty ? null : state.cidade.trim(),
        atrativo:   state.atrativo.trim().isEmpty ? null : state.atrativo.trim(),
        descricao:  state.descricao.trim(),
        tipo:       state.tipo.valor,
        dataInicio: state.dataInicio!,
        dataFim:    state.dataFim!,
        maxVagas:   state.maxVagas,
      );
      if (context.mounted) openTripDetails(context, trip.id);
    } catch (e) {
      state = state.copyWith(
          isSubmitting: false, error: 'Não foi possível criar a viagem.');
    }
  }
}

// ── Tela ───────────────────────────────────────────────────────────────────────

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});
  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _destinoCtrl   = TextEditingController();
  final _cidadeCtrl    = TextEditingController();
  final _atrativoCtrl  = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _vagasCtrl     = TextEditingController();
  final _scroll        = ScrollController();

  @override
  void dispose() {
    for (final c in [_destinoCtrl,_cidadeCtrl,_atrativoCtrl,_descricaoCtrl,_vagasCtrl]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form    = ref.watch(createTripNotifierProvider);
    final notif   = ref.read(createTripNotifierProvider.notifier);
    final tt      = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Criar viagem',
            style: TextStyle(
              fontFamily: 'DMSerifDisplay',
              fontSize: 20,
              color: Colors.white,
            )),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        children: [

          // ── Tipo ─────────────────────────────────────────────────────
          const _SectionLabel('Qual é o seu perfil nesta viagem?'),
          const SizedBox(height: 10),
          _TipoSelector(
            value:    form.tipo,
            onChanged: notif.setTipo,
          ),

          const SizedBox(height: 24),

          // ── Destino ───────────────────────────────────────────────────
          const _SectionLabel('Destino *'),
          const SizedBox(height: 8),
          _BvInput(
            controller:  _destinoCtrl,
            hint:        'Ex: Chapada dos Veadeiros, Bonito, Lençóis...',
            onChanged:   notif.setDestino,
            capitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 16),

          // Estado + Cidade
          Row(children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Estado'),
                  const SizedBox(height: 8),
                  _EstadoDropdown(
                    value:    form.estado,
                    onChanged: notif.setEstado,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Cidade'),
                  const SizedBox(height: 8),
                  _BvInput(
                    controller: _cidadeCtrl,
                    hint: 'Nome da cidade',
                    onChanged: notif.setCidade,
                    capitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          const _SectionLabel('Atrativo / Ponto turístico'),
          const SizedBox(height: 8),
          _BvInput(
            controller: _atrativoCtrl,
            hint: 'Ex: Parque Nacional, Cachoeira do Fumaça...',
            onChanged: notif.setAtrativo,
            capitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 24),

          // ── Datas ─────────────────────────────────────────────────────
          const _SectionLabel('Período da viagem *'),
          const SizedBox(height: 8),
          _DateRangePicker(
            dataInicio: form.dataInicio,
            dataFim:    form.dataFim,
            onChanged:  notif.setDatas,
          ),

          const SizedBox(height: 24),

          // ── Vagas ─────────────────────────────────────────────────────
          const _SectionLabel('Máximo de participantes'),
          const SizedBox(height: 4),
          Text('Deixe em branco para não ter limite.',
              style: tt.bodySmall?.copyWith(color: AppColors.barkMuted)),
          const SizedBox(height: 8),
          _BvInput(
            controller: _vagasCtrl,
            hint: 'Ex: 6',
            keyboardType: TextInputType.number,
            onChanged: (v) => notif.setMaxVagas(int.tryParse(v)),
          ),

          const SizedBox(height: 24),

          // ── Descrição ─────────────────────────────────────────────────
          const _SectionLabel('Descrição *'),
          const SizedBox(height: 4),
          Text('Conte o que planejou, como vai ser a viagem, o que espera dos companheiros.',
              style: tt.bodySmall?.copyWith(color: AppColors.barkMuted)),
          const SizedBox(height: 8),
          _BvInput(
            controller: _descricaoCtrl,
            hint: 'Descreva a viagem...',
            onChanged: notif.setDescricao,
            maxLines: 5,
          ),

          const SizedBox(height: 24),

          // Erro
          if (form.error != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(form.error!,
                  style: const TextStyle(color: AppColors.error,
                      fontFamily: 'Nunito', fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
        ],
            ),
          ),

          // Botão fixo acima do menu inferior
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + AppNotchShell.bottomBarClearance(context),
            ),
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: const Border(top: BorderSide(color: AppColors.sand)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bark.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: form.isValid && !form.isSubmitting
                    ? () => notif.submit(context)
                    : null,
                icon: form.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.rocket_launch_outlined, size: 18),
                label: Text(
                    form.isSubmitting ? 'Criando...' : 'Publicar viagem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terra,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets do formulário ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.titleSmall);
}

class _BvInput extends StatelessWidget {
  const _BvInput({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
          color: AppColors.bark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
            color: AppColors.barkMuted),
      ),
    );
  }
}

class _TipoSelector extends StatelessWidget {
  const _TipoSelector({required this.value, required this.onChanged});
  final TipoViagem value;
  final ValueChanged<TipoViagem> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TipoViagem.values.map((tipo) {
        final selected = value == tipo;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: tipo == TipoViagem.lider ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(tipo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? (tipo == TipoViagem.lider
                          ? AppColors.forest
                          : AppColors.terra)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? (tipo == TipoViagem.lider
                            ? AppColors.forest
                            : AppColors.terra)
                        : AppColors.sand,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      tipo == TipoViagem.lider
                          ? Icons.star_rounded
                          : Icons.explore_rounded,
                      color: selected ? Colors.white : AppColors.barkMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tipo == TipoViagem.lider
                          ? 'Sou o líder'
                          : 'Procuro grupo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.bark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tipo == TipoViagem.lider
                          ? 'Já tenho o plano'
                          : 'Quero companhia',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        color: selected
                            ? Colors.white70
                            : AppColors.barkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  const _DateRangePicker({
    required this.dataInicio,
    required this.dataFim,
    required this.onChanged,
  });
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final void Function(DateTime?, DateTime?) onChanged;

  String _fmt(DateTime? d) {
    if (d == null) return 'Selecionar';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  Future<void> _pick(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange: dataInicio != null && dataFim != null
          ? DateTimeRange(start: dataInicio!, end: dataFim!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.forest,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) onChanged(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dataInicio != null ? AppColors.forest : AppColors.sand,
            width: dataInicio != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded,
                color: dataInicio != null
                    ? AppColors.forest
                    : AppColors.barkMuted,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dataInicio != null
                    ? '${_fmt(dataInicio)}  →  ${_fmt(dataFim)}'
                    : 'Toque para selecionar as datas',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: dataInicio != null
                      ? AppColors.bark
                      : AppColors.barkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoDropdown extends StatelessWidget {
  const _EstadoDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  static const _estados = [
    'AC','AL','AM','AP','BA','CE','DF','ES','GO',
    'MA','MG','MS','MT','PA','PB','PE','PI','PR',
    'RJ','RN','RO','RR','RS','SC','SE','SP','TO',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: const Text('UF',
              style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 14, color: AppColors.barkMuted)),
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              color: AppColors.barkMuted, size: 18),
          style: const TextStyle(
              fontFamily: 'Nunito', fontSize: 14, color: AppColors.bark),
          onChanged: onChanged,
          items: [
            const DropdownMenuItem(value: null,
                child: Text('–', style: TextStyle(color: AppColors.barkMuted))),
            ..._estados.map((uf) =>
                DropdownMenuItem(value: uf, child: Text(uf))),
          ],
        ),
      ),
    );
  }
}
