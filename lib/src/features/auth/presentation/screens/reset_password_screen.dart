import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../controllers/auth_controller.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _linkCtrl = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _linkError;
  bool _linkApplied = false;

  @override
  void dispose() {
    _linkCtrl.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _applyLink() async {
    final l10n = AppLocalizations.of(context);
    final raw = _linkCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _linkError = l10n.t(AppText.authLinkRequired));
      return;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      setState(() => _linkError = l10n.t(AppText.authLinkInvalid));
      return;
    }

    try {
      await SupabaseService.client.auth.getSessionFromUrl(uri);
      if (!mounted) return;
      setState(() {
        _linkApplied = true;
        _linkError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.authLinkAccepted))),
      );
    } catch (e) {
      setState(() => _linkError = l10n.t(AppText.authLinkExpired));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t(AppText.authResetTitle))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _linkCtrl,
              decoration: InputDecoration(
                labelText: l10n.t(AppText.authPasteResetLink),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _applyLink,
                  child: Text(l10n.t(AppText.authUseResetLink)),
                ),
                const SizedBox(width: 12),
                if (_linkApplied)
                  Text(
                    l10n.t(AppText.authLinkApplied),
                    style: const TextStyle(color: Colors.green),
                  ),
              ],
            ),
            if (_linkError != null) ...[
              const SizedBox(height: 8),
              Text(
                _linkError!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t(AppText.authNewPasswordLabel),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t(AppText.commonConfirmPassword),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final password = _password.text.trim();
                      final confirm = _confirm.text.trim();

                      final session = SupabaseService.client.auth.currentSession;
                      if (session == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.t(AppText.authOpenResetLinkFirst)),
                          ),
                        );
                        return;
                      }

                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.t(AppText.commonPasswordMin))),
                        );
                        return;
                      }

                      if (password != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.t(AppText.commonPasswordsNoMatch))),
                        );
                        return;
                      }

                      final err = await ref
                          .read(authActionLoadingProvider.notifier)
                          .updatePassword(password);
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err ?? l10n.t(AppText.authPasswordUpdated))),
                      );
                    },
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.t(AppText.commonUpdate)),
            ),
          ],
        ),
      ),
    );
  }
}
