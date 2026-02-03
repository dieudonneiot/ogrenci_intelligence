import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  static const _sectors = <String>[
    'Yazilim',
    'Finans',
    'Egitim',
    'Saglik',
    'Üretim',
    'Danismanlik',
    'E-ticaret',
    'Turizm',
    'Medya',
    'Diger',
  ];

  static const _companySizes = <String>[
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+',
  ];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _foundedYearCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();

  String? _sector;
  String? _employeeCount;
  String _approvalStatus = '';
  String _rejectionReason = '';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    _foundedYearCtrl.dispose();
    _linkedinCtrl.dispose();
    _twitterCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    final companyId = auth?.companyId;
    if (auth == null || auth.userType != UserType.company || companyId == null) return;

    try {
      final repo = ref.read(companyRepositoryProvider);
      final company = await repo.getCompanyById(companyId);
      if (company == null) return;

      _nameCtrl.text = (company['name'] ?? '').toString();
      _sector = (company['sector'] ?? '').toString().trim().isEmpty
          ? null
          : (company['sector'] ?? '').toString();
      _phoneCtrl.text = (company['phone'] ?? '').toString();
      _emailCtrl.text = (company['email'] ?? '').toString();
      _websiteCtrl.text = (company['website'] ?? '').toString();
      _cityCtrl.text = (company['city'] ?? '').toString();
      _addressCtrl.text = (company['address'] ?? '').toString();
      _descriptionCtrl.text = (company['description'] ?? '').toString();
      _foundedYearCtrl.text = (company['founded_year'] ?? '').toString();
      _employeeCount = (company['employee_count'] ?? '').toString().trim().isEmpty
          ? null
          : (company['employee_count'] ?? '').toString();
      _linkedinCtrl.text = (company['linkedin'] ?? '').toString();
      _twitterCtrl.text = (company['twitter'] ?? '').toString();
      _facebookCtrl.text = (company['facebook'] ?? '').toString();
      _instagramCtrl.text = (company['instagram'] ?? '').toString();
      _approvalStatus = (company['approval_status'] ?? '').toString();
      _rejectionReason = (company['rejection_reason'] ?? '').toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final auth = ref.read(authViewStateProvider).value;
    final companyId = auth?.companyId;
    if (auth == null || auth.userType != UserType.company || companyId == null) return;

    final l10n = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      _snack(l10n.t(AppText.companyProfileValidationNameRequired), error: true);
      return;
    }
    if (_sector == null || _sector!.trim().isEmpty) {
      _snack(l10n.t(AppText.companyProfileValidationSectorRequired), error: true);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _snack(l10n.t(AppText.companyProfileValidationPhoneRequired), error: true);
      return;
    }
    if (_cityCtrl.text.trim().isEmpty) {
      _snack(l10n.t(AppText.companyProfileValidationCityRequired), error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(companyRepositoryProvider);
      await repo.updateCompany(companyId, {
        'name': _nameCtrl.text.trim(),
        'sector': _sector,
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        'founded_year': int.tryParse(_foundedYearCtrl.text.trim()),
        'employee_count': _employeeCount,
        'linkedin': _linkedinCtrl.text.trim().isEmpty ? null : _linkedinCtrl.text.trim(),
        'twitter': _twitterCtrl.text.trim().isEmpty ? null : _twitterCtrl.text.trim(),
        'facebook': _facebookCtrl.text.trim().isEmpty ? null : _facebookCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      _snack(l10n.t(AppText.companyProfileUpdated));
    } catch (e) {
      _snack(l10n.commonActionFailed('$e'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t(AppText.companyProfileTitle),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  _StatusBanner(status: _approvalStatus, reason: _rejectionReason),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: l10n.t(AppText.companyProfileSectionBasic),
                    child: Column(
                      children: [
                        _Field(label: l10n.t(AppText.companyProfileFieldNameRequired), controller: _nameCtrl),
                        _DropdownField(
                          label: l10n.t(AppText.companyProfileFieldSectorRequired),
                          value: _sector,
                          items: _sectors,
                          onChanged: (v) => setState(() => _sector = v),
                        ),
                        LayoutBuilder(
                          builder: (context, c) {
                            final narrow = c.maxWidth < 520;
                            if (narrow) {
                              return Column(
                                children: [
                                  _Field(label: l10n.t(AppText.companyProfileFieldPhoneRequired), controller: _phoneCtrl),
                                  _Field(label: l10n.t(AppText.companyProfileFieldEmail), controller: _emailCtrl),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: l10n.t(AppText.companyProfileFieldPhoneRequired),
                                    controller: _phoneCtrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Field(
                                    label: l10n.t(AppText.companyProfileFieldEmail),
                                    controller: _emailCtrl,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        LayoutBuilder(
                          builder: (context, c) {
                            final narrow = c.maxWidth < 520;
                            if (narrow) {
                              return Column(
                                children: [
                                  _Field(label: l10n.t(AppText.companyProfileFieldWebsite), controller: _websiteCtrl),
                                  _Field(label: l10n.t(AppText.companyProfileFieldCityRequired), controller: _cityCtrl),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: l10n.t(AppText.companyProfileFieldWebsite),
                                    controller: _websiteCtrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Field(
                                    label: l10n.t(AppText.companyProfileFieldCityRequired),
                                    controller: _cityCtrl,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        _Field(label: l10n.t(AppText.companyProfileFieldAddress), controller: _addressCtrl, maxLines: 2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: l10n.t(AppText.companyProfileSectionDetails),
                    child: Column(
                      children: [
                        _Field(
                          label: l10n.t(AppText.companyProfileFieldAbout),
                          controller: _descriptionCtrl,
                          maxLines: 3,
                        ),
                        LayoutBuilder(
                          builder: (context, c) {
                            final narrow = c.maxWidth < 520;
                            if (narrow) {
                              return Column(
                                children: [
                                  _Field(
                                    label: l10n.t(AppText.companyProfileFieldFoundedYear),
                                    controller: _foundedYearCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                  _DropdownField(
                                    label: l10n.t(AppText.companyProfileFieldCompanySize),
                                    value: _employeeCount,
                                    items: _companySizes,
                                    onChanged: (v) => setState(() => _employeeCount = v),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: l10n.t(AppText.companyProfileFieldFoundedYear),
                                    controller: _foundedYearCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DropdownField(
                                    label: l10n.t(AppText.companyProfileFieldCompanySize),
                                    value: _employeeCount,
                                    items: _companySizes,
                                    onChanged: (v) => setState(() => _employeeCount = v),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: l10n.t(AppText.companyProfileSectionSocial),
                    child: Column(
                      children: [
                        _Field(label: 'LinkedIn', controller: _linkedinCtrl),
                        _Field(label: 'Twitter', controller: _twitterCtrl),
                        _Field(label: 'Facebook', controller: _facebookCtrl),
                        _Field(label: 'Instagram', controller: _instagramCtrl),
                      ],
                    ),
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
                      label: Text(_saving ? l10n.t(AppText.commonSaving) : l10n.t(AppText.commonSave)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.reason});
  final String status;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (status.isEmpty || status == 'approved') return const SizedBox.shrink();
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'pending':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        text = l10n.t(AppText.companyProfileStatusPending);
        break;
      case 'rejected':
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFB91C1C);
        text = reason.isEmpty
            ? l10n.t(AppText.companyProfileStatusRejected)
            : l10n.companyProfileStatusRejectedWithReason(reason);
        break;
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        text = l10n.companyProfileStatusOther(status);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
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
