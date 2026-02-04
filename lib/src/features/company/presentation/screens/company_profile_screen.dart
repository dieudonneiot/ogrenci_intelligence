import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/supabase/supabase_service.dart';
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
    'Yazılım',
    'Finans',
    'Eğitim',
    'Sağlık',
    'Üretim',
    'Danışmanlık',
    'E-ticaret',
    'Turizm',
    'Medya',
    'Diğer',
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
  String? _logoUrl;
  String? _coverUrl;
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
      final rawLogo = (company['logo_url'] as String?)?.trim();
      final rawCover = (company['cover_image_url'] as String?)?.trim();
      _logoUrl = (rawLogo == null || rawLogo.isEmpty) ? null : rawLogo;
      _coverUrl = (rawCover == null || rawCover.isEmpty) ? null : rawCover;
      _approvalStatus = (company['approval_status'] ?? '').toString();
      _rejectionReason = (company['rejection_reason'] ?? '').toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAsset({
    required String companyId,
    required String kind, // 'logo' | 'cover'
  }) async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Images', extensions: <String>['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (file == null) return;

    setState(() => _saving = true);
    try {
      final bytes = await file.readAsBytes();
      final safe = file.name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
      final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      final path = '$companyId/${kind}_${stamp}_$safe';

      await SupabaseService.client.storage.from('company-assets').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFromName(file.name) ?? 'image/png',
            ),
          );

      final publicUrl = SupabaseService.client.storage.from('company-assets').getPublicUrl(path);

      final updates = <String, dynamic>{};
      if (kind == 'logo') updates['logo_url'] = publicUrl;
      if (kind == 'cover') updates['cover_image_url'] = publicUrl;

      await SupabaseService.client.from('companies').update(updates).eq('id', companyId);

      if (!mounted) return;
      setState(() {
        if (kind == 'logo') _logoUrl = publicUrl;
        if (kind == 'cover') _coverUrl = publicUrl;
      });

      _snack(l10n.t(AppText.companyProfileUpdated));
    } catch (e) {
      _snack(l10n.commonActionFailed(e.toString()), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String? _contentTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
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
	                  const SizedBox(height: 12),
	                  _BrandAssetsCard(
	                    logoUrl: _logoUrl,
	                    coverUrl: _coverUrl,
	                    onChangeLogo: _saving
	                        ? null
	                        : () {
	                            final auth = ref.read(authViewStateProvider).value;
	                            final companyId = auth?.companyId;
	                            if (companyId == null) return;
	                            _pickAndUploadAsset(companyId: companyId, kind: 'logo');
	                          },
	                    onChangeCover: _saving
	                        ? null
	                        : () {
	                            final auth = ref.read(authViewStateProvider).value;
	                            final companyId = auth?.companyId;
	                            if (companyId == null) return;
	                            _pickAndUploadAsset(companyId: companyId, kind: 'cover');
	                          },
	                  ),
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

class _BrandAssetsCard extends StatelessWidget {
  const _BrandAssetsCard({
    required this.logoUrl,
    required this.coverUrl,
    required this.onChangeLogo,
    required this.onChangeCover,
  });

  final String? logoUrl;
  final String? coverUrl;
  final VoidCallback? onChangeLogo;
  final VoidCallback? onChangeCover;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl != null && coverUrl!.trim().isNotEmpty)
                Image.network(coverUrl!, fit: BoxFit.cover)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                top: 12,
                child: _AssetButton(
                  icon: Icons.image_outlined,
                  label: 'Cover',
                  onTap: onChangeCover,
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: (logoUrl != null && logoUrl!.trim().isNotEmpty)
                                ? Image.network(logoUrl!, fit: BoxFit.cover)
                                : const Icon(Icons.apartment_outlined, size: 34, color: Color(0xFF6D28D9)),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: _IconFab(
                            icon: Icons.edit,
                            onTap: onChangeLogo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: const Text(
                        'Company branding',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetButton extends StatelessWidget {
  const _AssetButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconFab extends StatelessWidget {
  const _IconFab({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 6))],
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
        ),
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

  String _norm(String s) {
    return s
        .trim()
        .toLowerCase()
        // Turkish chars -> ascii-ish (to match older stored values)
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  @override
  Widget build(BuildContext context) {
    // Prevent DropdownButton assertion when DB value doesn't exactly match items.
    final uniqueItems = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();
    final raw = value?.trim();

    String? safeValue;
    if (raw != null && raw.isNotEmpty) {
      if (uniqueItems.contains(raw)) {
        safeValue = raw;
      } else {
        // Try normalized match (e.g., "Yazılım" vs "Yazilim")
        final n = _norm(raw);
        safeValue = uniqueItems.cast<String?>().firstWhere(
              (it) => it != null && _norm(it) == n,
              orElse: () => null,
            );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: safeValue,
        items: uniqueItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
