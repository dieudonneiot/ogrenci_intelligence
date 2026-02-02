import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class RegisterCompanyScreen extends ConsumerStatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  ConsumerState<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends ConsumerState<RegisterCompanyScreen> {
  static const _sectors = [
    'Yazılım',
    'Finans',
    'Eğitim',
    'Sağlık',
    'Üretim',
    'Danışmanlık',
    'Diğer',
  ];

  static const _cities = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya',
    'Adana',
    'Diğer',
  ];

  final _nameCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _sector;
  String? _city;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _submit() async {
    final auth = ref.read(authViewStateProvider).value;
    final user = auth?.user;
    if (auth == null || user == null || auth.userType != UserType.company) {
      _snack('Şirket kaydı için giriş yapmalısınız.', error: true);
      return;
    }

    if (_nameCtrl.text.trim().isEmpty ||
        _sector == null ||
        _taxCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _city == null) {
      _snack('Tüm alanları doldurun.', error: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final client = SupabaseService.client;

      final exists = await client
          .from('companies')
          .select('id')
          .eq('tax_number', _taxCtrl.text.trim())
          .maybeSingle();

      if (exists != null) {
        _snack('Bu vergi numarası ile kayıtlı bir şirket zaten var.', error: true);
        return;
      }

      final company = await client
          .from('companies')
          .insert({
            'name': _nameCtrl.text.trim(),
            'sector': _sector,
            'tax_number': _taxCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'city': _city,
            'email': user.email,
            'approval_status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      await client.from('company_users').insert({
        'company_id': company['id'],
        'user_id': user.id,
        'role': 'owner',
        'permissions': 'all',
      });

      if (!mounted) return;
      _snack('Şirket kaydı başarılı!');
      context.go(Routes.companyDashboard);
    } on PostgrestException catch (e) {
      _snack('Kayıt başarısız: ${e.message}', error: true);
    } catch (e) {
      _snack('Kayıt başarısız: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewStateProvider);
    if (authAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = authAsync.value;
    if (auth == null || auth.userType != UserType.company) {
      return const Center(child: Text('Şirket kaydı için giriş yapmalısınız.'));
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.apartment, color: Color(0xFF6D28D9)),
                    SizedBox(width: 8),
                    Text('Şirket Kaydı', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      _Field(label: 'Şirket Adı', controller: _nameCtrl),
                      _DropdownField(
                        label: 'Sektör',
                        value: _sector,
                        items: _sectors,
                        onChanged: (v) => setState(() => _sector = v),
                      ),
                      _Field(label: 'Vergi Numarası', controller: _taxCtrl),
                      _Field(label: 'Telefon', controller: _phoneCtrl),
                      _DropdownField(
                        label: 'Şehir',
                        value: _city,
                        items: _cities,
                        onChanged: (v) => setState(() => _city = v),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: Text(_loading ? 'Kaydediliyor...' : 'Kaydı Tamamla'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
                        ),
                      ),
                    ],
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
