import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';

class CompanyInternshipFormScreen extends ConsumerStatefulWidget {
  const CompanyInternshipFormScreen({super.key, this.internshipId});

  final String? internshipId;

  @override
  ConsumerState<CompanyInternshipFormScreen> createState() => _CompanyInternshipFormScreenState();
}

class _CompanyInternshipFormScreenState extends ConsumerState<CompanyInternshipFormScreen> {
  static const _departments = <String>[
    'Bilgisayar Mühendisliği',
    'Elektrik-Elektronik Mühendisliği',
    'Makine Mühendisliği',
    'Endüstri Mühendisliği',
    'İşletme',
    'İnsan Kaynakları',
    'Pazarlama',
    'Muhasebe/Finans',
    'Hukuk',
    'Diğer',
  ];

  static const _workTypes = <String>['on-site', 'remote', 'hybrid'];

  static const _durations = <int>[1, 2, 3, 4, 5, 6, 12];

  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _quotaCtrl = TextEditingController();
  final _monthlyStipendCtrl = TextEditingController();
  final _benefitsCtrl = TextEditingController();

  String? _department;
  String _workType = _workTypes.first;
  int? _durationMonths;
  DateTime? _startDate;
  DateTime? _deadline;
  bool _isPaid = false;
  bool _providesCertificate = true;
  bool _possibilityOfEmployment = false;
  bool _isActive = true;

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
    _quotaCtrl.dispose();
    _monthlyStipendCtrl.dispose();
    _benefitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    if (auth == null || auth.userType != UserType.company) return;

    try {
      if (widget.internshipId != null) {
        final repo = ref.read(companyRepositoryProvider);
        final internship = await repo.getInternshipById(
          internshipId: widget.internshipId!,
          companyId: auth.companyId,
        );
        if (internship != null) {
          _titleCtrl.text = (internship['title'] ?? '').toString();
          _descriptionCtrl.text = (internship['description'] ?? '').toString();
          _requirementsCtrl.text = (internship['requirements'] ?? '').toString();
          _locationCtrl.text = (internship['location'] ?? '').toString();
          _department = (internship['department'] ?? '').toString().trim().isEmpty
              ? null
              : (internship['department'] ?? '').toString();
          _workType = (internship['work_type'] ?? _workType).toString();
          _durationMonths = internship['duration_months'] == null
              ? null
              : int.tryParse(internship['duration_months'].toString());
          _quotaCtrl.text = internship['quota']?.toString() ?? '';
          _monthlyStipendCtrl.text = (internship['monthly_stipend'] ?? '').toString();
          _benefitsCtrl.text = (internship['benefits'] ?? '').toString();
          _isPaid = internship['is_paid'] == true;
          _providesCertificate = internship['provides_certificate'] != false;
          _possibilityOfEmployment = internship['possibility_of_employment'] == true;
          _isActive = internship['is_active'] != false;
          final startRaw = internship['start_date']?.toString();
          final deadlineRaw = internship['deadline']?.toString();
          _startDate = startRaw == null ? null : DateTime.tryParse(startRaw);
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
      _snack('Başlık ve açıklama zorunludur.', error: true);
      return;
    }
    if (_requirementsCtrl.text.trim().isEmpty) {
      _snack('Gereksinimler zorunludur.', error: true);
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
    if (_durationMonths == null) {
      _snack('Süre seçimi zorunludur.', error: true);
      return;
    }
    if (_startDate == null) {
      _snack('Başlangıç tarihi seçin.', error: true);
      return;
    }
    if (_deadline == null) {
      _snack('Son başvuru tarihi seçin.', error: true);
      return;
    }
    if (_quotaCtrl.text.trim().isEmpty) {
      _snack('Kontenjan zorunludur.', error: true);
      return;
    }

    final quota = int.tryParse(_quotaCtrl.text.trim());
    if (quota == null || quota < 1) {
      _snack('Geçerli bir kontenjan girin.', error: true);
      return;
    }

    if (_isPaid && _monthlyStipendCtrl.text.trim().isEmpty) {
      _snack('Ücretli staj için aylık ücret girin.', error: true);
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
        'requirements': _requirementsCtrl.text.trim(),
        'department': _department,
        'location': _locationCtrl.text.trim(),
        'work_type': _workType,
        'duration_months': _durationMonths,
        'start_date': _startDate!.toIso8601String(),
        'quota': quota,
        'monthly_stipend': _isPaid ? _monthlyStipendCtrl.text.trim() : null,
        'benefits': _benefitsCtrl.text.trim().isEmpty ? null : _benefitsCtrl.text.trim(),
        'deadline': _deadline!.toIso8601String(),
        'is_paid': _isPaid,
        'provides_certificate': _providesCertificate,
        'possibility_of_employment': _possibilityOfEmployment,
        'is_remote': _workType == 'remote',
        'is_active': _isActive,
      };

      if (widget.internshipId == null) {
        await repo.createInternship({
          ...payload,
          'company_id': companyId,
          'company_name': companyName,
          'created_by': user.id,
        });
      } else {
        await repo.updateInternship(widget.internshipId!, payload);
      }

      if (!mounted) return;
      _snack(widget.internshipId == null ? 'Staj ilanı oluşturuldu.' : 'Staj ilanı güncellendi.');
      context.go(Routes.companyInternships);
    } catch (e) {
      _snack('Kayıt başarısız: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
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
                        onPressed: () => context.go(Routes.companyInternships),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.internshipId == null ? 'Yeni Staj İlanı' : 'Staj İlanını Düzenle',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      children: [
                        _Field(label: 'Başlık *', controller: _titleCtrl),
                        _Field(label: 'Açıklama *', controller: _descriptionCtrl, maxLines: 4),
                        _Field(label: 'Gereksinimler *', controller: _requirementsCtrl, maxLines: 3),
                        _DropdownField(
                          label: 'Departman *',
                          value: _department,
                          items: _departments,
                          onChanged: (v) => setState(() => _department = v),
                        ),
                        _Field(label: 'Lokasyon *', controller: _locationCtrl),
                        _DropdownField(
                          label: 'Çalışma Şekli',
                          value: _workType,
                          items: _workTypes,
                          onChanged: (v) => setState(() => _workType = v ?? _workType),
                        ),
                        _DropdownFieldInt(
                          label: 'Staj Süresi (Ay) *',
                          value: _durationMonths,
                          items: _durations,
                          onChanged: (v) => setState(() => _durationMonths = v),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Başlangıç Tarihi *',
                                value: _startDate,
                                onPick: _pickStartDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateField(
                                label: 'Son Başvuru *',
                                value: _deadline,
                                onPick: _pickDeadline,
                              ),
                            ),
                          ],
                        ),
                        _Field(
                          label: 'Kontenjan *',
                          controller: _quotaCtrl,
                          keyboardType: TextInputType.number,
                        ),
                        SwitchListTile(
                          value: _isPaid,
                          onChanged: (v) => setState(() => _isPaid = v),
                          title: const Text('Ücretli Staj'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_isPaid)
                          _Field(
                            label: 'Aylık Ücret *',
                            controller: _monthlyStipendCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        _Field(label: 'Yan Haklar', controller: _benefitsCtrl, maxLines: 2),
                        SwitchListTile(
                          value: _providesCertificate,
                          onChanged: (v) => setState(() => _providesCertificate = v),
                          title: const Text('Staj Sertifikası Verilir'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          value: _possibilityOfEmployment,
                          onChanged: (v) => setState(() => _possibilityOfEmployment = v),
                          title: const Text('İş İmkanı Sunulur'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (widget.internshipId != null)
                          SwitchListTile(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            title: const Text('İlan Aktif'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
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

class _DropdownFieldInt extends StatelessWidget {
  const _DropdownFieldInt({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<int> items;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text('$e Ay'))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Tarih seçilmedi'
        : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}
