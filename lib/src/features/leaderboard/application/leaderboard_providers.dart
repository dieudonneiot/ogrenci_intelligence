import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_models.dart';

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return const LeaderboardRepository();
});

final leaderboardProvider =
    AutoDisposeAsyncNotifierProvider<
      LeaderboardController,
      LeaderboardViewModel
    >(LeaderboardController.new);

class LeaderboardController
    extends AutoDisposeAsyncNotifier<LeaderboardViewModel> {
  @override
  Future<LeaderboardViewModel> build() async {
    return _load();
  }

  Future<LeaderboardViewModel> _load() async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;

    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated (leaderboardProvider)');
    }

    final repo = ref.read(leaderboardRepositoryProvider);

    final myProfile = await repo.fetchMyProfile(userId: uid);
    final myDept = (myProfile?['department'] as String?)?.trim();
    final myTotal = _asInt(myProfile?['total_points']);

    // Fetch lists in parallel (tabs feel instant)
    final futures = await Future.wait<List<LeaderboardEntry>>([
      repo.fetchOverall(limit: 50),
      if (myDept != null && myDept.isNotEmpty)
        repo.fetchByDepartment(department: myDept, limit: 50),
    ]);

    final overall = futures[0];
    final deptList = futures.length > 1 ? futures[1] : <LeaderboardEntry>[];

    final overallRank = overall
        .where((e) => e.userId == uid)
        .map((e) => e.rank)
        .firstOrNull;
    final deptRank = deptList
        .where((e) => e.userId == uid)
        .map((e) => e.rank)
        .firstOrNull;

    return LeaderboardViewModel(
      meId: uid,
      totalPoints: myTotal,
      overallRank: overallRank,
      departmentRank: deptRank,
      department: myDept,
      overall: overall,
      departmentList: deptList,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
