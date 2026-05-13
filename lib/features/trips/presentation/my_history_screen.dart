import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../data/trips_repository.dart';
import '../domain/trip_model.dart';
import '../widgets/trip_card.dart';

part 'my_history_screen.g.dart';

// ── Tabs ───────────────────────────────────────────────────────────────────────

enum HistoryTab { participando, liderando, todas }

extension HistoryTabExt on HistoryTab {
  String get label => switch (this) {
    HistoryTab.participando => 'Participando',
    HistoryTab.liderando    => 'Liderando',
    HistoryTab.todas        => 'Todas',
  };
}

// ── Provider ───────────────────────────────────────────────────────────────────

@riverpod
Future<List<TripModel>> myTrips(Ref ref) async {
  final repo = ref.watch(tripsRepositoryProvider);
  return repo.minhasViagens();
}

// ── Tela ───────────────────────────────────────────────────────────────────────

class MyHistoryScreen extends ConsumerStatefulWidget {
  const MyHistoryScreen({super.key});
  @override
  ConsumerState<MyHistoryScreen> createState() => _MyHistoryScreenState();
}

class _MyHistoryScreenState extends ConsumerState<MyHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Minhas viagens',
            style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/trips/create'),
            tooltip: 'Criar viagem',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w500, fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: HistoryTab.values
              .map((t) => Tab(text: t.label))
              .toList(),
        ),
      ),
      body: tripsAsync.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e.toString()),
        data: (trips) => TabBarView(
          controller: _tabController,
          children: [
            _TripsList(
              trips:  trips.where((t) => t.myStatus != null).toList(),
              label:  'Você ainda não está participando de nenhuma viagem.',
            ),
            _TripsList(
              trips:  trips.where((t) => t.isLider == true).toList(),
              label:  'Você ainda não criou nenhuma viagem.',
            ),
            _TripsList(
              trips:  trips,
              label:  'Nenhuma viagem encontrada.',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/create'),
        backgroundColor: AppColors.terra,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Criar viagem',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: AppColors.sand,
          highlightColor: Colors.white,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.barkMuted),
            const SizedBox(height: 16),
            const Text('Não foi possível carregar suas viagens',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 20,
                    color: AppColors.bark)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(myTripsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  const _TripsList({required this.trips, required this.label});
  final List<TripModel> trips;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.luggage_outlined,
                  size: 64, color: AppColors.sand),
              const SizedBox(height: 16),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                      color: AppColors.barkMuted)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => GoRouter.of(context).push('/trips/create'),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Criar viagem'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.forest,
      onRefresh: () async =>
          GoRouter.of(context).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: trips.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TripCard(
            trip:  trips[i],
            onTap: () => GoRouter.of(context).push('/trips/${trips[i].id}'),
          ),
        ),
      ),
    );
  }
}

// Extensão helper para verificar se o usuário é líder
extension TripModelHelper on TripModel {
  bool? get isLider => myStatus == null ? true : null;
}
