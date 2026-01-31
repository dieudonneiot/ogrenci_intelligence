
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/student_dashboard_repository.dart';
import '../../domain/dashboard_application.dart';


final studentDashboardRepositoryProvider = Provider<StudentDashboardRepository>((ref) {
  return const StudentDashboardRepository();
});

final studentDashboardProvider =
    AutoDisposeAsyncNotifierProvider<StudentDashboardController, StudentDashboardData>(
  StudentDashboardController.new,
);

class StudentDashboardController extends AutoDisposeAsyncNotifier<StudentDashboardData> {
@override
Future<StudentDashboardData> build() async {
  final auth = await ref.watch(authViewStateProvider.future);
  final user = auth.user;
  if (user == null) throw StateError('No authenticated user for dashboard');

  final email = user.email ?? '';
  final fallbackName = email.isNotEmpty ? email.split('@').first : 'Kullanıcı';

  final repo = ref.read(studentDashboardRepositoryProvider);
  return repo.fetchDashboard(
    userId: user.id,
    email: email,
    fallbackFullName: fallbackName,
  );
}

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}
