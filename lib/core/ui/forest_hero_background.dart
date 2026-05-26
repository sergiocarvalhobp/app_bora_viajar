import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fundo verde floresta + padrão pontilhado (mesmo visual do login).
/// [showIconWatermark] exibe o ícone do app em marca d'água (útil no header da home).
class ForestHeroBackground extends StatelessWidget {
  const ForestHeroBackground({
    super.key,
    this.showIconWatermark = false,
  });

  final bool showIconWatermark;

  static const _iconAsset = 'assets/images/icon/app_icon_orange.jpg';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.forest),
        const CustomPaint(painter: ForestDotPatternPainter()),
        if (showIconWatermark)
          Center(
            child: Opacity(
              opacity: 0.14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  _iconAsset,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Padrão pontilhado decorativo (login / home).
class ForestDotPatternPainter extends CustomPainter {
  const ForestDotPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    const radius = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(ForestDotPatternPainter oldDelegate) => false;
}
