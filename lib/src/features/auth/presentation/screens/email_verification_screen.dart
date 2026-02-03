import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final email = _emailToShow();
    if (email == null || email.trim().isEmpty) {
      _snack(l10n.t(AppText.authEmailNotFound), isError: true);
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

      _snack(l10n.t(AppText.authVerificationEmailSentAgain));
      _startCountdown(60);
    } catch (e) {
      _snack(l10n.authResendFailed('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authViewStateProvider).value;
    final user = auth?.user;

    // If no session/user, we cannot call getUser() reliably.
    if (user == null) {
      _snack(l10n.t(AppText.authPleaseLoginAfterVerify), isError: true);
      return;
    }

    if (_checking) return;

    setState(() => _checking = true);
    try {
      final res = await SupabaseService.client.auth.getUser();
      final updated = res.user;

      if (updated?.emailConfirmedAt != null) {
        _snack(l10n.t(AppText.authEmailVerifiedSuccess));
        if (!mounted) return;

        // React goes to /profile
        // Guards will redirect if company/admin.
        // ignore: use_build_context_synchronously
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Better with GoRouter, but keep this screen self-contained.
        // Your router will handle redirect from home -> role dashboard.
      } else {
        _snack(l10n.t(AppText.authEmailNotVerifiedYet), isError: true);
      }
    } catch (e) {
      _snack(l10n.authVerificationCheckFailed('$e'), isError: true);
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
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authViewStateProvider).value;
    final email = _emailToShow() ?? '—';
    final hasUser = auth?.user != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t(AppText.authEmailVerificationTitle))),
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
                      l10n.t(AppText.authEmailVerificationPending),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t(AppText.authEmailVerificationSubtitle),
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
                        l10n.authVerificationSentTo(email),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    _StepTile(
                      index: 1,
                      title: l10n.t(AppText.authStepCheckInboxTitle),
                      subtitle: l10n.t(AppText.authStepCheckInboxSubtitle),
                    ),
                    _StepTile(
                      index: 2,
                      title: l10n.t(AppText.authStepClickLinkTitle),
                      subtitle: l10n.t(AppText.authStepClickLinkSubtitle),
                    ),
                    _StepTile(
                      index: 3,
                      title: l10n.t(AppText.authStepReturnTitle),
                      subtitle: l10n.t(AppText.authStepReturnSubtitle),
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
                      label: Text(
                        _checking
                            ? l10n.t(AppText.commonChecking)
                            : l10n.t(AppText.authIHaveVerified),
                      ),
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
                            ? l10n.t(AppText.commonSending)
                            : _countdown > 0
                                ? l10n.commonResendCountdown(_countdown)
                                : l10n.t(AppText.authResendEmail),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        l10n.t(AppText.authDidNotReceive),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        context.go(Routes.login);
                      },
                      child: Text(l10n.t(AppText.authLoginDifferent)),
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
