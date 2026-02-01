import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/jobs_repository.dart';
import '../domain/job_models.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository();
});

String? _uid(Ref ref) => ref.read(authViewStateProvider).value?.user?.id;

final jobFiltersProvider = StateProvider<JobFilters>((ref) => const JobFilters());

final jobsListProvider =
    AutoDisposeAsyncNotifierProvider<JobsListController, JobsListVm>(JobsListController.new);

class JobsListController extends AutoDisposeAsyncNotifier<JobsListVm> {
  @override
  Future<JobsListVm> build() async {
    final filters = ref.watch(jobFiltersProvider);
    final repo = ref.watch(jobsRepositoryProvider);

    final uid = _uid(ref);

    // Load list + favorites in parallel (favorites only if authed)
    final futures = await Future.wait([
      repo.fetchJobs(filters: filters),
      if (uid != null && uid.isNotEmpty) repo.fetchMyFavoriteJobIds(userId: uid) else Future.value(<String>{}),
    ]);

    final items = futures[0] as List<JobSummary>;
    final favs = futures.length > 1 ? (futures[1] as Set<String>) : <String>{};

    return JobsListVm(items: items, favoriteJobIds: favs);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> toggleFavorite(String jobId) async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated');
    }

    final previous = state.value;
    if (previous == null) return;

    // optimistic UI
    final nextSet = {...previous.favoriteJobIds};
    final wasFav = nextSet.contains(jobId);
    if (wasFav) {
      nextSet.remove(jobId);
    } else {
      nextSet.add(jobId);
    }
    state = AsyncData(previous.copyWith(favoriteJobIds: nextSet));

    try {
      final repo = ref.read(jobsRepositoryProvider);
      final nowFav = await repo.toggleFavorite(userId: uid, jobId: jobId);

      // reconcile if backend result differs
      final reconcile = {...previous.favoriteJobIds};
      if (nowFav) {
        reconcile.add(jobId);
      } else {
        reconcile.remove(jobId);
      }
      state = AsyncData(previous.copyWith(favoriteJobIds: reconcile));
    } catch (e) {
      // rollback
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final jobDetailProvider = AutoDisposeAsyncNotifierProviderFamily<JobDetailController, JobDetailVm, String>(
  JobDetailController.new,
);

class JobDetailController extends AutoDisposeFamilyAsyncNotifier<JobDetailVm, String> {
  @override
  Future<JobDetailVm> build(String jobId) async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated (jobDetailProvider)');
    }

    final repo = ref.watch(jobsRepositoryProvider);

    final futures = await Future.wait([
      repo.fetchJobById(jobId: jobId),
      repo.isJobFavorited(userId: uid, jobId: jobId),
      repo.hasApplied(userId: uid, jobId: jobId),
    ]);

    return JobDetailVm(
      job: futures[0] as JobDetail,
      isFavorited: futures[1] as bool,
      hasApplied: futures[2] as bool,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> toggleFavorite() async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) throw Exception('Not authenticated');

    final current = state.value;
    if (current == null) return;

    // optimistic
    state = AsyncData(current.copyWith(isFavorited: !current.isFavorited));

    try {
      final repo = ref.read(jobsRepositoryProvider);
      final nowFav = await repo.toggleFavorite(userId: uid, jobId: arg);

      final updated = state.value;
      if (updated != null) {
        state = AsyncData(updated.copyWith(isFavorited: nowFav));
      }

      // keep list screen in sync
      ref.invalidate(jobsListProvider);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> apply({String? coverLetter, String? cvUrl}) async {
    final uid = _uid(ref);
    if (uid == null || uid.isEmpty) throw Exception('Not authenticated');

    final current = state.value;
    if (current == null) return;
    if (current.hasApplied) return;

    try {
      final repo = ref.read(jobsRepositoryProvider);
      await repo.applyToJob(
        userId: uid,
        jobId: arg,
        coverLetter: coverLetter,
        cvUrl: cvUrl,
      );

      // mark applied
      final updated = state.value;
      if (updated != null) {
        state = AsyncData(updated.copyWith(hasApplied: true));
      }
    } catch (e) {
      rethrow;
    }
  }
}
