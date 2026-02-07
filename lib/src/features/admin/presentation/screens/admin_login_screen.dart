import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _remember = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.t(AppText.adminLoginErrorRequired));
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = l10n.t(AppText.adminLoginErrorInvalidEmail));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      final session = res.session;
      if (user == null) {
        _error = l10n.t(AppText.commonSomethingWentWrong);
        return;
      }

      if (user.emailConfirmedAt == null) {
        await SupabaseService.client.auth.signOut();
        _error = l10n.t(AppText.adminLoginErrorVerifyEmail);
        return;
      }

      // Some platforms emit auth state before `currentSession` is hydrated.
      // Ensure subsequent RPC calls are authenticated.
      if (session != null &&
          SupabaseService.client.auth.currentSession == null) {
        try {
          await SupabaseService.client.auth.recoverSession(
            jsonEncode(session.toJson()),
          );
        } catch (_) {}
      }

      // Determine admin using the same robust logic as the global auth state
      // (uses explicit JWT when available, then falls back).
      final isAdmin = await ref.read(authRepositoryProvider).isAdmin(
            sessionOverride: session,
            userIdOverride: user.id,
          );
      if (!isAdmin) {
        await SupabaseService.client.auth.signOut();
        _error = l10n.t(AppText.adminLoginErrorNotAdmin);
        if (kDebugMode) {
          _error =
              '$_error\n(DB check failed: ensure `public.is_admin()` exists and is executable - see `docs/sql/00_helpers.sql`.)';
        }
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.adminLoginSuccess))),
      );

      // Trigger auth state listeners to re-evaluate role (helps on some platforms).
      try {
        await SupabaseService.client.auth.refreshSession();
      } catch (_) {}

      // Wait briefly for auth state propagation, then go to admin dashboard.
      final current = ref.read(authViewStateProvider).valueOrNull;
      if (current?.isAuthenticated == true &&
          current?.userType == UserType.admin) {
        if (!mounted) return;
        context.go(Routes.adminDashboard);
        return;
      }

      final completer = Completer<void>();
      final sub = ref.listenManual<AsyncValue<AuthViewState>>(
        authViewStateProvider,
        (_, next) {
          final v = next.valueOrNull;
          if (v?.isAuthenticated == true && v?.userType == UserType.admin) {
            if (!completer.isCompleted) completer.complete();
          }
        },
      );

      try {
        await completer.future.timeout(const Duration(seconds: 2));
      } catch (_) {
        // ignore
      } finally {
        sub.close();
      }

      if (!mounted) return;
      final resolved = ref.read(authViewStateProvider).valueOrNull;
      if (resolved?.isAuthenticated == true &&
          resolved?.userType == UserType.admin) {
        if (!mounted) return;
        context.go(Routes.adminDashboard);
      } else {
        // Navigate to a stable location and let the router redirect based on role.
        if (!mounted) return;
        context.go(Routes.home);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.security,
                    size: 48,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t(AppText.adminLoginTitle),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.t(AppText.adminLoginSubtitle),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFF7F1D1D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _TextField(
                    controller: _emailCtrl,
                    label: l10n.t(AppText.adminLoginEmailLabel),
                    hint: l10n.t(AppText.adminLoginEmailHint),
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _TextField(
                    controller: _passwordCtrl,
                    label: l10n.t(AppText.adminLoginPasswordLabel),
                    hint: l10n.t(AppText.adminLoginPasswordHint),
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, c) {
                      final narrow = c.maxWidth < 360;
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  onChanged: (v) => setState(
                                    () => _remember = v ?? false,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    l10n.t(AppText.adminLoginRememberMe),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    context.go(Routes.forgotPassword),
                                child: Text(
                                  l10n.t(AppText.adminLoginForgotPassword),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Checkbox(
                            value: _remember,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              l10n.t(AppText.adminLoginRememberMe),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(Routes.forgotPassword),
                            child: Text(
                              l10n.t(AppText.adminLoginForgotPassword),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_outline),
                      label: Text(
                        _loading
                            ? l10n.t(AppText.adminLoginButtonLoading)
                            : l10n.t(AppText.adminLoginButton),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(height: 1, color: const Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${l10n.t(AppText.authNoAccount)} '),
                      TextButton(
                        onPressed: () => context.go(Routes.adminSetup),
                        child: Text(l10n.t(AppText.adminSetupCreateButton)),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.go(Routes.home),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.t(AppText.commonBack)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
