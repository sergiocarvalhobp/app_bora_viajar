import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boraviajar_app/app.dart';
import 'package:boraviajar_app/features/trips/data/trips_repository.dart';
import 'package:boraviajar_app/features/trips/domain/trip_model.dart';

class _FakeTripsRepository extends TripsRepository {
  _FakeTripsRepository() : super(dio: Dio());

  @override
  Future<List<TripModel>> listar(TripFilters filters) async => [];
}

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripsRepositoryProvider.overrideWith((ref) => _FakeTripsRepository()),
        ],
        child: const BoraViajarApp(),
      ),
    );

    expect(find.byType(BoraViajarApp), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
