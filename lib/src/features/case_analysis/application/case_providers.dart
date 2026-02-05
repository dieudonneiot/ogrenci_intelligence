import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../oi/application/oi_providers.dart';
import '../data/case_repository.dart';
import '../domain/case_models.dart';

final caseRepositoryProvider = Provider<CaseRepository>(
  (ref) => const CaseRepository(),
);

final caseScenariosProvider =
    AutoDisposeAsyncNotifierProvider<
      CaseScenariosController,
      List<CaseScenario>
    >(CaseScenariosController.new);

class CaseScenariosController
    extends AutoDisposeAsyncNotifier<List<CaseScenario>> {
  @override
  Future<List<CaseScenario>> build() async {
    final repo = ref.watch(caseRepositoryProvider);
    return repo.listActiveScenarios();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> submitChoice({
    required String scenarioId,
    required CaseChoice choice,
  }) async {
    final repo = ref.read(caseRepositoryProvider);
    await repo.submitChoice(scenarioId: scenarioId, choice: choice);

    // OI updates as a side-effect of the RPC; refresh local caches.
    ref.invalidate(myOiProfileProvider);
  }
}
