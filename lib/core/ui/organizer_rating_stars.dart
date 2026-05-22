import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Exibe de 0 a 5 estrelas (média das viagens que o usuário criou, na API).
class OrganizerRatingStars extends StatelessWidget {
  const OrganizerRatingStars({
    super.key,
    this.rating,
    this.ratingCount,
    this.size = 22,
    this.emptyLabel = 'Ainda sem avaliações das viagens que criou',
    this.filledLabelPrefix = 'Média das viagens que criou',
  });

  /// Média 0–5; `null` = ainda sem avaliações na API.
  final double? rating;
  final int? ratingCount;
  final double size;
  final String emptyLabel;
  final String filledLabelPrefix;

  @override
  Widget build(BuildContext context) {
    final value = rating;
    const labelStyle = TextStyle(
      fontFamily: 'Nunito',
      fontSize: 12,
      color: AppColors.barkMuted,
      fontWeight: FontWeight.w600,
    );

    if (value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StarRow(filled: 0, size: size),
          const SizedBox(height: 4),
          Text(emptyLabel, style: labelStyle),
        ],
      );
    }

    final rounded = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 1,
    );
    final countSuffix = ratingCount != null && ratingCount! > 0
        ? ' · $ratingCount ${ratingCount == 1 ? 'avaliação' : 'avaliações'}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StarRow(filled: value, size: size),
        const SizedBox(height: 4),
        Text(
          '$filledLabelPrefix: $rounded de 5$countSuffix',
          style: labelStyle,
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.filled, required this.size});

  /// Valor 0–5 (pode ter decimais para meia estrela).
  final double filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final index = i + 1;
        IconData icon;
        if (filled >= index) {
          icon = Icons.star_rounded;
        } else if (filled >= index - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 2 : 0),
          child: Icon(
            icon,
            size: size,
            color: filled >= index - 0.5
                ? AppColors.terra
                : AppColors.sand,
          ),
        );
      }),
    );
  }
}
