import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../controllers/auth_controller.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, this.emailHint});

  /// If user session is null (e.g., signUp returns no session),
  /// we still show the email and allow "resend" using this.
  final String? emailHint;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  Timer? _timer;
  int _countdown = 0;

  bool _resending = false;
  bool _checking = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _countdown = seconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  String? _emailToShow() {
    final auth = ref.watch(authViewStateProvider).value;
    return auth?.user?.email ?? widget.emailHint;
  }

  Future<void> _resend() async {
    final email = _emailToShow();
    if (email == null || email.trim().isEmpty) {
      _snack('Email not found. Please login again.', isError: true);
      return;
    }

    if (_countdown > 0 || _resending) return;

    setState(() => _resending = true);
    try {
      // Supabase resend signup verification email
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );

      _snack('Verification email sent again.');
      _startCountdown(60);
    } catch (e) {
      _snack('Failed to resend email: $e', isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _check() async {
    final auth = ref.watch(authViewStateProvider).value;
    final user = auth?.user;

    // If no session/user, we cannot call getUser() reliably.
    if (user == null) {
      _snack('Please login again after verifying your email.', isError: true);
      return;
    }

    if (_checking) return;

    setState(() => _checking = true);
    try {
      final res = await SupabaseService.client.auth.getUser();
      final updated = res.user;

      if (updated?.emailConfirmedAt != null) {
        _snack('Email verified successfully!');
        if (!mounted) return;

        // React goes to /profile
        // Guards will redirect if company/admin.
        // ignore: use_build_context_synchronously
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Better with GoRouter, but keep this screen self-contained.
        // Your router will handle redirect from home -> role dashboard.
      } else {
        _snack('Email not verified yet.', isError: true);
      }
    } catch (e) {
      _snack('Verification check failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewStateProvider).value;
    final email = _emailToShow() ?? '—';
    final hasUser = auth?.user != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mail_outline,
                          size: 42,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Email verification pending',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To activate your account, please verify your email address.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Verification link sent to: $email',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    _StepTile(
                      index: 1,
                      title: 'Check your inbox',
                      subtitle: 'The verification email should arrive in a few minutes.',
                    ),
                    _StepTile(
                      index: 2,
                      title: 'Click the verification link',
                      subtitle: 'Open the email and confirm your account.',
                    ),
                    _StepTile(
                      index: 3,
                      title: 'Return to the app',
                      subtitle: 'After verification, you can access all features.',
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: (_checking || !hasUser) ? null : _check,
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: Text(_checking ? 'Checking...' : 'I verified my email'),
                    ),

                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: (_resending || _countdown > 0) ? null : _resend,
                      icon: _resending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _resending
                            ? 'Sending...'
                            : _countdown > 0
                                ? 'Resend ($_countdown s)'
                                : 'Resend email',
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.35)),
                      ),
                      child: const Text(
                        'Didn’t receive the email? Check spam/junk, or try resending.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        // Use GoRouter if available
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pushNamed(Routes.login);
                      },
                      child: const Text('Login with a different account'),
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

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
