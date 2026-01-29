// lib/features/auth/presentation/controllers/auth_controller.dart
import 'dart:async';
// ✅ for unawaited
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../admin/presentation/controllers/admin_controller.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';

class AuthViewState {
  const AuthViewState({
    required this.user,
    required this.session,
    required this.loading,
    required this.userType,
    this.companyId,
    this.companyRole,
  });

  final User? user;
  final Session? session;
  final bool loading;

  final UserType userType;
  final String? companyId;
  final String? companyRole;

  bool get isAuthenticated => user != null && user!.emailConfirmedAt != null;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseService.client);
});

final authViewStateProvider = StreamProvider<AuthViewState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final controller = StreamController<AuthViewState>.broadcast();

  Future<void> emit(Session? session, {required bool loading}) async {
    final user = session?.user;

    UserType userType = UserType.guest;
    String? companyId;
    String? companyRole;

    if (user != null && user.emailConfirmedAt != null) {
      // Admin has priority
      final admin = await ref.read(activeAdminProvider.future);
      if (admin != null) {
        userType = UserType.admin;
      } else {
        final membership = await repo.fetchCompanyMembership(user.id);
        if (membership != null) {
          userType = UserType.company;
          companyId = membership.companyId;
          companyRole = membership.role;
        } else {
          userType = UserType.student;
        }
      }
    }

    controller.add(
      AuthViewState(
        user: user,
        session: session,
        loading: loading,
        userType: userType,
        companyId: companyId,
        companyRole: companyRole,
      ),
    );
  }

  // initial
  controller.add(const AuthViewState(
    user: null,
    session: null,
    loading: true,
    userType: UserType.guest,
  ));

  unawaited(() async {
    await emit(repo.currentSession, loading: false);
  }());

  final sub = repo.authStateChanges().listen((evt) async {
    ref.invalidate(activeAdminProvider);
    await emit(evt.session, loading: false);
  });

  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
});

final authActionLoadingProvider =
    StateNotifierProvider<AuthActionController, bool>((ref) {
  return AuthActionController(ref.watch(authRepositoryProvider));
});

class AuthActionController extends StateNotifier<bool> {
  AuthActionController(this._repo) : super(false);
  final AuthRepository _repo;

  Future<String?> signIn(String email, String password) async {
    try {
      state = true;
      await _repo.signIn(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      state = false;
    }
  }

  Future<String?> signUp(String email, String password, String fullName) async {
    try {
      state = true;
      await _repo.signUp(email: email, password: password, fullName: fullName);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      state = false;
    }
  }

  Future<String?> signOut() async {
    try {
      state = true;
      await _repo.signOut();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      state = false;
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      state = true;
      await _repo.resetPassword(
        email: email,
        redirectTo: Env.deepLinkResetPassword.toString(),
      );
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      state = false;
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      state = true;
      await _repo.updatePassword(newPassword);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      state = false;
    }
  }
}