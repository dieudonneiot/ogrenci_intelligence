import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/internships_repository.dart';
import '../domain/internship_models.dart';

final internshipsRepositoryProvider = Provider<InternshipsRepository>((ref) {
  return const InternshipsRepository();
});

// Filters (match React)
final internshipsSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);
final internshipsLocationProvider = StateProvider.autoDispose<String>(
  (ref) => 'all',
); // all, İstanbul, Ankara, İzmir, Bursa, remote
final internshipsDurationProvider = StateProvider.autoDispose<String>(
  (ref) => 'all',
); // all, 1-3, 3-6, 6-12, 12+, 6+

String? _uid(Ref ref) => ref.read(authViewStateProvider).value?.user?.id;

final internshipsProvider =
    AutoDisposeAsyncNotifierProvider<
      InternshipsController,
      InternshipsViewModel
    >(InternshipsController.new);

class InternshipsController
    extends AutoDisposeAsyncNotifier<InternshipsViewModel> {
  @override
  Future<InternshipsViewModel> build() async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated (internshipsProvider)');
    }

    final repo = ref.read(internshipsRepositoryProvider);

    final search = ref.watch(internshipsSearchProvider);
    final loc = ref.watch(internshipsLocationProvider);
    final dur = ref.watch(internshipsDurationProvider);

    final dept = await repo.fetchMyDepartment(userId: uid);
    if (dept == null || dept.isEmpty) {
      // React: requires department (profile)
      return InternshipsViewModel.empty(
        department: null,
        departmentMissing: true,
      );
    }

    final futures = await Future.wait([
      repo.fetchInternships(
        userId: uid,
        department: dept,
        search: search,
        locationFilter: loc,
        durationFilter: dur,
      ),
      repo.fetchMyFavoriteInternshipIds(userId: uid),
      repo.fetchMyApplicationStatusByInternshipId(userId: uid),
      (() async => await SupabaseService.client
          .from('profiles')
          .select('year')
          .eq('id', uid)
          .maybeSingle())(),
      (() async => await SupabaseService.client
          .from('oi_scores')
          .select('oi_score')
          .eq('user_id', uid)
          .maybeSingle())(),
    ]);

    var internships = futures[0] as List<Internship>;
    final favoriteIds = futures[1] as Set<String>;
    final statusByInternshipId = futures[2] as Map<String, String>;
    final profileRow = futures[3] as Map<String, dynamic>?;
    final oiRow = futures[4] as Map<String, dynamic>?;

    final year = int.tryParse((profileRow?['year'] ?? '').toString());
    final oiScore = int.tryParse((oiRow?['oi_score'] ?? '').toString()) ?? 0;

    int compatibilityFor(Internship i) {
      var score = 0;

      final idept = (i.department ?? '').trim();
      if (idept.isEmpty) {
        score += 10;
      } else if (idept.toLowerCase() == dept.toLowerCase()) {
        score += 40;
      } else {
        score += 8;
      }

      // If user has a year set, slightly boost longer internships.
      // (No explicit year requirements exist in the internships schema.)
      if (year != null && year > 0) {
        if (i.durationMonths >= 6) score += 10;
        if (i.durationMonths >= 12) score += 5;
      }

      score += ((oiScore.clamp(0, 100) / 100.0) * 40).round();

      return score.clamp(0, 100);
    }

    internships =
        internships
            .map((i) => i.copyWith(compatibility: compatibilityFor(i)))
            .toList(growable: false)
          ..sort((a, b) {
            final c = b.compatibility.compareTo(a.compatibility);
            if (c != 0) return c;
            final ad = a.deadline ?? DateTime(2100);
            final bd = b.deadline ?? DateTime(2100);
            final d = ad.compareTo(bd);
            if (d != 0) return d;
            final ac = a.createdAt ?? DateTime(1970);
            final bc = b.createdAt ?? DateTime(1970);
            return bc.compareTo(ac);
          });

    final items = internships
        .map((i) {
          final status = statusByInternshipId[i.id];
          final app = status == null
              ? null
              : InternshipApplication.fromMap({
                  'id': 'local',
                  'internship_id': i.id,
                  'status': status,
                });
          return InternshipCardItem(
            internship: i,
            isFavorite: favoriteIds.contains(i.id),
            myApplication: app,
          );
        })
        .toList(growable: false);

    return InternshipsViewModel(
      department: dept,
      departmentMissing: false,
      items: items,
      appliedCount: statusByInternshipId.length,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> toggleFavorite(String internshipId) async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) return;

    final repo = ref.read(internshipsRepositoryProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    // optimistic UI
    final idx = current.items.indexWhere(
      (e) => e.internship.id == internshipId,
    );
    if (idx < 0) return;

    final before = current.items[idx];
    final updatedItem = before.copyWith(isFavorite: !before.isFavorite);
    final newItems = [...current.items];
    newItems[idx] = updatedItem;

    state = AsyncData(current.copyWith(items: newItems));

    try {
      await repo.toggleFavorite(userId: uid, internshipId: internshipId);
    } catch (e) {
      // rollback by reloading
      await refresh();
      rethrow;
    }
  }

  Future<void> markApplied(String internshipId) async {
    // helper to update list after applying in detail
    final current = state.valueOrNull;
    if (current == null) return;

    final idx = current.items.indexWhere(
      (e) => e.internship.id == internshipId,
    );
    if (idx < 0) return;

    final before = current.items[idx];
    if (before.myApplication != null) return;

    final newItems = [...current.items];
    newItems[idx] = before.copyWith(
      myApplication: InternshipApplication(
        id: 'local',
        internshipId: internshipId,
        status: InternshipApplicationStatus.pending,
        appliedAt: null,
      ),
    );

    state = AsyncData(
      current.copyWith(items: newItems, appliedCount: current.appliedCount + 1),
    );
  }
}

final internshipDetailProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      InternshipDetailController,
      InternshipDetailViewModel,
      String
    >(InternshipDetailController.new);

class InternshipDetailController
    extends AutoDisposeFamilyAsyncNotifier<InternshipDetailViewModel, String> {
  @override
  Future<InternshipDetailViewModel> build(String internshipId) async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated (internshipDetailProvider)');
    }

    final repo = ref.read(internshipsRepositoryProvider);

    final futures = await Future.wait([
      repo.fetchInternshipById(internshipId: internshipId),
      repo.isFavorite(userId: uid, internshipId: internshipId),
      repo.fetchMyApplication(userId: uid, internshipId: internshipId),
    ]);

    final internship = futures[0] as Internship;

    final isFav = futures[1] as bool;
    final myApp = futures[2] as InternshipApplication?;

    return InternshipDetailViewModel(
      item: InternshipCardItem(
        internship: internship,
        isFavorite: isFav,
        myApplication: myApp,
      ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> toggleFavorite() async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) return;

    final repo = ref.read(internshipsRepositoryProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final internshipId = current.item.internship.id;

    // optimistic
    state = AsyncData(
      InternshipDetailViewModel(
        item: current.item.copyWith(isFavorite: !current.item.isFavorite),
      ),
    );

    try {
      await repo.toggleFavorite(userId: uid, internshipId: internshipId);

      // keep list in sync
      ref.invalidate(internshipsProvider);
    } catch (e) {
      await refresh();
      rethrow;
    }
  }

  Future<void> apply(String motivation) async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) return;

    final repo = ref.read(internshipsRepositoryProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final internshipId = current.item.internship.id;

    await repo.apply(
      userId: uid,
      internshipId: internshipId,
      motivation: motivation,
    );

    // optimistic list update
    await ref.read(internshipsProvider.notifier).markApplied(internshipId);

    // re-fetch application, show status pill
    final app = await repo.fetchMyApplication(
      userId: uid,
      internshipId: internshipId,
    );

    state = AsyncData(
      InternshipDetailViewModel(
        item: current.item.copyWith(myApplication: app),
      ),
    );

    // keep list badges in sync
    ref.invalidate(internshipsProvider);
  }
}
