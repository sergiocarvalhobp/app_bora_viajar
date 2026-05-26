import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app_constants.dart';
import '../../../core/router/trip_navigation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/bv_forest_app_bar.dart';
import '../../../core/ui/forest_hero_background.dart';
import '../../../core/ui/avatar_image_provider.dart';
import '../../../core/ui/organizer_rating_stars.dart';
import '../../auth/domain/user_model.dart';
import '../../trips/domain/trip_model.dart';
import '../../trips/widgets/trip_card.dart';

part 'public_profile_screen.g.dart';

/// Um único `GET /api/v1/profile/public/{userId}` devolve perfil + listas de viagens.
@riverpod
Future<({List<TripModel> trips, UserModel user})> publicProfilePage(
    Ref ref, int userId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get('${AppConstants.restApiPrefix}/profile/public/$userId');
    final map = res.data as Map<String, dynamic>;
    final user = UserModel.fromJson(map);
    final rawTrips = map['viagens'] as List<dynamic>? ?? [];
    final trips = rawTrips
        .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return (trips: trips, user: user);
  } catch (e) {
    throw ErrorHandler.handle(e);
  }
}

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicProfilePageProvider(userId));

    return async.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      ),
      error: (e, _) => Scaffold(
        appBar: const BvForestAppBar(title: 'Perfil'),
        body: Center(child: Text('Erro: $e')),
      ),
      data: (bundle) => _ProfileBody(user: bundle.user, trips: bundle.trips),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user, required this.trips});
  final UserModel user;
  final List<TripModel> trips;

  @override
  Widget build(BuildContext context) {
    final tt = context.appText;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const ForestHeroBackground(),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white24,
                          backgroundImage: avatarImageProvider(user.foto),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          color: AppColors.forest.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text('Viajante',
                            style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppColors.forestDk)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OrganizerRatingStars(
                    rating: user.organizerRating,
                    ratingCount: user.organizerRatingCount,
                    filledLabelPrefix: 'Média das viagens que criou',
                  ),
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
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(user.bio!,
                        style: tt.bodyMedium?.copyWith(
                            color: AppColors.barkMuted, height: 1.6)),
                  ],
                  if (user.instagramHandle != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.alternate_email_rounded,
                          size: 14, color: AppColors.terra),
                      const SizedBox(width: 4),
                      Text(user.instagramHandle!,
                          style: tt.bodySmall?.copyWith(
                              color: AppColors.terra,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                  const SizedBox(height: 28),
                  const Divider(color: AppColors.sand, height: 1),
                  const SizedBox(height: 20),
                  Text('Viagens de ${user.name.split(' ').first}',
                      style: tt.headlineSmall),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (trips.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Text(
                  '${user.name.split(' ').first} ainda não publicou nenhuma viagem.',
                  style: tt.bodyMedium?.copyWith(color: AppColors.barkMuted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TripCard(
                      trip: trips[i],
                      onTap: () => openTripDetails(context, trips[i].id),
                    ),
                  ),
                  childCount: trips.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
