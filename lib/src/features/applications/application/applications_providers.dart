import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/applications_repository.dart';
import '../domain/applications_models.dart';

final applicationsRepositoryProvider = Provider<ApplicationsRepository>((ref) {
  return const ApplicationsRepository();
});

String? _uid(Ref ref) => ref.read(authViewStateProvider).value?.user?.id;

final myApplicationsBundleProvider =
    FutureProvider.autoDispose<ApplicationsBundle>((ref) async {
      final uid = _uid(ref);
      if (uid == null || uid.isEmpty) return ApplicationsBundle.empty();

      final repo = ref.read(applicationsRepositoryProvider);

      final results = await Future.wait<List<ApplicationListItem>>([
        repo.fetchMyJobApplications(userId: uid),
        repo.fetchMyInternshipApplications(userId: uid),
        repo.fetchMyCourseApplications(userId: uid),
      ]);

      return ApplicationsBundle(
        jobs: results[0],
        internships: results[1],
        courses: results[2],
      );
    });
