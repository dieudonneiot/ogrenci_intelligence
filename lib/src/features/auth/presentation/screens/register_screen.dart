import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _showPassword = false;
  bool _acceptTerms = false;

  String? _department;
  int? _year;

  String? _error;

  static const departments = [
    "Bilgisayar Mühendisliği",
    "Yazılım Mühendisliği",
    "Elektrik-Elektronik Mühendisliği",
    "Endüstri Mühendisliği",
    "Makine Mühendisliği",
    "İnşaat Mühendisliği",
    "Mimarlık",
    "İşletme",
    "İktisat",
    "Hukuk",
    "Tıp",
    "Diş Hekimliği",
    "Eczacılık",
    "Hemşirelik",
    "Psikoloji",
    "Öğretmenlik",
    "İletişim",
    "Güzel Sanatlar",
    "Diğer",
  ];

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() => _error = null);

    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return false;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return false;
    }
    if (_department == null) {
      setState(() => _error = 'Please select your department.');
      return false;
    }
    if (_year == null) {
      setState(() => _error = 'Please select your year.');
      return false;
    }
    if (!_acceptTerms) {
      setState(() => _error = 'You must accept Terms & Privacy.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final email = _email.text.trim();
    final pass = _password.text;
    final fullName = _fullName.text.trim();

    final err = await ref
        .read(authActionLoadingProvider.notifier)
        .signUp(email, pass, fullName);

    if (!mounted) return;

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // Try to update profile (same as React). Ignore errors if RLS blocks it.
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        await SupabaseService.client.from('profiles').update({
          'full_name': fullName,
          'department': _department,
          'year': _year,
          'email': email,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }
    } catch (_) {
      // ignore
    }

    // Professional flow: show email verification page, with email hint
    final uri = Uri(
      path: Routes.emailVerification,
      queryParameters: {'email': email},
    ).toString();

    context.go(uri);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authActionLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
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
                          Icons.person_outline,
                          size: 34,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Student registration',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: _fullName,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _department,
                      items: departments
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _department = v),
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      initialValue: _year,
                      items: const [1, 2, 3, 4, 5]
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text(y == 5 ? '5+ (and above)' : '$y'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v),
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _confirm,
                      obscureText: !_showPassword,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              children: [
                                const Text('I accept '),
                                GestureDetector(
                                  onTap: () => context.push(Routes.terms),
                                  child: Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Text(' and '),
                                GestureDetector(
                                  onTap: () => context.push(Routes.privacy),
                                  child: Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Text('.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.25)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
                          : const Text('Register'),
                    ),

                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),

                    OutlinedButton(
                      onPressed: () => context.push(Routes.companyAuth),
                      child: const Text('Register as company'),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? '),
                        TextButton(
                          onPressed: () => context.go(Routes.login),
                          child: const Text('Login'),
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
