import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shell com 4 abas: Explorar · Minhas viagens · Criar · Perfil.
class AppNotchShell extends StatefulWidget {
  const AppNotchShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static bool isChatRoute(BuildContext context) {
    return GoRouterState.of(context).uri.path.endsWith('/chat');
  }

  /// Altura do menu inferior (notch + FAB) para não cobrir botões no fim da tela.
  static double bottomBarClearance(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 92;
  }

  @override
  State<AppNotchShell> createState() => _AppNotchShellState();
}

class _AppNotchShellState extends State<AppNotchShell> {
  late final NotchBottomBarController _notchController;

  @override
  void initState() {
    super.initState();
    _notchController =
        NotchBottomBarController(index: widget.shell.currentIndex);
  }

  @override
  void didUpdateWidget(covariant AppNotchShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shell.currentIndex != _notchController.index) {
      _notchController.jumpTo(widget.shell.currentIndex);
    }
  }

  @override
  void dispose() {
    _notchController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    widget.shell.goBranch(
      index,
      initialLocation: widget.shell.currentIndex == index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hideBottomChrome = AppNotchShell.isChatRoute(context);

    return Theme(
      data: AppTheme.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: !hideBottomChrome,
        body: widget.shell,
        bottomNavigationBar: hideBottomChrome
            ? null
            : SafeArea(
                bottom: true,
                child: AnimatedNotchBottomBar(
                  notchBottomBarController: _notchController,
                  color: Colors.white,
                  notchColor: AppColors.terra,
                  showLabel: true,
                  showShadow: true,
                  removeMargins: false,
                  durationInMilliSeconds: 300,
                  itemLabelStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.barkMuted,
                  ),
                  bottomBarItems: const [
                    BottomBarItem(
                      inActiveItem: _ShellNavIcon(
                        icon: Icons.explore_outlined,
                        active: false,
                      ),
                      activeItem: _ShellNavIcon(
                        icon: Icons.explore,
                        active: true,
                      ),
                      itemLabel: 'Explorar',
                    ),
                    BottomBarItem(
                      inActiveItem: _ShellNavIcon(
                        icon: Icons.history_outlined,
                        active: false,
                      ),
                      activeItem: _ShellNavIcon(
                        icon: Icons.history,
                        active: true,
                      ),
                      itemLabel: 'Minhas',
                    ),
                    BottomBarItem(
                      inActiveItem: _ShellNavIcon(
                        icon: Icons.luggage_outlined,
                        active: false,
                      ),
                      activeItem: _ShellNavIcon(
                        icon: Icons.luggage,
                        active: true,
                      ),
                      itemLabel: 'Criar',
                    ),
                    BottomBarItem(
                      inActiveItem: _ShellNavIcon(
                        icon: Icons.person_outline,
                        active: false,
                      ),
                      activeItem: _ShellNavIcon(
                        icon: Icons.person,
                        active: true,
                      ),
                      itemLabel: 'Perfil',
                    ),
                  ],
                  onTap: _onTabTap,
                ),
              ),
      ),
    );
  }
}

/// Ícone ativo/inativo no estilo da lib (outline → preenchido + cor da marca).
class _ShellNavIcon extends StatelessWidget {
  const _ShellNavIcon({
    required this.icon,
    required this.active,
  });

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: active ? 26 : 24,
      color: active ? Colors.white : AppColors.barkMuted,
    );
  }
}
