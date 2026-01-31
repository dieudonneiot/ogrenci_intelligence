import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/student_dashboard_repository.dart';
import '../domain/student_dashboard_models.dart';

final studentDashboardRepositoryProvider = Provider<StudentDashboardRepository>((ref) {
  return StudentDashboardRepository();
});

final studentDashboardProvider =
    AsyncNotifierProvider<StudentDashboardNotifier, StudentDashboardViewModel>(
  StudentDashboardNotifier.new,
);

class StudentDashboardNotifier extends AsyncNotifier<StudentDashboardViewModel> {
  @override
  Future<StudentDashboardViewModel> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<StudentDashboardViewModel> _load() async {
    final repo = ref.read(studentDashboardRepositoryProvider);

    final auth = ref.read(authViewStateProvider).value;
    final uid = auth?.user?.id;

    final fallbackName = (auth?.user?.email ?? 'Öğrenci').split('@').first;

    if (uid == null || uid.isEmpty) {
      return StudentDashboardViewModel.empty(displayName: fallbackName);
    }

    return repo.fetchDashboard(uid: uid, fallbackName: fallbackName);
  }
}
