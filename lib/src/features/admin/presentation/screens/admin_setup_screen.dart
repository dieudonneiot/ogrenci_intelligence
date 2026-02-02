import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final _setupKeyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = true;
  bool _creating = false;
  bool _hasAdmins = false;

  @override
  void initState() {
    super.initState();
    _checkExistingAdmins();
  }

  @override
  void dispose() {
    _setupKeyCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkExistingAdmins() async {
    try {
      final exists = await SupabaseService.client.rpc('admin_exists');
      final hasAdmins = exists == true;
      if (hasAdmins) {
        _hasAdmins = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu sayfaya erişim yetkiniz yok')),
          );
          context.go(Routes.home);
        }
        return;
      }

    } catch (_) {
      if (mounted) {
        context.go(Routes.home);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final setupKey = _setupKeyCtrl.text.trim();
    if (setupKey != Env.adminSetupKey) {
      _showError('Geçersiz kurulum anahtarı');
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Tüm alanları doldurun');
      return;
    }

    if (password.length < 8) {
      _showError('Şifre en az 8 karakter olmalı');
      return;
    }

    if (password != confirm) {
      _showError('Şifreler eşleşmiyor');
      return;
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Geçerli bir email adresi girin');
      return;
    }

    setState(() => _creating = true);

    try {
      final res = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {'user_type': 'admin', 'name': name},
        emailRedirectTo: Env.deepLinkCallback.toString(),
      );

      final user = res.user;
      if (user == null) {
        throw const AuthException('Admin kullanıcısı oluşturulamadı');
      }

      try {
        await SupabaseService.client.from('admins').insert({
          'user_id': user.id,
          'name': name,
          'email': email,
          'role': 'super_admin',
          'permissions': {
            'manage_companies': true,
            'manage_users': true,
            'manage_jobs': true,
            'manage_subscriptions': true,
            'manage_admins': true,
            'view_reports': true,
            'manage_payments': true,
          },
        });
      } catch (e) {
        try {
          await SupabaseService.client.auth.signOut();
        } catch (_) {}
        rethrow;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin hesabı başarıyla oluşturuldu!')),
      );

      if (user.emailConfirmedAt == null) {
        context.go(
          Uri(path: Routes.emailVerification, queryParameters: {'email': email})
              .toString(),
        );
        return;
      }

      final signInRes = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      if (signInRes.user != null) {
        context.go(Routes.adminDashboard);
      } else {
        context.go(Routes.adminLogin);
      }
    } catch (e) {
      _showError(e.toString());
    }
    if (!mounted) return;
    setState(() => _creating = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasAdmins) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFFEDE9FE),
                      child: Icon(Icons.security, size: 36, color: Color(0xFF7C3AED)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'İlk Admin Kurulumu',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Platform için ilk admin hesabını oluşturun',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bu sayfa sadece sistemde hiç admin yokken görüntülenir. '
                              'Oluşturacağınız hesap süper admin yetkilerine sahip olacaktır.',
                              style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      label: 'Kurulum Anahtarı',
                      controller: _setupKeyCtrl,
                      icon: Icons.key_outlined,
                      obscure: true,
                      hint: 'Güvenlik anahtarını girin',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bu anahtarı sistem yöneticisinden alın',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      label: 'Ad Soyad',
                      controller: _nameCtrl,
                      icon: Icons.person_outline,
                      hint: 'Admin User',
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      label: 'E-posta Adresi',
                      controller: _emailCtrl,
                      icon: Icons.mail_outline,
                      hint: 'admin@platform.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      label: 'Şifre',
                      controller: _passwordCtrl,
                      icon: Icons.lock_outline,
                      hint: 'En az 8 karakter',
                      obscure: true,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      label: 'Şifre Tekrar',
                      controller: _confirmCtrl,
                      icon: Icons.lock_outline,
                      hint: 'Şifreyi tekrar girin',
                      obscure: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _creating ? null : _submit,
                        icon: _creating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_creating ? 'Admin oluşturuluyor...' : 'Admin Hesabı Oluştur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
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
