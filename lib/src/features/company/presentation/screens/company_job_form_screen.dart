import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
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

    final l10n = AppLocalizations.of(context);
    if (_titleCtrl.text.trim().isEmpty || _descriptionCtrl.text.trim().isEmpty) {
      _snack(l10n.t(AppText.companyJobFormValidationTitleDesc), error: true);
      return;
    }

    if (_department == null || _department!.trim().isEmpty) {
      _snack(l10n.t(AppText.companyJobFormValidationDepartment), error: true);
      return;
    }

    if (_locationCtrl.text.trim().isEmpty) {
      _snack(l10n.t(AppText.companyJobFormValidationLocation), error: true);
      return;
    }

    if (_deadline == null) {
      _snack(l10n.t(AppText.companyJobFormValidationDeadline), error: true);
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
      _snack(widget.jobId == null ? l10n.t(AppText.companyJobFormCreated) : l10n.t(AppText.companyJobFormUpdated));
      context.go(Routes.companyJobs);
    } catch (e) {
      _snack(l10n.commonActionFailed('$e'), error: true);
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
    final l10n = AppLocalizations.of(context);
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
                        widget.jobId == null
                            ? l10n.t(AppText.companyJobFormCreateTitle)
                            : l10n.t(AppText.companyJobFormEditTitle),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      children: [
                        _Field(label: l10n.t(AppText.companyJobFormPositionTitleLabel), controller: _titleCtrl),
                        _Field(
                          label: l10n.t(AppText.companyJobFormDescriptionLabel),
                          controller: _descriptionCtrl,
                          maxLines: 5,
                        ),
                        _Field(
                          label: l10n.t(AppText.companyJobFormRequirementsLabel),
                          controller: _requirementsCtrl,
                          maxLines: 4,
                        ),
                        _DropdownField(
                          label: l10n.t(AppText.companyJobFormDepartmentLabel),
                          value: _department,
                          items: _departments,
                          onChanged: (v) => setState(() => _department = v),
                          itemLabel: (v) => _departmentLabel(l10n, v),
                        ),
                        _Field(label: l10n.t(AppText.companyJobFormLocationLabel), controller: _locationCtrl),
                        _DropdownField(
                          label: l10n.t(AppText.companyJobFormWorkTypeLabel),
                          value: _workType,
                          items: _workTypes,
                          onChanged: (v) => setState(() => _workType = v ?? _workType),
                          itemLabel: (v) => _workTypeLabel(l10n, v),
                        ),
                        SwitchListTile(
                          value: _isRemote,
                          onChanged: (v) => setState(() => _isRemote = v),
                          title: Text(l10n.t(AppText.remote)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        LayoutBuilder(
                          builder: (context, c) {
                            final narrow = c.maxWidth < 520;
                            if (narrow) {
                              return Column(
                                children: [
                                  _Field(
                                    label: l10n.t(AppText.companyJobFormMinExperienceLabel),
                                    controller: _minYearCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                  _Field(
                                    label: l10n.t(AppText.companyJobFormMaxExperienceLabel),
                                    controller: _maxYearCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: l10n.t(AppText.companyJobFormMinExperienceLabel),
                                    controller: _minYearCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Field(
                                    label: l10n.t(AppText.companyJobFormMaxExperienceLabel),
                                    controller: _maxYearCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        _Field(label: l10n.t(AppText.companyJobFormSalaryOptionalLabel), controller: _salaryCtrl),
                        _Field(
                          label: l10n.t(AppText.companyJobFormBenefitsOptionalLabel),
                          controller: _benefitsCtrl,
                          maxLines: 3,
                        ),
                        _Field(
                          label: l10n.t(AppText.companyJobFormContactEmailLabel),
                          controller: _contactEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _deadline == null
                                    ? l10n.t(AppText.companyJobFormDeadlineNotSelected)
                                    : l10n.companyJobFormDeadlineSelected(
                                        MaterialLocalizations.of(context).formatShortDate(_deadline!),
                                      ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickDeadline,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(l10n.t(AppText.companyJobFormPickDate)),
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
                            label: Text(
                              _saving ? l10n.t(AppText.commonSaving) : l10n.t(AppText.commonSave),
                            ),
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

  String _workTypeLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'full-time':
        return l10n.t(AppText.workTypeFullTime);
      case 'part-time':
        return l10n.t(AppText.workTypePartTime);
      case 'intern':
        return l10n.t(AppText.workTypeIntern);
      case 'freelance':
        return l10n.t(AppText.workTypeFreelance);
      default:
        return code;
    }
  }

  String _departmentLabel(AppLocalizations l10n, String department) {
    switch (department) {
      case 'Yazılım Geliştirme':
        return l10n.t(AppText.deptSoftwareDevelopment);
      case 'Satış & Pazarlama':
        return l10n.t(AppText.deptSalesMarketing);
      case 'İnsan Kaynakları':
        return l10n.t(AppText.deptHumanResources);
      case 'Muhasebe & Finans':
        return l10n.t(AppText.deptAccountingFinance);
      case 'Operasyon':
        return l10n.t(AppText.deptOperations);
      case 'Müşteri Hizmetleri':
        return l10n.t(AppText.deptCustomerSupport);
      case 'Ürün Yönetimi':
        return l10n.t(AppText.deptProductManagement);
      case 'Tasarım':
        return l10n.t(AppText.deptDesign);
      case 'Hukuk':
        return l10n.t(AppText.deptLegal);
      case 'Diğer':
        return l10n.t(AppText.deptOther);
      default:
        return department;
    }
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
    this.itemLabel,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String value)? itemLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: (value != null && value!.isNotEmpty) ? value : null,
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(itemLabel == null ? e : itemLabel!(e)),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
