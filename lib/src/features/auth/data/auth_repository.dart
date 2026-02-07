// lib/features/auth/data/auth_repository.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../domain/auth_models.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  /// Ensures `_client.auth.currentSession` is hydrated when an auth event
  /// provides a non-null [session] but the client hasn't updated yet.
  ///
  /// This happens occasionally on web/desktop and breaks RPC/Edge Function calls
  /// that rely on `currentSession`.
  Future<void> ensureHydratedSession(Session session) async {
    final current = _client.auth.currentSession;
    if (current?.accessToken == session.accessToken) return;

    try {
      await _client.auth.recoverSession(jsonEncode(session.toJson()));
    } catch (_) {
      // Best-effort: callers can still use the passed-in session.
    }
  }

  bool _boolFromDynamic(Object? res) {
    if (res is bool) return res;
    if (res is num) return res != 0;
    if (res is String) {
      final v = res.trim().toLowerCase();
      if (v == 'true') return true;
      if (v == 'false') return false;
      if (v == 't') return true;
      if (v == 'f') return false;
      final n = num.tryParse(v);
      if (n != null) return n != 0;
    }

    if (res is Map) {
      final map = res.cast<Object?, Object?>();
      final candidate =
          map['is_admin'] ??
          map['isAdmin'] ??
          map['is_admin()'] ??
          map['result'];
      return _boolFromDynamic(candidate);
    }

    if (res is List && res.isNotEmpty) {
      return _boolFromDynamic(res.first);
    }

    return false;
  }

  Uri _restUri(String path, {Map<String, String>? queryParameters}) {
    final base = Uri.parse(Env.supabaseUrl);

    // Avoid double slashes if SUPABASE_URL ends with "/".
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;

    final fullPath = '$basePath$path';
    return base.replace(path: fullPath, queryParameters: queryParameters);
  }

  Future<bool> _isAdminViaHttp(String accessToken) async {
    final url = _restUri('/rest/v1/rpc/is_admin');

    final resp = await http.post(
      url,
      headers: <String, String>{
        'apikey': Env.supabaseAnonKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: '{}',
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AuthException('is_admin failed (${resp.statusCode}): ${resp.body}');
    }

    final body = resp.body.trim();
    if (body.isEmpty) return false;

    return _boolFromDynamic(jsonDecode(body));
  }

  Future<bool> _isAdminViaHttpTable({
    required String accessToken,
    required String userId,
  }) async {
    final url = _restUri(
      '/rest/v1/admins',
      queryParameters: <String, String>{
        'select': 'id',
        'user_id': 'eq.$userId',
        'is_active': 'eq.true',
        'limit': '1',
      },
    );

    final resp = await http.get(
      url,
      headers: <String, String>{
        'apikey': Env.supabaseAnonKey,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) return false;

    final body = resp.body.trim();
    if (body.isEmpty) return false;

    final decoded = jsonDecode(body);
    if (decoded is List) return decoded.isNotEmpty;
    if (decoded is Map) return decoded.isNotEmpty;
    return false;
  }

  Future<bool> isAdmin({
    Session? sessionOverride,
    String? userIdOverride,
  }) async {
    // Prefer using the explicit JWT (doesn't rely on `currentSession` hydration),
    // but treat a `false` as inconclusive and fall back to client-based checks.
    //
    // On some setups, PostgREST HTTP RPC can produce a false-negative (shape /
    // parsing / transient timing), while the client RPC succeeds.
    try {
      final token = sessionOverride?.accessToken;
      if (token != null && token.trim().isNotEmpty) {
        final viaHttp = await _isAdminViaHttp(token);
        if (viaHttp) return true;

        // If the RPC is missing/misconfigured, some setups still allow reading
        // the user's own `admins` row (depending on RLS). Try as a best-effort.
        final uid = userIdOverride ?? currentUser?.id;
        if (uid != null && uid.trim().isNotEmpty) {
          final viaTable = await _isAdminViaHttpTable(
            accessToken: token,
            userId: uid,
          );
          if (viaTable) return true;
        }
      }
    } catch (_) {}

    try {
      return _boolFromDynamic(await _client.rpc('is_admin'));
    } catch (_) {
      // Fallback if RPC doesn't exist yet (legacy DB): try reading the table.
      final uid = userIdOverride ?? currentUser?.id;
      if (uid == null || uid.isEmpty) return false;
      try {
        final row = await _client
            .from('admins')
            .select('id')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle();
        return row != null;
      } catch (_) {
        return false;
      }
    }
  }

  Future<User> signIn({required String email, required String password}) async {
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
    Map<String, dynamic>? metadata,
    String? emailRedirectTo,
  }) async {
    final data = <String, dynamic>{...?(metadata)};
    data['full_name'] = fullName;

    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: emailRedirectTo,
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
    await _client.auth.resend(type: OtpType.signup, email: email);
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
