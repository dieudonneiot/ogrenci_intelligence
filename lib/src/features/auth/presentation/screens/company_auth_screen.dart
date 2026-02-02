import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../controllers/auth_controller.dart';

class CompanyAuthScreen extends ConsumerStatefulWidget {
  const CompanyAuthScreen({super.key, this.initialIsLogin = true});

  final bool initialIsLogin;

  @override
  ConsumerState<CompanyAuthScreen> createState() => _CompanyAuthScreenState();
}

class _CompanyAuthScreenState extends ConsumerState<CompanyAuthScreen> {
  static const _sectors = <String>[
    "Yazılım",
    "Finans",
    "Eğitim",
    "Sağlık",
    "Üretim",
    "Danışmanlık",
    "E-ticaret",
    "Turizm",
    "Diğer",
  ];

  static const _cities = <String>[
    "İstanbul",
    "Ankara",
    "İzmir",
    "Bursa",
    "Antalya",
    "Adana",
    "Konya",
    "Gaziantep",
    "Kayseri",
    "Diğer",
  ];

  late bool _isLogin;
  bool _showPassword = false;
  bool _loading = false;

  // Login
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  // Register
  final _regCompanyName = TextEditingController();
  String? _regSector;
  String? _regCity;
  final _regTaxNumber = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  final _regPhone = TextEditingController();
  final _regAddress = TextEditingController();

  String? _error;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();

    _regCompanyName.dispose();
    _regTaxNumber.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regPhone.dispose();
    _regAddress.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _loginEmail.text.trim();
    final pass = _loginPassword.text;

    if (email.isEmpty || pass.isEmpty) {
      _snack('Lütfen tüm alanları doldurun', error: true);
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      _snack('Please enter a valid email address.', error: true);
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      // 1) Supabase sign-in (your repo already blocks unverified emails)
      final err = await ref
          .read(authActionLoadingProvider.notifier)
          .signIn(email, pass);

      if (err != null) {
        setState(() => _error = err);
        return;
      }

      // 2) Verify that this account is actually a company account
      final repo = ref.read(authRepositoryProvider);
      final user = repo.currentUser;

      if (user == null) {
        setState(() => _error = 'Giriş başarısız: kullanıcı bulunamadı');
        return;
      }

      final membership = await repo.fetchCompanyMembership(user.id);
      if (membership == null) {
        await repo.signOut();
        setState(() => _error = 'Bu hesap bir işletme hesabı değil');
        return;
      }

      _snack('Giriş başarılı!');
      if (!mounted) return;
      context.go(Routes.companyDashboard);
    } catch (e) {
      setState(() => _error = 'Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    final companyName = _regCompanyName.text.trim();
    final sector = _regSector;
    final city = _regCity;
    final tax = _regTaxNumber.text.trim();
    final email = _regEmail.text.trim();
    final pass = _regPassword.text;
    final phone = _regPhone.text.trim();
    final address = _regAddress.text.trim();

    if (companyName.isEmpty ||
        sector == null ||
        city == null ||
        tax.isEmpty ||
        email.isEmpty ||
        pass.isEmpty ||
        phone.isEmpty) {
      _snack('Lütfen tüm zorunlu alanları doldurun', error: true);
      return;
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      _snack('Please enter a valid email address.', error: true);
      return;
    }

    if (pass.length < 6) {
      _snack('Şifre en az 6 karakter olmalıdır', error: true);
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    String? companyId;
    try {
      final client = SupabaseService.client;

      // 1) Tax number uniqueness check
      final existing = await client
          .from('companies')
          .select('id')
          .eq('tax_number', tax)
          .maybeSingle();

      if (existing != null) {
        _snack('Bu vergi numarası ile kayıtlı bir şirket zaten var', error: true);
        return;
      }

      // 2) Create auth user (company user)
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signUp(
        email: email,
        password: pass,
        fullName: companyName,
        metadata: const {'user_type': 'company'},
        emailRedirectTo: Env.deepLinkCallback.toString(),
      );

      // 3) Create company row
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final createdCompany = await client
          .from('companies')
          .insert({
            'name': companyName,
            'sector': sector,
            'tax_number': tax,
            'phone': phone,
            'city': city,
            'address': address.isEmpty ? null : address,
            'email': email,
            'verified': false,
            'created_at': nowIso,
            'updated_at': nowIso,
          })
          .select('id')
          .single();

      companyId = createdCompany['id'] as String;

      // 4) Link user to company in company_users (retry on FK timing)
      await _insertCompanyUserWithRetry(
        client: client,
        companyId: companyId,
        userId: user.id,
        createdAt: nowIso,
      );

      _snack('Kayıt başarılı! Lütfen email adresinizi doğrulayın.');
      if (!mounted) return;

      // Mirror React: switch back to login.
      setState(() => _isLogin = true);

      // Optional: route to email verification page (recommended UX)
      context.go(
        Uri(path: Routes.emailVerification, queryParameters: {'email': email})
            .toString(),
      );
    } on PostgrestException catch (e) {
      if (companyId != null) {
        try {
          await SupabaseService.client.from('companies').delete().eq('id', companyId);
        } catch (_) {}
      }

      if (e.code == '23503') {
        setState(() => _error =
            'Account was created but not fully linked yet. Please verify your email and try again.');
      } else {
        setState(() => _error = 'Bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      if (companyId != null) {
        try {
          await SupabaseService.client.from('companies').delete().eq('id', companyId);
        } catch (_) {}
      }
      setState(() => _error = 'Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _insertCompanyUserWithRetry({
    required SupabaseClient client,
    required String companyId,
    required String userId,
    required String createdAt,
  }) async {
    const maxAttempts = 3;
    var attempt = 0;

    while (true) {
      try {
        await client.from('company_users').insert({
          'company_id': companyId,
          'user_id': userId,
          'role': 'owner',
          'created_at': createdAt,
        });
        return;
      } on PostgrestException catch (e) {
        attempt += 1;
        if (e.code == '23503' && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewStateProvider).value;
    final isAuthed = auth?.isAuthenticated ?? false;

    // If someone is already logged in, let router redirects handle it.
    // (Your app_router already pushes company->dashboard, student->dashboard)
    if (isAuthed) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final w = MediaQuery.of(context).size.width;
    final showLeftPanel = w >= 980;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // slate-900
              Color(0xFF1E293B), // slate-800
              Color(0xFF1E3A8A), // blue-900
            ],
          ),
        ),
        child: Row(
          children: [
            if (showLeftPanel) Expanded(child: _LeftPanel()),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                    color: Colors.black26,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.business, color: Colors.white, size: 44),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _isLogin ? 'İşletme Girişi' : 'İşletme Kaydı',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLogin ? 'Hesabınıza giriş yapın' : 'Yeni işletme hesabı oluşturun',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          const SizedBox(height: 18),

                          if (_isLogin) _buildLoginForm(context) else _buildRegisterForm(context),

                          const SizedBox(height: 14),

                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.red.withOpacity(0.25)),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          _GradientButton(
                            text: _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                            loading: _loading,
                            onPressed: _loading ? null : () async {
                              if (_isLogin) {
                                await _handleLogin();
                              } else {
                                await _handleRegister();
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _isLogin ? 'Hesabınız yok mu?' : 'Zaten hesabınız var mı?',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() {
                                            _error = null;
                                            _isLogin = !_isLogin;
                                          }),
                                  child: Text(
                                    _isLogin ? 'Kayıt Ol' : 'Giriş Yap',
                                    style: const TextStyle(
                                      color: Color(0xFF60A5FA),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 6),
                          Center(
                            child: TextButton(
                              onPressed: _loading ? null : () => context.go(Routes.login),
                              child: const Text(
                                'Öğrenci girişine dön',
                                style: TextStyle(color: Colors.white70),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DarkField(
          label: 'E-posta Adresi',
          controller: _loginEmail,
          keyboardType: TextInputType.emailAddress,
          icon: Icons.mail_outline,
          hint: 'ornek@sirket.com',
        ),
        const SizedBox(height: 12),
        _DarkField(
          label: 'Şifre',
          controller: _loginPassword,
          icon: Icons.lock_outline,
          hint: '••••••••',
          obscureText: !_showPassword,
          suffix: IconButton(
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(
              _showPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DarkField(
          label: 'Şirket Adı *',
          controller: _regCompanyName,
          icon: Icons.apartment,
          hint: 'Şirket adınız',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DarkDropdown(
                label: 'Sektör *',
                value: _regSector,
                items: _sectors,
                icon: Icons.work_outline,
                onChanged: (v) => setState(() => _regSector = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DarkDropdown(
                label: 'Şehir *',
                value: _regCity,
                items: _cities,
                icon: Icons.location_on_outlined,
                onChanged: (v) => setState(() => _regCity = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DarkField(
          label: 'Vergi Numarası *',
          controller: _regTaxNumber,
          icon: Icons.receipt_long_outlined,
          hint: 'Vergi numaranız',
        ),
        const SizedBox(height: 12),
        _DarkField(
          label: 'E-posta Adresi *',
          controller: _regEmail,
          keyboardType: TextInputType.emailAddress,
          icon: Icons.mail_outline,
          hint: 'ornek@sirket.com',
        ),
        const SizedBox(height: 12),
        _DarkField(
          label: 'Şifre *',
          controller: _regPassword,
          icon: Icons.lock_outline,
          hint: 'En az 6 karakter',
          obscureText: !_showPassword,
          suffix: IconButton(
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(
              _showPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DarkField(
          label: 'Telefon *',
          controller: _regPhone,
          keyboardType: TextInputType.phone,
          icon: Icons.phone_outlined,
          hint: '0532 XXX XX XX',
        ),
        const SizedBox(height: 12),
        _DarkField(
          label: 'Adres',
          controller: _regAddress,
          icon: Icons.home_outlined,
          hint: 'Şirket adresi (opsiyonel)',
          maxLines: 2,
        ),
      ],
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    final features = const [
      (Icons.work_outline, 'İlan Yönetimi', 'İş ve staj ilanlarınızı kolayca yönetin'),
      (Icons.people_outline, 'Başvuru Takibi', 'Tüm başvuruları tek panelden inceleyin'),
      (Icons.trending_up, 'Detaylı Analizler', 'İlan performanslarını takip edin'),
      (Icons.emoji_events_outlined, 'Yetenekleri Keşfedin', 'En uygun adayları bulun'),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.20),
                  Colors.purple.withOpacity(0.18),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.business, size: 68, color: Color(0xFF60A5FA)),
                  const SizedBox(height: 14),
                  const Text(
                    'İşletme Yönetim Paneli',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Geleceğin yetenekleriyle buluşun',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 22),
                  ...features.map((f) {
                    final icon = f.$1;
                    final title = f.$2;
                    final desc = f.$3;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(desc, style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: const [
          BoxShadow(blurRadius: 28, offset: Offset(0, 14), color: Colors.black38),
        ],
      ),
      child: child,
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
    );
  }
}

class _DarkDropdown extends StatelessWidget {
  const _DarkDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF111827),
      style: const TextStyle(color: Colors.white),
      items: items
          .map((v) => DropdownMenuItem<String>(
                value: v,
                child: Text(v, style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(blurRadius: 22, offset: Offset(0, 10), color: Colors.black26),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
      ),
    );
  }
}
