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

// ---------------- New jobs flow (JobsFilters + JobsViewModel) ----------------

final jobsFiltersProvider = StateProvider.autoDispose<JobsFilters>((ref) {
  return const JobsFilters();
});

final jobsProvider =
    AutoDisposeAsyncNotifierProvider<JobsController, JobsViewModel>(JobsController.new);

class JobsController extends AutoDisposeAsyncNotifier<JobsViewModel> {
  @override
  Future<JobsViewModel> build() async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated (jobsProvider)');
    }

    final filters = ref.watch(jobsFiltersProvider);
    final repo = ref.watch(jobsRepositoryProvider);

    final futures = await Future.wait([
      repo.fetchJobsRaw(filters: filters),
      repo.fetchMyFavoriteJobIds(userId: uid),
      repo.fetchMyJobApplicationStatuses(userId: uid),
    ]);

    final jobs = futures[0] as List<Job>;
    final favs = futures[1] as Set<String>;
    final applied = futures[2] as Map<String, String>;

    final items = jobs
        .map((j) => JobCardVM(
              job: j,
              isFavorite: favs.contains(j.id),
              applicationStatus: applied[j.id],
            ))
        .toList(growable: false);

    final departments = jobs
        .map((j) => j.department.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final workTypes = jobs
        .map((j) => j.workType.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return JobsViewModel(
      items: items,
      availableDepartments: departments,
      availableWorkTypes: workTypes,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> toggleFavorite(String jobId) async {
    final auth = ref.read(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) return;

    final repo = ref.read(jobsRepositoryProvider);
    final current = state.valueOrNull;
    if (current == null) {
      await refresh();
      return;
    }

    final idx = current.items.indexWhere((e) => e.job.id == jobId);
    if (idx < 0) return;

    final wasFav = current.items[idx].isFavorite;

    final nextItems = [...current.items];
    nextItems[idx] = JobCardVM(
      job: nextItems[idx].job,
      isFavorite: !wasFav,
      applicationStatus: nextItems[idx].applicationStatus,
    );
    state = AsyncData(
      JobsViewModel(
        items: nextItems,
        availableDepartments: current.availableDepartments,
        availableWorkTypes: current.availableWorkTypes,
      ),
    );

    try {
      if (wasFav) {
        await repo.removeJobFavorite(userId: uid, jobId: jobId);
      } else {
        await repo.addJobFavorite(userId: uid, jobId: jobId);
      }
    } catch (_) {
      await refresh();
      rethrow;
    }
  }
}

final jobDetailViewProvider = AutoDisposeAsyncNotifierProviderFamily<
    JobDetailViewController, JobDetailViewModel, String>(JobDetailViewController.new);

class JobDetailViewController
    extends AutoDisposeFamilyAsyncNotifier<JobDetailViewModel, String> {
  @override
  Future<JobDetailViewModel> build(String jobId) async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated (jobDetailProvider)');
    }

    final repo = ref.watch(jobsRepositoryProvider);

    final job = await repo.fetchJobByIdRaw(jobId: jobId);
    if (job == null) throw Exception('Job not found');

    final favs = await repo.fetchMyFavoriteJobIds(userId: uid);
    final status = await repo.fetchMyJobApplicationStatusForJob(userId: uid, jobId: jobId);

    return JobDetailViewModel(
      job: job,
      isFavorite: favs.contains(jobId),
      applicationStatus: status,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> toggleFavorite() async {
    final auth = ref.read(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) return;

    final repo = ref.read(jobsRepositoryProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final wasFav = current.isFavorite;

    state = AsyncData(JobDetailViewModel(
      job: current.job,
      isFavorite: !wasFav,
      applicationStatus: current.applicationStatus,
    ));

    try {
      if (wasFav) {
        await repo.removeJobFavorite(userId: uid, jobId: current.job.id);
      } else {
        await repo.addJobFavorite(userId: uid, jobId: current.job.id);
      }
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  Future<void> apply(String coverLetter) async {
    final auth = ref.read(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) return;

    final repo = ref.read(jobsRepositoryProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    await repo.applyToJob(userId: uid, jobId: current.job.id, coverLetter: coverLetter);

    // After apply, refresh to get status from DB (pending)
    await refresh();
  }
}
