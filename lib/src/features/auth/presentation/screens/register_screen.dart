// lib/src/features/auth/presentation/screens/register_screen.dart
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
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _showPassword = false;
  bool _acceptTerms = false;

  String? _department;
  int? _year;
  String? _error;

  static const departments = <String>[
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
    "Diğer"
  ];

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  int _passwordStrength(String p) {
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(p)) s++;
    return s; // 0..4
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      setState(() => _error = 'Kullanım şartlarını kabul etmelisiniz!');
      return;
    }

    final action = ref.read(authActionLoadingProvider.notifier);
    final err = await action.signUp(
      _email.text.trim(),
      _password.text,
      _fullName.text.trim(),
    );

    if (!mounted) return;

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // Mirror React: update profiles with extra fields (ignore errors)
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        await SupabaseService.client.from('profiles').update({
          'full_name': _fullName.text.trim(),
          'department': _department,
          'year': _year,
          'email': _email.text.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id);
      }
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kayıt başarılı. Lütfen email adresinizi doğrulayın.'),
      ),
    );

    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authActionLoadingProvider);
    final pStrength = _passwordStrength(_password.text);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.person, color: Colors.purple, size: 34),
                ),
                const SizedBox(height: 14),
                Text('Hesap Oluşturun',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text('Kariyer yolculuğunuza başlayın',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text('Öğrenci Kaydı',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.purple)),
                const SizedBox(height: 18),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _fullName,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              labelText: 'Ad Soyad',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Ad Soyad gerekli' : null,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.mail_outline),
                              labelText: 'E-posta Adresi',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Email gerekli';
                              if (!s.contains('@')) return 'Geçerli email girin';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            initialValue: _department,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.school_outlined),
                              labelText: 'Bölüm',
                              border: OutlineInputBorder(),
                            ),
                            items: departments
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (v) => setState(() => _department = v),
                            validator: (v) => v == null ? 'Lütfen bölüm seçin' : null,
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<int>(
                            initialValue: _year,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                              labelText: 'Sınıf',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1. Sınıf')),
                              DropdownMenuItem(value: 2, child: Text('2. Sınıf')),
                              DropdownMenuItem(value: 3, child: Text('3. Sınıf')),
                              DropdownMenuItem(value: 4, child: Text('4. Sınıf')),
                              DropdownMenuItem(value: 5, child: Text('5. Sınıf ve üzeri')),
                            ],
                            onChanged: (v) => setState(() => _year = v),
                            validator: (v) => v == null ? 'Lütfen sınıf seçin' : null,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _password,
                            obscureText: !_showPassword,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              labelText: 'Şifre',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _showPassword = !_showPassword),
                                icon: Icon(_showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                              ),
                            ),
                            validator: (v) {
                              final s = (v ?? '');
                              if (s.isEmpty) return 'Şifre gerekli';
                              if (s.length < 6) return 'Şifre en az 6 karakter olmalı';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // strength bar (simple)
                          if (_password.text.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: pStrength / 4.0,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('Güç: $pStrength/4',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),

                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirm,
                            obscureText: !_showPassword,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline),
                              labelText: 'Şifre Tekrar',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) return 'Şifre tekrar gerekli';
                              if (v != _password.text) return 'Şifreler eşleşmiyor!';
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _acceptTerms,
                            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                            title: const Text('Kullanım Şartları ve Gizlilik Politikasını kabul ediyorum'),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.25)),
                              ),
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                          ],

                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: loading ? null : _submit,
                              child: loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Kayıt Ol'),
                            ),
                          ),

                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => context.go(Routes.companyAuth),
                            child: const Text('İşletme olarak kayıt ol'),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Zaten hesabınız var mı? '),
                              TextButton(
                                onPressed: () => context.go(Routes.login),
                                child: const Text('Giriş yapın'),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
