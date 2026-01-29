// lib/features/auth/data/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/auth_models.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) {
      throw const AuthException('Sign-in failed: user is null.');
    }

    // Block if email not confirmed (same as React)
    if (user.emailConfirmedAt == null) {
      await _client.auth.signOut();
      throw const AuthException('Please verify your email address.');
    }

    return user;
  }

  Future<User> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    final user = res.user;
    if (user == null) {
      throw const AuthException('Sign-up failed: user is null.');
    }
    return user;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword({
    required String email,
    String? redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await _client.auth.updateUser(UserAttributes(data: updates));
  }

  Future<Session?> refreshSession() async {
    final res = await _client.auth.refreshSession();
    return res.session;
  }

  Future<void> resendSignupOtp({required String email}) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<void> upsertStudentProfile({
    required String userId,
    required String email,
    required String fullName,
    required String department,
    required int year,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'email': email,
      'full_name': fullName,
      'department': department,
      'year': year,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<CompanyMembership?> fetchCompanyMembership(String userId) async {
    final row = await _client
        .from('company_users')
        .select('company_id, role')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return CompanyMembership.fromJson(row);
  }

  Future<User?> getFreshUser() async {
    final res = await _client.auth.getUser();
    return res.user;
  }

  Future<void> resendSignupVerificationEmail(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

}
