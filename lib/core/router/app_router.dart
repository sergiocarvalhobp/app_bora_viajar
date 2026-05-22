import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';



import '../widgets/app_notch_shell.dart';

import '../../features/auth/presentation/auth_provider.dart';

import '../../features/auth/presentation/login_screen.dart';

import '../../features/trips/presentation/search_trips_screen.dart';
import '../../features/trips/presentation/my_history_screen.dart';

import '../../features/trips/presentation/trip_details_screen.dart';

import '../../features/trips/presentation/create_trip_screen.dart';

import '../../features/chat/presentation/chat_trip_screen.dart';

import '../../features/profile/presentation/edit_profile_screen.dart';

import '../../features/profile/presentation/public_profile_screen.dart';

import '../../features/notifications/presentation/notifications_screen.dart';



part 'app_router.g.dart';



/// Navigator raiz — detalhes/chat da viagem abrem por cima do shell (evita tela branca).

final GlobalKey<NavigatorState> rootNavigatorKey =

    GlobalKey<NavigatorState>(debugLabel: 'root');



abstract final class Routes {

  static const login         = '/login';

  static const home          = '/';

  /// Fora de `/trips/:id` para não confundir `id` com a palavra "create".

  static const myTrips       = '/my-trips';
  static const createTrip    = '/create-trip';

  static const tripDetails   = '/trips/:id';

  static const tripChat      = '/trips/:id/chat';

  static const editProfile   = '/profile/edit';

  static const publicProfile = '/profile/:userId';

  static const notifications = '/notifications';

}



int? _tripIdFromParams(GoRouterState state) {

  final id = state.pathParameters['id'];

  if (id == null) return null;

  return int.tryParse(id);

}



@Riverpod(keepAlive: true)

GoRouter appRouter(Ref ref) {

  // Não use ref.watch(auth) aqui — recriaria o GoRouter a cada mudança de auth

  // e resetaria a navegação para initialLocation (bug: login → tela de viagens).

  final authRefresh = _AuthStateListenable(ref);



  return GoRouter(

    navigatorKey: rootNavigatorKey,

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



      // ── Shell: Explorar | Minhas viagens | Criar | Perfil ──────────

      StatefulShellRoute.indexedStack(

        builder: (_, __, shell) => AppNotchShell(shell: shell),

        branches: [

          // Tab 0 — Explorar

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.home,

              name: 'home',

              builder: (_, __) => const SearchTripsScreen(),

            ),

          ]),



          // Tab 1 — Minhas viagens (histórico)

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.myTrips,

              name: 'myTrips',

              builder: (_, __) => const MyHistoryScreen(),

            ),

          ]),



          // Tab 2 — Criar viagem

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.createTrip,

              name: 'createTrip',

              builder: (_, __) => const CreateTripScreen(),

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



      // ── Viagem (por cima do menu — parentNavigatorKey) ───────────────

      GoRoute(

        path: Routes.tripDetails,

        name: 'tripDetails',

        parentNavigatorKey: rootNavigatorKey,

        redirect: (_, state) {

          if (_tripIdFromParams(state) == null) return Routes.home;

          return null;

        },

        builder: (_, state) => TripDetailsScreen(

          tripId: int.parse(state.pathParameters['id']!),

        ),

        routes: [

          GoRoute(

            path: 'chat',

            name: 'tripChat',

            parentNavigatorKey: rootNavigatorKey,

            builder: (_, state) => ChatTripScreen(

              tripId: int.parse(state.pathParameters['id']!),

            ),

          ),

        ],

      ),



      // Avisos — fora do menu; acesso pelo ícone no header da home

      GoRoute(

        path: Routes.notifications,

        name: 'notifications',

        parentNavigatorKey: rootNavigatorKey,

        builder: (_, __) => const NotificationsScreen(),

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


