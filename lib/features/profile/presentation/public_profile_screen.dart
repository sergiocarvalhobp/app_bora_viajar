import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/domain/user_model.dart';
import '../../trips/domain/trip_model.dart';
import '../../trips/widgets/trip_card.dart';

part 'public_profile_screen.g.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

@riverpod
Future<UserModel> publicProfile(Ref ref, int userId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get(
      trpcUrl('users.buscarPorId'),
      queryParameters: {'input': '{"json":{"userId":$userId}}'},
    );
    dynamic raw = res.data;
    if (raw is List) raw = raw.first;
    final data = raw['result']?['data']?['json'] ?? raw['result']?['data'];
    return UserModel.fromJson(data as Map<String, dynamic>);
  } catch (e) {
    throw ErrorHandler.handle(e);
  }
}

@riverpod
Future<List<TripModel>> userPublicTrips(Ref ref, int userId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get(
      trpcUrl('viagens.listarPorUsuario'),
      queryParameters: {'input': '{"json":{"userId":$userId}}'},
    );
    dynamic raw = res.data;
    if (raw is List) raw = raw.first;
    final data = raw['result']?['data']?['json'] ?? raw['result']?['data'];
    if (data is! List) return [];
    return data
        .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw ErrorHandler.handle(e);
  }
}

// ── Tela ───────────────────────────────────────────────────────────────────────

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final tripsAsync   = ref.watch(userPublicTripsProvider(userId));

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(child: Text('Erro: $e')),
      ),
      data: (user) => _ProfileBody(
          user: user, tripsAsync: tripsAsync),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user, required this.tripsAsync});
  final UserModel user;
  final AsyncValue<List<TripModel>> tripsAsync;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.forest, AppColors.forestDk],
                      ),
                    ),
                  ),
                  // Avatar centralizado
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white24,
                          backgroundImage: user.foto != null
                              ? CachedNetworkImageProvider(user.foto!)
                              : null,
                          child: user.foto == null
                              ? Text(user.initials,
                                  style: const TextStyle(
                                      fontFamily: 'Nunito', fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome + badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(user.name,
                          style: const TextStyle(
                              fontFamily: 'DMSerifDisplay', fontSize: 26,
                              color: AppColors.bark)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.forest.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text('Viajante',
                            style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppColors.forestDk)),
                      ),
                    ],
                  ),

                  // Localização
                  if (user.estado != null || user.cidade != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.barkMuted),
                      const SizedBox(width: 4),
                      Text(
                        [user.cidade, user.estado]
                            .whereType<String>()
                            .join(', '),
                        style: tt.bodySmall?.copyWith(
                            color: AppColors.barkMuted),
                      ),
                    ]),
                  ],

                  // Bio
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(user.bio!,
                        style: tt.bodyMedium?.copyWith(
                            color: AppColors.barkMuted, height: 1.6)),
                  ],

                  // Instagram
                  if (user.instagram != null && user.instagram!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.alternate_email_rounded,
                          size: 14, color: AppColors.terra),
                      const SizedBox(width: 4),
                      Text(user.instagram!,
                          style: tt.bodySmall?.copyWith(
                              color: AppColors.terra,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],

                  const SizedBox(height: 28),
                  const Divider(color: AppColors.sand, height: 1),
                  const SizedBox(height: 20),

                  // Viagens públicas
                  Text('Viagens de ${user.name.split(' ').first}',
                      style: tt.headlineSmall),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Lista de viagens
          tripsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.forest),
              )),
            ),
            error: (_, __) => const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Não foi possível carregar as viagens.',
                    style: TextStyle(fontFamily: 'Nunito',
                        color: AppColors.barkMuted)),
              )),
            ),
            data: (trips) {
              if (trips.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Text(
                      '${user.name.split(' ').first} ainda não publicou nenhuma viagem.',
                      style: tt.bodyMedium?.copyWith(color: AppColors.barkMuted),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TripCard(
                        trip: trips[i],
                        onTap: () => context.push('/trips/${trips[i].id}'),
                      ),
                    ),
                    childCount: trips.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
