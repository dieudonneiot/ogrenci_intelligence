import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';

class CompanyJobFormScreen extends ConsumerStatefulWidget {
  const CompanyJobFormScreen({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<CompanyJobFormScreen> createState() => _CompanyJobFormScreenState();
}

class _CompanyJobFormScreenState extends ConsumerState<CompanyJobFormScreen> {
  static const _departments = <String>[
    'Yazılım Geliştirme',
    'Satış & Pazarlama',
    'İnsan Kaynakları',
    'Muhasebe & Finans',
    'Operasyon',
    'Müşteri Hizmetleri',
    'Ürün Yönetimi',
    'Tasarım',
    'Hukuk',
    'Diğer',
  ];

  static const _workTypes = <String>[
    'full-time',
    'part-time',
    'intern',
    'freelance',
  ];

  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _minYearCtrl = TextEditingController();
  final _maxYearCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _benefitsCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();

  String? _department;
  String _workType = _workTypes.first;
  bool _isRemote = false;
  DateTime? _deadline;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _requirementsCtrl.dispose();
    _locationCtrl.dispose();
    _minYearCtrl.dispose();
    _maxYearCtrl.dispose();
    _salaryCtrl.dispose();
    _benefitsCtrl.dispose();
    _contactEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    if (auth == null || auth.userType != UserType.company) return;

    try {
      final repo = ref.read(companyRepositoryProvider);
      final companyId = auth.companyId;
      if (companyId != null && _contactEmailCtrl.text.isEmpty) {
        final company = await repo.getCompanyById(companyId);
        _contactEmailCtrl.text = (company?['email'] ?? '').toString();
      }

      if (widget.jobId != null) {
        final job = await repo.getJobById(jobId: widget.jobId!, companyId: companyId);
        if (job != null) {
          _titleCtrl.text = (job['title'] ?? '').toString();
          _descriptionCtrl.text = (job['description'] ?? '').toString();
          _requirementsCtrl.text = (job['requirements'] ?? '').toString();
          _locationCtrl.text = (job['location'] ?? '').toString();
          _department = (job['department'] ?? '').toString().trim().isEmpty
              ? null
              : (job['department'] ?? '').toString();
          _workType = (job['work_type'] ?? _workType).toString();
          _isRemote = job['is_remote'] == true;
          _minYearCtrl.text = job['min_year']?.toString() ?? '';
          _maxYearCtrl.text = job['max_year']?.toString() ?? '';
          _salaryCtrl.text = (job['salary'] ?? '').toString();
          _benefitsCtrl.text = (job['benefits'] ?? '').toString();
          _contactEmailCtrl.text = (job['contact_email'] ?? _contactEmailCtrl.text).toString();
          final deadlineRaw = job['deadline']?.toString();
          _deadline = deadlineRaw == null ? null : DateTime.tryParse(deadlineRaw);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final auth = ref.read(authViewStateProvider).value;
    final user = auth?.user;
    final companyId = auth?.companyId;
    if (auth == null || user == null || companyId == null) return;

    if (_titleCtrl.text.trim().isEmpty || _descriptionCtrl.text.trim().isEmpty) {
      _snack('Lütfen başlık ve açıklama girin.', error: true);
      return;
    }

    if (_department == null || _department!.trim().isEmpty) {
      _snack('Departman seçimi zorunludur.', error: true);
      return;
    }

    if (_locationCtrl.text.trim().isEmpty) {
      _snack('Lokasyon zorunludur.', error: true);
      return;
    }

    if (_deadline == null) {
      _snack('Son başvuru tarihi seçin.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(companyRepositoryProvider);
      final company = await repo.getCompanyById(companyId);
      final companyName = (company?['name'] ?? '').toString();

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'requirements': _requirementsCtrl.text.trim().isEmpty ? null : _requirementsCtrl.text.trim(),
        'department': _department,
        'location': _locationCtrl.text.trim(),
        'work_type': _workType,
        'type': _workType == 'part-time' ? 'part-time' : 'departmental',
        'min_year': int.tryParse(_minYearCtrl.text.trim()) ?? 0,
        'max_year': int.tryParse(_maxYearCtrl.text.trim()) ?? 5,
        'salary': _salaryCtrl.text.trim().isEmpty ? null : _salaryCtrl.text.trim(),
        'benefits': _benefitsCtrl.text.trim().isEmpty ? null : _benefitsCtrl.text.trim(),
        'contact_email': _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim(),
        'deadline': _deadline!.toIso8601String(),
        'is_remote': _isRemote,
      };

      if (widget.jobId == null) {
        await repo.createJob({
          ...payload,
          'company_id': companyId,
          'company': companyName,
          'created_by': user.id,
          'is_active': true,
        });
      } else {
        await repo.updateJob(widget.jobId!, payload);
      }

      if (!mounted) return;
      _snack(widget.jobId == null ? 'İlan oluşturuldu.' : 'İlan güncellendi.');
      context.go(Routes.companyJobs);
    } catch (e) {
      _snack('Kayıt başarısız: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDeadline() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.go(Routes.companyJobs),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.jobId == null ? 'Yeni İş İlanı' : 'İlanı Düzenle',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      children: [
                        _Field(label: 'Pozisyon Başlığı *', controller: _titleCtrl),
                        _Field(label: 'İş Tanımı *', controller: _descriptionCtrl, maxLines: 5),
                        _Field(label: 'Gereksinimler', controller: _requirementsCtrl, maxLines: 4),
                        _DropdownField(
                          label: 'Departman *',
                          value: _department,
                          items: _departments,
                          onChanged: (v) => setState(() => _department = v),
                        ),
                        _Field(label: 'Lokasyon *', controller: _locationCtrl),
                        _DropdownField(
                          label: 'Çalışma Tipi',
                          value: _workType,
                          items: _workTypes,
                          onChanged: (v) => setState(() => _workType = v ?? _workType),
                        ),
                        SwitchListTile(
                          value: _isRemote,
                          onChanged: (v) => setState(() => _isRemote = v),
                          title: const Text('Remote'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        Row(
                          children: [
                            Expanded(child: _Field(label: 'Min Deneyim', controller: _minYearCtrl, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _Field(label: 'Max Deneyim', controller: _maxYearCtrl, keyboardType: TextInputType.number)),
                          ],
                        ),
                        _Field(label: 'Maaş (opsiyonel)', controller: _salaryCtrl),
                        _Field(label: 'Yan Haklar (opsiyonel)', controller: _benefitsCtrl, maxLines: 3),
                        _Field(label: 'İletişim E-postası', controller: _contactEmailCtrl, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _deadline == null
                                    ? 'Son başvuru tarihi seçilmedi'
                                    : 'Son başvuru: ${_deadline!.day.toString().padLeft(2, '0')}.${_deadline!.month.toString().padLeft(2, '0')}.${_deadline!.year}',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickDeadline,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: const Text('Tarih Seç'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
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
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
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
        initialValue: (value != null && value!.isNotEmpty) ? value : null,
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
