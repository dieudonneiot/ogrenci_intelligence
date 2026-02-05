import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _rememberMe = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// React-parity:
  /// - If redirected to /login?from=..., after login go back to that exact location.
  /// - If missing/invalid, go to student default: /dashboard
  /// - Prevent external redirects + auth-page loops
  String _resolveFromTarget() {
    final raw = widget.from?.trim();
    if (raw == null || raw.isEmpty) return Routes.dashboard;

    String decoded;
    try {
      decoded = Uri.decodeComponent(raw);
    } catch (_) {
      return Routes.dashboard;
    }

    // Must be an internal absolute path.
    if (!decoded.startsWith('/')) return Routes.dashboard;

    final uri = Uri.tryParse(decoded);
    if (uri == null) return Routes.dashboard;

    // Block external redirects
    if (uri.hasScheme || uri.hasAuthority) return Routes.dashboard;

    // Avoid loops back into auth pages
    const blocked = <String>{
      Routes.login,
      Routes.register,
      Routes.forgotPassword,
      Routes.emailVerification,
      Routes.companyAuth,
      Routes.companyRegister,
      Routes.adminLogin,
      Routes.adminSetup,
    };

    if (blocked.contains(uri.path)) return Routes.dashboard;

    // Preserve path + query exactly
    return uri.toString();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);

    final email = _email.text.trim();
    final pass = _password.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = l10n.t(AppText.commonFillAllFields));
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = l10n.t(AppText.commonInvalidEmail));
      return;
    }

    final err = await ref
        .read(authActionLoadingProvider.notifier)
        .signIn(email, pass);

    if (!mounted) return;

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // If auth state is already updated, navigate immediately.
    final current = ref.read(authViewStateProvider).valueOrNull;
    if (current?.isAuthenticated == true) {
      context.go(_resolveFromTarget());
      return;
    }

    // Otherwise wait a bit for auth to update (but never hang forever).
    final completer = Completer<void>();
    final sub = ref.listenManual<AsyncValue<AuthViewState>>(
      authViewStateProvider,
      (_, next) {
        final value = next.valueOrNull;
        if (value?.isAuthenticated == true && !completer.isCompleted) {
          completer.complete();
        }
      },
    );

    try {
      await completer.future.timeout(const Duration(seconds: 2));
    } catch (_) {
      // ignore timeout; router redirect will handle if needed
    } finally {
      sub.close();
    }

    if (!mounted) return;
    context.go(_resolveFromTarget());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionLoadingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          size: 38,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.t(AppText.authWelcomeBack),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t(AppText.authStudentLoginSubtitle),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonEmail),
                        prefixIcon: const Icon(Icons.mail_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonPassword),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                        ),
                        Text(
                          l10n.t(AppText.commonRememberMe),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push(Routes.forgotPassword),
                          child: Text(l10n.t(AppText.commonForgotPassword)),
                        ),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
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
                                style: const TextStyle(
                                  color: Color(0xFF7F1D1D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : _submit,
                        icon: busy
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
                          l10n.t(AppText.authLoginTitle),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(height: 1, color: const Color(0xFFE5E7EB)),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () => context.push(Routes.companyAuth),
                      icon: const Icon(Icons.apartment_outlined),
                      label: Text(
                        l10n.t(AppText.authLoginAsCompany),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${l10n.t(AppText.authNoAccount)} '),
                        TextButton(
                          onPressed: () => context.push(Routes.register),
                          child: Text(l10n.t(AppText.authRegisterCta)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admin panel',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(Routes.adminLogin),
                            child: const Text('Login'),
                          ),
                          TextButton(
                            onPressed: () => context.go(Routes.adminSetup),
                            child: const Text('Setup'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
