import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/trip_model.dart';

/// Card de viagem — usado na SearchTripsScreen e MyHistoryScreen.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
  });

  final TripModel trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sand),
          boxShadow: [
            BoxShadow(
              color: AppColors.bark.withOpacity( 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Imagem do destino ───────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _DestinationImage(destino: trip.destino),
              ),
            ),

            // ── Conteúdo ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge tipo + vagas
                  Row(
                    children: [
                      _TipoBadge(tipo: trip.tipo),
                      const Spacer(),
                      if (trip.maxVagas != null)
                        _VagasBadge(trip: trip),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Destino
                  Text(
                    trip.destino,
                    style: tt.titleLarge?.copyWith(
                      fontFamily: 'DMSerifDisplay',
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (trip.atrativo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      trip.atrativo!,
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.terra,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Datas + duração
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.barkMuted),
                      const SizedBox(width: 6),
                      Text(
                        trip.periodoFormatado,
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.barkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${trip.duracaoDias}d',
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.barkMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Descrição
                  Text(
                    trip.descricao,
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.barkMuted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Rodapé: líder + participantes
                  Row(
                    children: [
                      if (trip.lider != null) ...[
                        _LiderAvatar(lider: trip.lider!),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.lider!.name,
                            style: tt.labelMedium?.copyWith(
                              color: AppColors.bark,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(Icons.people_outline,
                          size: 14, color: AppColors.barkMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.participantesCount}',
                        style: tt.labelMedium?.copyWith(
                          color: AppColors.barkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Imagem do destino ──────────────────────────────────────────────────────────

class _DestinationImage extends StatelessWidget {
  const _DestinationImage({required this.destino});
  final String destino;

  // Gradientes por bioma brasileiro (fallback visual sem depender de API)
  static const _gradients = {
    'amazônia':  [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
    'pantanal':  [Color(0xFF4A7C59), Color(0xFF2D5A3D)],
    'nordeste':  [Color(0xFFC4622D), Color(0xFF8B3A14)],
    'cerrado':   [Color(0xFF8B6914), Color(0xFF5C4209)],
    'sul':       [Color(0xFF2D6A8F), Color(0xFF1A3F5C)],
    'serra':     [Color(0xFF5C7A3E), Color(0xFF3A5226)],
  };

  List<Color> get _gradient {
    final lower = destino.toLowerCase();
    for (final entry in _gradients.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return [AppColors.forest, AppColors.forestDk];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradiente de fundo (sempre visível como fallback)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _gradient,
            ),
          ),
        ),

        // Nome do destino centralizado no hero
        Center(
          child: Text(
            destino,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'DMSerifDisplay',
              fontSize: 22,
              color: Colors.white,
              shadows: [
                Shadow(blurRadius: 8, color: Colors.black26),
              ],
            ),
          ),
        ),

        // Overlay escuro suave na base para legibilidade
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity( 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Badges ─────────────────────────────────────────────────────────────────────

class _TipoBadge extends StatelessWidget {
  const _TipoBadge({required this.tipo});
  final TipoViagem tipo;

  @override
  Widget build(BuildContext context) {
    final isLider = tipo == TipoViagem.lider;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLider
            ? AppColors.forest.withOpacity( 0.12)
            : AppColors.terra.withOpacity( 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLider ? Icons.star_outline_rounded : Icons.explore_outlined,
            size: 12,
            color: isLider ? AppColors.forest : AppColors.terra,
          ),
          const SizedBox(width: 4),
          Text(
            tipo.label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isLider ? AppColors.forestDk : AppColors.terra,
            ),
          ),
        ],
      ),
    );
  }
}

class _VagasBadge extends StatelessWidget {
  const _VagasBadge({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final vagas = trip.vagasDisponiveis!;
    final semVagas = vagas == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: semVagas
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: semVagas
              ? const Color(0xFFFCA5A5)
              : const Color(0xFF86EFAC),
        ),
      ),
      child: Text(
        semVagas ? 'Lotado' : '$vagas vagas',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: semVagas ? AppColors.error : AppColors.forest,
        ),
      ),
    );
  }
}

// ── Avatar do líder ────────────────────────────────────────────────────────────

class _LiderAvatar extends StatelessWidget {
  const _LiderAvatar({required this.lider});
  final dynamic lider;

  @override
  Widget build(BuildContext context) {
    final foto = lider.foto as String?;
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.sand,
      backgroundImage:
          foto != null ? CachedNetworkImageProvider(foto) : null,
      child: foto == null
          ? Text(
              lider.initials as String,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.bark,
              ),
            )
          : null,
    );
  }
}
