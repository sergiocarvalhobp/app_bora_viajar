import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../presentation/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    // Navega para home quando autenticado
    ref.listen(authNotifierProvider, (_, next) {
      if (next is AuthAuthenticated) {
        context.go('/');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.forest,
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero superior ─────────────────────────────────────────
            Expanded(
              flex: 5,
              child: _HeroSection(),
            ),

            // ── Card inferior com botões ───────────────────────────────
            Expanded(
              flex: 4,
              child: _LoginCard(
                isLoading: isLoading,
                error: authState is AuthError ? authState.message : null,
                onGoogleLogin: () =>
                    ref.read(authNotifierProvider.notifier).loginWithGoogle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Section ───────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fundo verde floresta com padrão sutil
        Container(color: AppColors.forest),

        // Overlay com padrão pontilhado decorativo
        CustomPaint(painter: _DotPatternPainter()),

        // Conteúdo central
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone de mapa/viagem
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity( 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              // Logo — DM Serif Display
              const Text(
                'Bora Viajar',
                style: TextStyle(
                  fontFamily: 'DMSerifDisplay',
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              Text(
                'Conecte-se com pessoas que\nplanejam a mesma viagem pelo Brasil.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity( 0.85),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Destinos em destaque — chips decorativos
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _DestinationChip('Amazônia'),
                  _DestinationChip('Pantanal'),
                  _DestinationChip('Nordeste'),
                  _DestinationChip('Cerrado'),
                  _DestinationChip('Sul'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationChip extends StatelessWidget {
  const _DestinationChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity( 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withOpacity( 0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Login Card ─────────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.isLoading,
    required this.onGoogleLogin,
    this.error,
  });

  final bool isLoading;
  final VoidCallback onGoogleLogin;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título
          const Text(
            'Comece sua aventura',
            style: TextStyle(
              fontFamily: 'DMSerifDisplay',
              fontSize: 26,
              color: AppColors.bark,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Entre com sua conta Google para encontrar\ncompanheiros de viagem.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: AppColors.barkMuted,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 28),

          // Botão Google
          _GoogleSignInButton(
            isLoading: isLoading,
            onPressed: isLoading ? null : onGoogleLogin,
          ),

          // Mensagem de erro
          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _friendlyError(error!)),
          ],

          const Spacer(),

          // Termos
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Ao entrar, você concorda com os nossos\nTermos de Uso e Política de Privacidade.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: AppColors.barkMuted.withOpacity( 0.7),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('cancelado') || raw.contains('cancel')) {
      return 'Login cancelado. Tente novamente quando quiser.';
    }
    if (raw.contains('rede') || raw.contains('network') || raw.contains('connection')) {
      return 'Sem conexão. Verifique sua internet e tente novamente.';
    }
    if (raw.contains('sessão') || raw.contains('auth')) {
      return 'Erro de autenticação. Tente novamente.';
    }
    return 'Algo deu errado. Tente novamente.';
  }
}

// ── Botão Google ───────────────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.bark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.sand, width: 1.5),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.forest),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Google em SVG inline
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continuar com Google',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bark,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Logo do Google desenhado com CustomPainter (sem depender de assets externos).
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // Arcos coloridos do logo Google
    const colors = [
      Color(0xFF4285F4), // Azul
      Color(0xFF34A853), // Verde
      Color(0xFFFBBC05), // Amarelo
      Color(0xFFEA4335), // Vermelho
    ];

    final sweeps = [90.0, 90.0, 90.0, 90.0];
    final starts = [-30.0, 60.0, 150.0, 240.0];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.2
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.7),
        starts[i] * 3.14159 / 180,
        sweeps[i] * 3.14159 / 180,
        false,
        paint,
      );
    }

    // "G" central — barra horizontal
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.7, cy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}

// ── Banner de erro ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: Color(0xFF991B1B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Padrão pontilhado decorativo ───────────────────────────────────────────────

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity( 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    const radius  = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter old) => false;
}
