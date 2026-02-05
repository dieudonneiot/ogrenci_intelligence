import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../oi/application/oi_providers.dart';
import '../data/evidence_repository.dart';
import '../domain/evidence_models.dart';

final evidenceRepositoryProvider = Provider<EvidenceRepository>(
  (ref) => const EvidenceRepository(),
);

final myEvidenceProvider =
    AutoDisposeAsyncNotifierProvider<MyEvidenceController, List<EvidenceItem>>(
      MyEvidenceController.new,
    );

class MyEvidenceController
    extends AutoDisposeAsyncNotifier<List<EvidenceItem>> {
  @override
  Future<List<EvidenceItem>> build() async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) throw Exception('Not authenticated');
    final repo = ref.watch(evidenceRepositoryProvider);
    return repo.listMyEvidence(userId: uid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final companyPendingEvidenceProvider =
    AutoDisposeAsyncNotifierProvider<
      CompanyPendingEvidenceController,
      List<EvidenceItem>
    >(CompanyPendingEvidenceController.new);

class CompanyPendingEvidenceController
    extends AutoDisposeAsyncNotifier<List<EvidenceItem>> {
  @override
  Future<List<EvidenceItem>> build() async {
    final auth = ref.watch(authViewStateProvider).value;
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.userType != UserType.company) {
      throw Exception('Not authorized');
    }
    final companyId = auth.companyId;
    if (companyId == null || companyId.isEmpty) {
      throw Exception('Missing companyId');
    }
    final repo = ref.watch(evidenceRepositoryProvider);
    return repo.listCompanyPendingEvidence(companyId: companyId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> review({
    required String evidenceId,
    required String status,
    String? reason,
  }) async {
    final repo = ref.read(evidenceRepositoryProvider);
    await repo.reviewEvidence(
      evidenceId: evidenceId,
      status: status,
      reason: reason,
    );
    ref.invalidate(companyPendingEvidenceProvider);
    ref.invalidate(myOiProfileProvider);
  }
}
