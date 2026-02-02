import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final raw = _linkCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _linkError = 'Paste the full reset link from your email.');
      return;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      setState(() => _linkError = 'Invalid link format.');
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
        const SnackBar(content: Text('Link accepted. You can set a new password now.')),
      );
    } catch (e) {
      setState(() => _linkError = 'Invalid or expired link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authActionLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _linkCtrl,
              decoration: const InputDecoration(
                labelText: 'Paste reset link (if not redirected automatically)',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _applyLink,
                  child: const Text('Use reset link'),
                ),
                const SizedBox(width: 12),
                if (_linkApplied)
                  const Text(
                    'Link applied',
                    style: TextStyle(color: Colors.green),
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
              decoration: const InputDecoration(
                labelText: 'New password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
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
                          const SnackBar(
                            content: Text('Open the reset link first (or paste it above).'),
                          ),
                        );
                        return;
                      }

                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters.')),
                        );
                        return;
                      }

                      if (password != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match.')),
                        );
                        return;
                      }

                      final err = await ref
                          .read(authActionLoadingProvider.notifier)
                          .updatePassword(password);
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err ?? 'Password updated')),
                      );
                    },
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
