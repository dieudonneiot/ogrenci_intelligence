import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/internships_repository.dart';
import '../domain/internship_models.dart';

final internshipsRepositoryProvider = Provider<InternshipsRepository>((ref) {
  return const InternshipsRepository();
});

// Filters (match React)
final internshipsSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final internshipsLocationProvider = StateProvider.autoDispose<String>((ref) => 'all'); // all, İstanbul, Ankara, İzmir, Bursa
final internshipsDurationProvider = StateProvider.autoDispose<String>((ref) => 'all'); // all, 1-3, 3-6, 6-12, 12+

String? _uid(Ref ref) => ref.read(authViewStateProvider).value?.user?.id;

final internshipsProvider =
    AutoDisposeAsyncNotifierProvider<InternshipsController, InternshipsViewModel>(
  InternshipsController.new,
);

class InternshipsController extends AutoDisposeAsyncNotifier<InternshipsViewModel> {
  @override
  Future<InternshipsViewModel> build() async {
    final uid = _uid(ref);
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
      return InternshipsViewModel.empty(department: null, departmentMissing: true);
    }

    final futures = await Future.wait([
      repo.fetchInternships(
        department: dept,
        search: search,
        selectedLocation: loc,
        selectedDuration: dur,
      ),
      repo.fetchFavoriteInternshipIds(userId: uid),
      repo.fetchMyApplicationsByInternshipId(userId: uid),
    ]);

    final internships = futures[0] as List<Internship>;
    final favoriteIds = futures[1] as Set<String>;
    final appsByInternshipId = futures[2] as Map<String, InternshipApplication>;

    final items = internships
        .map((i) => InternshipCardItem(
              internship: i,
              isFavorite: favoriteIds.contains(i.id),
              myApplication: appsByInternshipId[i.id],
            ))
        .toList(growable: false);

    return InternshipsViewModel(
      department: dept,
      departmentMissing: false,
      items: items,
      appliedCount: appsByInternshipId.length,
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
    final idx = current.items.indexWhere((e) => e.internship.id == internshipId);
    if (idx < 0) return;

    final before = current.items[idx];
    final updatedItem = before.copyWith(isFavorite: !before.isFavorite);
    final newItems = [...current.items];
    newItems[idx] = updatedItem;

    state = AsyncData(current.copyWith(items: newItems));

    try {
      await repo.toggleFavorite(userId: uid, internshipId: internshipId);
    } catch (e) {
      // rollback
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> markApplied(String internshipId) async {
    // helper to update list after applying in detail
    final current = state.valueOrNull;
    if (current == null) return;

    final idx = current.items.indexWhere((e) => e.internship.id == internshipId);
    if (idx < 0) return;

    final before = current.items[idx];
    if (before.myApplication != null) return;

    final newItems = [...current.items];
    newItems[idx] = before.copyWith(
      myApplication: const InternshipApplication(
        id: 'local',
        internshipId: '',
        status: InternshipApplicationStatus.pending,
        appliedAt: null,
      ),
    );

    state = AsyncData(current.copyWith(items: newItems, appliedCount: current.appliedCount + 1));
  }
}

final internshipDetailProvider = AutoDisposeAsyncNotifierProviderFamily<
    InternshipDetailController, InternshipDetailViewModel, String>(
  InternshipDetailController.new,
);

class InternshipDetailController
    extends AutoDisposeFamilyAsyncNotifier<InternshipDetailViewModel, String> {
  @override
  Future<InternshipDetailViewModel> build(String internshipId) async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated (internshipDetailProvider)');
    }

    final repo = ref.read(internshipsRepositoryProvider);

    final futures = await Future.wait([
      repo.fetchInternshipById(internshipId: internshipId),
      repo.isFavorite(userId: uid, internshipId: internshipId),
      repo.fetchMyApplication(userId: uid, internshipId: internshipId),
    ]);

    final internship = futures[0] as Internship?;
    if (internship == null) throw Exception('Staj bulunamadı');

    final isFav = futures[1] as bool;
    final myApp = futures[2] as InternshipApplication?;

    return InternshipDetailViewModel(
      item: InternshipCardItem(internship: internship, isFavorite: isFav, myApplication: myApp),
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
      ref.read(internshipsProvider.notifier).toggleFavorite(internshipId);
    } catch (e) {
      state = AsyncData(current);
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

    await repo.applyToInternship(
      userId: uid,
      internshipId: internshipId,
      motivationLetter: motivation,
    );

    // refresh detail + list
    ref.invalidate(internshipsProvider);
    await refresh();
  }
}
