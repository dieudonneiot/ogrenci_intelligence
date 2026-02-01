// lib/src/features/points/application/points_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/points_repository.dart';
import '../domain/points_models.dart';

final pointsRepositoryProvider = Provider<PointsRepository>((ref) {
  return PointsRepository(onPointsAwarded: () => invalidatePointsProviders(ref));
});

String? _uid(Ref ref) => ref.read(authViewStateProvider).value?.user?.id;

// Total points
final myTotalPointsProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = _uid(ref);
  if (uid == null || uid.isEmpty) return 0;
  return ref.read(pointsRepositoryProvider).fetchTotalPoints(userId: uid);
});

// Points history
final myPointsHistoryProvider = FutureProvider.autoDispose<List<UserPoint>>((ref) async {
  final uid = _uid(ref);
  if (uid == null || uid.isEmpty) return const <UserPoint>[];
  return ref.read(pointsRepositoryProvider).fetchUserPoints(userId: uid);
});

// Rewards
final rewardsProvider = FutureProvider.autoDispose<List<Reward>>((ref) async {
  return ref.read(pointsRepositoryProvider).fetchRewards();
});

// Badges
final myBadgesProvider = FutureProvider.autoDispose<List<UserBadge>>((ref) async {
  final uid = _uid(ref);
  if (uid == null || uid.isEmpty) return const <UserBadge>[];
  return ref.read(pointsRepositoryProvider).fetchBadges(userId: uid);
});

void invalidatePointsProviders(Ref ref) {
  ref.invalidate(myTotalPointsProvider);
  ref.invalidate(myPointsHistoryProvider);
  ref.invalidate(myBadgesProvider);
  ref.invalidate(rewardsProvider);
}
