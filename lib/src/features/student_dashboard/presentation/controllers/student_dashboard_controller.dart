import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/student_dashboard_repository.dart';
import '../../domain/student_dashboard_models.dart';

final studentDashboardRepositoryProvider = Provider<StudentDashboardRepository>((ref) {
  return StudentDashboardRepository(Supabase.instance.client);
});

final studentDashboardProvider =
    AutoDisposeAsyncNotifierProvider<StudentDashboardController, StudentDashboardVm>(
  StudentDashboardController.new,
);

class StudentDashboardController extends AutoDisposeAsyncNotifier<StudentDashboardVm> {
  @override
  Future<StudentDashboardVm> build() async {
    final auth = ref.watch(authViewStateProvider).value;
    final userId = auth?.user?.id;

    if (userId == null) {
      throw Exception('Not authenticated (studentDashboardProvider)');
    }

    final repo = ref.watch(studentDashboardRepositoryProvider);
    return repo.fetchDashboard(userId: userId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}
