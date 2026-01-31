import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/student_dashboard_repository.dart';
import '../../domain/student_dashboard_models.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

final studentDashboardRepositoryProvider =
    Provider<StudentDashboardRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StudentDashboardRepository(client);
});

final studentDashboardProvider =
    FutureProvider.autoDispose<StudentDashboardVm>((ref) async {
  final authAsync = ref.watch(authViewStateProvider);
  final auth = authAsync.value;

  final userId = auth?.user?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('No authenticated user');
  }

  final repo = ref.watch(studentDashboardRepositoryProvider);
  return repo.fetchDashboard(userId: userId);
});
