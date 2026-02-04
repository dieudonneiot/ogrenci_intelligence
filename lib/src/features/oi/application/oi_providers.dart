import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/oi_repository.dart';
import '../domain/oi_models.dart';

final oiRepositoryProvider = Provider<OiRepository>((ref) => const OiRepository());

final myOiProfileProvider = AutoDisposeAsyncNotifierProvider<MyOiProfileController, OiProfile>(
  MyOiProfileController.new,
);

class MyOiProfileController extends AutoDisposeAsyncNotifier<OiProfile> {
  @override
  Future<OiProfile> build() async {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Not authenticated');
    }

    final repo = ref.watch(oiRepositoryProvider);
    return repo.fetchMyOiProfile(userId: uid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

