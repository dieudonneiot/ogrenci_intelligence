// lib/src/features/auth/presentation/screens/forgot_password_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../controllers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _submitted = false;
  String? _error;
  Timer? _timer;
  int _cooldown = 0;

  @override
  void dispose() {
    _email.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);

    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = l10n.t(AppText.authEmailRequired));
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = l10n.t(AppText.commonInvalidEmail));
      return;
    }
    if (_cooldown > 0) {
      setState(() => _error = l10n.authWaitSeconds(_cooldown));
      return;
    }

    final err = await ref
        .read(authActionLoadingProvider.notifier)
        .resetPassword(email);

    if (!mounted) return;

    if (err != null) {
      if (err.toLowerCase().contains('rate_limit')) {
        _startCooldown(60);
        setState(() => _error = l10n.t(AppText.authTooManyRequests));
      } else {
        setState(() => _error = err);
      }
    } else {
      _startCooldown(60);
      setState(() => _submitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionLoadingProvider);

    if (_submitted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t(AppText.authForgotTitle))),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        l10n.t(AppText.authEmailSentTitle),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.authResetLinkSentTo(_email.text.trim()),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          l10n.t(AppText.authCheckSpam),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_cooldown > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.authRequestAgainIn(_cooldown),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () => context.go(Routes.login),
                        child: Text(l10n.t(AppText.commonBackToLogin)),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t(AppText.authForgotTitle))),
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
                          Icons.mail_outline,
                          size: 34,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.t(AppText.authForgotTitle),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t(AppText.authForgotSubtitle),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonEmail),
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.t(AppText.authSendResetLink)),
                    ),

                    const SizedBox(height: 10),

                    TextButton.icon(
                      onPressed: () => context.go(Routes.login),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.t(AppText.commonBackToLogin)),
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
