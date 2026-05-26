import '../../auth/domain/user_model.dart';

/// Avaliação de um participante sobre a viagem / organizador nesta viagem.
class OrganizerTripReview {
  const OrganizerTripReview({
    required this.stars,
    this.testemunho,
    this.rater,
    this.isMine = false,
    this.createdAt,
  });

  final int stars;
  final String? testemunho;
  final UserModel? rater;
  final bool isMine;
  final DateTime? createdAt;

  factory OrganizerTripReview.fromJson(Map<String, dynamic> json) {
    UserModel? rater;
    final raterJson = json['rater'];
    if (raterJson is Map<String, dynamic>) {
      rater = UserModel.fromJson(raterJson);
    }

    final createdRaw = json['createdAt'] ?? json['updatedAt'];
    DateTime? createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    return OrganizerTripReview(
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      testemunho: json['testemunho'] as String?,
      rater: rater,
      isMine: json['isMine'] == true,
      createdAt: createdAt,
    );
  }
}

/// Resposta de GET /trips/{id}/organizer-ratings
class OrganizerTripReviewsPage {
  const OrganizerTripReviewsPage({
    required this.reviews,
    this.organizerRating,
    this.organizerRatingCount,
    this.tripReviewCount = 0,
  });

  final List<OrganizerTripReview> reviews;
  final double? organizerRating;
  final int? organizerRatingCount;
  final int tripReviewCount;

  factory OrganizerTripReviewsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['reviews'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => OrganizerTripReview.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <OrganizerTripReview>[];

    double? avg;
    final ratingRaw = json['organizerRating'] ?? json['mediaOrganizador'];
    if (ratingRaw is num) {
      avg = ratingRaw.toDouble();
    }

    return OrganizerTripReviewsPage(
      reviews: list,
      organizerRating: avg,
      organizerRatingCount: (json['organizerRatingCount'] as num?)?.toInt(),
      tripReviewCount: (json['tripReviewCount'] as num?)?.toInt() ?? list.length,
    );
  }
}
