import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra de 1–5 estrelas para o participante avaliar quem criou a viagem.
class InteractiveOrganizerRating extends StatelessWidget {
  const InteractiveOrganizerRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= value;
        return IconButton(
          onPressed: enabled ? () => onChanged(star) : null,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled ? AppColors.terra : AppColors.sand,
          ),
        );
      }),
    );
  }
}
