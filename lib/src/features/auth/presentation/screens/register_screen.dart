import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
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
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);

    final email = _email.text.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() => _error = l10n.t(AppText.commonInvalidEmail));
      return false;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = l10n.t(AppText.commonPasswordsNoMatch));
      return false;
    }
    if (_password.text.length < 6) {
      setState(() => _error = l10n.t(AppText.commonPasswordMin));
      return false;
    }
    if (_department == null) {
      setState(() => _error = l10n.t(AppText.authSelectDepartment));
      return false;
    }
    if (_year == null) {
      setState(() => _error = l10n.t(AppText.authSelectYear));
      return false;
    }
    if (!_acceptTerms) {
      setState(() => _error = l10n.t(AppText.authAcceptTermsError));
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
        .signUp(
          email: email,
          password: pass,
          fullName: fullName,
          metadata: const {'user_type': 'student'},
          redirectTo: Env.deepLinkCallback.toString(),
        );

    if (!mounted) return;

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // Try to update profile (same as React). Ignore errors if RLS blocks it.
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        await SupabaseService.client.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName,
          'department': _department,
          'year': _year,
          'email': email,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {
      // ignore
    }

    // Professional flow: show email verification page, with email hint
    final uri = Uri(
      path: Routes.emailVerification,
      queryParameters: {'email': email},
    ).toString();

    if (!mounted) return;
    context.go(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authActionLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF115E59), Color(0xFF0F766E), Color(0xFF4338CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          size: 38,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.t(AppText.authCreateAccount),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t(AppText.authStudentRegisterSubtitle),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: _fullName,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonFullName),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonEmail),
                        prefixIcon: const Icon(Icons.mail_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _department,
                      isExpanded: true,
                      items: departments
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _department = v),
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonDepartment),
                        prefixIcon: const Icon(Icons.school_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      initialValue: _year,
                      isExpanded: true,
                      items: const [1, 2, 3, 4, 5]
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(
                                y == 5 ? l10n.t(AppText.authYearPlus) : '$y',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _year = v),
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonYear),
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonPassword),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _confirm,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: l10n.t(AppText.commonConfirmPassword),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (v) =>
                              setState(() => _acceptTerms = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              children: [
                                Text(l10n.t(AppText.authAcceptTermsPrefix)),
                                GestureDetector(
                                  onTap: () => context.push(Routes.terms),
                                  child: Text(
                                    l10n.t(AppText.linkTerms),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(l10n.t(AppText.authAcceptTermsAnd)),
                                GestureDetector(
                                  onTap: () => context.push(Routes.privacy),
                                  child: Text(
                                    l10n.t(AppText.linkPrivacy),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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

                    const SizedBox(height: 14),

                    ElevatedButton(
                      onPressed: busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.t(AppText.authRegisterTitle)),
                    ),

                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),

                    OutlinedButton(
                      onPressed: () => context.push(Routes.companyAuth),
                      child: Text(l10n.t(AppText.authRegisterAsCompany)),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${l10n.t(AppText.authAlreadyHaveAccount)} '),
                        TextButton(
                          onPressed: () => context.go(Routes.login),
                          child: Text(l10n.t(AppText.authLoginTitle)),
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
