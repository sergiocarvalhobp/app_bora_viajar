import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../theme/app_colors.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/trips/presentation/search_trips_screen.dart';
import '../../features/trips/presentation/trip_details_screen.dart';
import '../../features/trips/presentation/create_trip_screen.dart';
import '../../features/trips/presentation/my_history_screen.dart';
import '../../features/chat/presentation/chat_trip_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/public_profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

part 'app_router.g.dart';

abstract final class Routes {
  static const login         = '/login';
  static const home          = '/';
  static const createTrip    = '/trips/create';
  static const tripDetails   = '/trips/:id';
  static const tripChat      = '/trips/:id/chat';
  static const myHistory     = '/my-history';
  static const editProfile   = '/profile/edit';
  static const publicProfile = '/profile/:userId';
  static const notifications = '/notifications';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Não use ref.watch(auth) aqui — recriaria o GoRouter a cada mudança de auth
  // e resetaria a navegação para initialLocation (bug: login → tela de viagens).
  final authRefresh = _AuthStateListenable(ref);

  return GoRouter(
    initialLocation: Routes.login,
    debugLogDiagnostics: false,
    refreshListenable: authRefresh,

    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoading = authState is AuthLoading;
      final isAuth = authState is AuthAuthenticated;
      final onLogin = state.matchedLocation == Routes.login;

      // Enquanto verifica sessão ou faz login: só fica na tela de login.
      if (isLoading) return onLogin ? null : Routes.login;

      if (!isAuth && !onLogin) return Routes.login;
      if (isAuth && onLogin) return Routes.home;
      return null;
    },

    routes: [
      // ── Login ───────────────────────────────────────────────────────
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Shell com bottom nav ─────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => _AppShell(shell: shell),
        branches: [
          // Tab 0 — Explorar
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              name: 'home',
              builder: (_, __) => const SearchTripsScreen(),
              routes: [
                GoRoute(
                  path: 'trips/create',
                  name: 'createTrip',
                  builder: (_, __) => const CreateTripScreen(),
                ),
                GoRoute(
                  path: 'trips/:id',
                  name: 'tripDetails',
                  builder: (_, state) => TripDetailsScreen(
                    tripId: int.parse(state.pathParameters['id']!)),
                  routes: [
                    GoRoute(
                      path: 'chat',
                      name: 'tripChat',
                      builder: (_, state) => ChatTripScreen(
                        tripId: int.parse(state.pathParameters['id']!)),
                    ),
                  ],
                ),
              ],
            ),
          ]),

          // Tab 1 — Minhas viagens
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.myHistory,
              name: 'myHistory',
              builder: (_, __) => const MyHistoryScreen(),
            ),
          ]),

          // Tab 2 — Notificações
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.notifications,
              name: 'notifications',
              builder: (_, __) => const NotificationsScreen(),
            ),
          ]),

          // Tab 3 — Perfil
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              redirect: (_, __) => Routes.editProfile,
              routes: [
                GoRoute(
                  path: 'edit',
                  name: 'editProfile',
                  builder: (_, __) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: ':userId',
                  name: 'publicProfile',
                  builder: (_, state) => PublicProfileScreen(
                    userId: int.parse(state.pathParameters['userId']!),
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Página não encontrada: ${state.uri}')),
    ),
  );
}

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  /// Chat precisa do rodapé livre para o campo de mensagem (sem FAB/nav).
  static bool _isChatRoute(BuildContext context) {
    return GoRouterState.of(context).uri.path.endsWith('/chat');
  }

  @override
  Widget build(BuildContext context) {
    final hideBottomChrome = _isChatRoute(context);

    // Menu sempre branco — não herda surface escura do ThemeMode.system (dark).
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: Color(0x1A000000),
        ),
      ),
      child: Scaffold(
      backgroundColor: Colors.white,
      extendBody: !hideBottomChrome,
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: hideBottomChrome
          ? null
          : Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: SizedBox(
          width: 76,
          height: 76,
          child: FloatingActionButton(
            onPressed: () => context.push(Routes.createTrip),
            backgroundColor: AppColors.terra,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, size: 34),
          ),
        ),
      ),
      bottomNavigationBar: hideBottomChrome
          ? null
          : Material(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x1A000000),
        child: SafeArea(
          top: false,
          child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: _ShellNavItem(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore,
                  label: 'Explorar',
                  isSelected: shell.currentIndex == 0,
                  onTap: () => shell.goBranch(
                    0,
                    initialLocation: shell.currentIndex == 0,
                  ),
                ),
              ),
              Expanded(
                child: _ShellNavItem(
                  icon: Icons.luggage_outlined,
                  selectedIcon: Icons.luggage,
                  label: 'Minhas',
                  isSelected: shell.currentIndex == 1,
                  onTap: () => shell.goBranch(
                    1,
                    initialLocation: shell.currentIndex == 1,
                  ),
                ),
              ),
              const SizedBox(width: 72),
              Expanded(
                child: _ShellNavItem(
                  icon: Icons.notifications_outlined,
                  selectedIcon: Icons.notifications,
                  label: 'Avisos',
                  isSelected: shell.currentIndex == 2,
                  onTap: () => shell.goBranch(
                    2,
                    initialLocation: shell.currentIndex == 2,
                  ),
                ),
              ),
              Expanded(
                child: _ShellNavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Perfil',
                  isSelected: shell.currentIndex == 3,
                  onTap: () => shell.goBranch(
                    3,
                    initialLocation: shell.currentIndex == 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isSelected ? AppColors.forest : AppColors.barkMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? selectedIcon : icon, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
