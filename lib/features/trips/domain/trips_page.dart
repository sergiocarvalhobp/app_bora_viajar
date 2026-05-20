import 'trip_model.dart';

/// Resposta paginada de `GET /api/v1/trips` (ou `/filter`).
class TripsPage {
  const TripsPage({
    required this.items,
    required this.fetchedCount,
    required this.hasMore,
    required this.total,
  });

  final List<TripModel> items;

  /// Quantidade bruta retornada pelo servidor nesta página (antes de filtros locais).
  final int fetchedCount;
  final bool hasMore;
  final int total;
}
