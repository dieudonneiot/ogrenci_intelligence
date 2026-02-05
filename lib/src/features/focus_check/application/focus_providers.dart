import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../oi/application/oi_providers.dart';
import '../data/focus_repository.dart';
import '../domain/focus_models.dart';

final focusRepositoryProvider = Provider<FocusRepository>(
  (ref) => const FocusRepository(),
);

final acceptedInternshipsProvider =
    AutoDisposeAsyncNotifierProvider<
      AcceptedInternshipsController,
      List<AcceptedInternshipApplication>
    >(AcceptedInternshipsController.new);

class AcceptedInternshipsController
    extends AutoDisposeAsyncNotifier<List<AcceptedInternshipApplication>> {
  @override
  Future<List<AcceptedInternshipApplication>> build() async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) throw Exception('Not authenticated');
    final repo = ref.watch(focusRepositoryProvider);
    return repo.listMyAcceptedInternships(userId: uid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final focusSessionProvider = StateProvider<FocusCheckSession?>((ref) => null);

final focusActionProvider = Provider<FocusActions>((ref) => FocusActions(ref));

class FocusActions {
  FocusActions(this.ref);
  final Ref ref;

  Future<FocusCheckSession> start({
    required String internshipApplicationId,
  }) async {
    final repo = ref.read(focusRepositoryProvider);
    final session = await repo.startFocusCheck(
      internshipApplicationId: internshipApplicationId,
    );
    ref.read(focusSessionProvider.notifier).state = session;
    return session;
  }

  Future<void> submit({
    required String focusCheckId,
    required String answer,
  }) async {
    final repo = ref.read(focusRepositoryProvider);
    await repo.submitFocusAnswer(focusCheckId: focusCheckId, answer: answer);
    ref.read(focusSessionProvider.notifier).state = null;
    ref.invalidate(myOiProfileProvider);
  }
}
