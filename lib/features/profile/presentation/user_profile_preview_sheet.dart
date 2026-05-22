import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/avatar_image_provider.dart';
import '../../../core/ui/organizer_rating_stars.dart';
import '../../auth/domain/user_model.dart';
import 'public_profile_screen.dart';

/// Abre resumo do viajante (sem e-mail, telefone ou outros dados sensíveis).
void showUserProfilePreviewSheet(
  BuildContext context,
  WidgetRef ref, {
  required UserModel user,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UserProfilePreviewSheet(userId: user.id, initial: user),
  );
}

class _UserProfilePreviewSheet extends ConsumerWidget {
  const _UserProfilePreviewSheet({
    required this.userId,
    required this.initial,
  });

  final int userId;
  final UserModel initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfilePageProvider(userId));

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.68,
      expand: false,
      builder: (_, scrollController) {
        return Material(
          color: AppColors.cream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: profileAsync.when(
            loading: () => _SheetBody(
              scrollController: scrollController,
              user: initial,
              isLoading: true,
            ),
            error: (_, __) => _SheetBody(
              scrollController: scrollController,
              user: initial,
            ),
            data: (bundle) => _SheetBody(
              scrollController: scrollController,
              user: bundle.user,
            ),
          ),
        );
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.scrollController,
    required this.user,
    this.isLoading = false,
  });

  final ScrollController scrollController;
  final UserModel user;
  final bool isLoading;

  String? get _localizacao {
    final parts = [user.cidade, user.estado].whereType<String>().toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bio = user.bio?.trim();
    final hasBio = bio != null && bio.isNotEmpty;
    final instagram = user.instagram?.trim();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.sand,
              backgroundImage: avatarImageProvider(user.foto),
              child: user.foto == null
                  ? Text(
                      user.initials,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.bark,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontFamily: 'DMSerifDisplay',
                      fontSize: 22,
                      color: AppColors.bark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Criador da viagem',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OrganizerRatingStars(
                    rating: user.organizerRating,
                    ratingCount: user.organizerRatingCount,
                    filledLabelPrefix: 'Média das viagens que criou',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.forest,
                ),
              ),
            ),
          )
        else ...[
          Text(
            hasBio ? bio : 'Este viajante ainda não adicionou uma descrição.',
            style: tt.bodyMedium?.copyWith(
              color: AppColors.barkMuted,
              height: 1.55,
              fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          if (_localizacao != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.barkMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _localizacao!,
                    style: tt.bodyMedium?.copyWith(
                      color: AppColors.bark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (instagram != null && instagram.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.alternate_email_rounded,
                  size: 18,
                  color: AppColors.terra,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    instagram.startsWith('@') ? instagram : '@$instagram',
                    style: tt.bodyMedium?.copyWith(
                      color: AppColors.terra,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
