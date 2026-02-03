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
      appBar: AppBar(title: Text(l10n.t(AppText.authLoginTitle))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 34,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.t(AppText.authWelcomeBack),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t(AppText.authStudentLoginSubtitle),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonEmail),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonPassword),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
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
                        Text(l10n.t(AppText.commonRememberMe)),
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
                          color: Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    ElevatedButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.t(AppText.authLoginTitle)),
                    ),

                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),

                    OutlinedButton(
                      onPressed: () => context.push(Routes.companyAuth),
                      child: Text(l10n.t(AppText.authLoginAsCompany)),
                    ),

                    const SizedBox(height: 12),

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
