import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  String _activeTab = 'profile';
  bool _loading = false;

  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _currentPasswordCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _prefsLoading = true;
  _NotificationPrefs _prefs = const _NotificationPrefs();

  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController();
    _currentPasswordCtrl = TextEditingController();
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authAsync = ref.watch(authViewStateProvider);
    if (authAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = authAsync.value;
    final user = auth?.user;
    final isLoggedIn = auth?.isAuthenticated ?? false;

    if (!isLoggedIn || user == null) {
      return _GuestView(title: l10n.t(AppText.settingsLoginRequired));
    }

    final meta = user.userMetadata;
    final fullName = (meta is Map<String, dynamic>)
        ? (meta['full_name'] as String?)
        : null;
    _ensureLoaded(user.id, fullName);

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (_, c) {
                      final isWide = c.maxWidth >= 768;
                      final sidebar = _SettingsSidebar(
                        activeTab: _activeTab,
                        onSelect: (id) => setState(() => _activeTab = id),
                      );

                      final content = _SettingsContent(
                        activeTab: _activeTab,
                        fullNameCtrl: _fullNameCtrl,
                        email: user.email ?? '',
                        loading: _loading,
                        onSaveProfile: _saveProfile,
                        currentPasswordCtrl: _currentPasswordCtrl,
                        newPasswordCtrl: _newPasswordCtrl,
                        confirmPasswordCtrl: _confirmPasswordCtrl,
                        showCurrent: _showCurrent,
                        showNew: _showNew,
                        showConfirm: _showConfirm,
                        onToggleCurrent: () =>
                            setState(() => _showCurrent = !_showCurrent),
                        onToggleNew: () => setState(() => _showNew = !_showNew),
                        onToggleConfirm: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        onSavePassword: _savePassword,
                        prefs: _prefs,
                        prefsLoading: _prefsLoading,
                        onTogglePref: _togglePref,
                        onDeleteAccount: _confirmDeleteAccount,
                      );

                      if (!isWide) {
                        return Column(
                          children: [
                            sidebar,
                            const SizedBox(height: 14),
                            content,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 240, child: sidebar),
                          const SizedBox(width: 16),
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _ensureLoaded(String uid, String? fullName) {
    if (_loadedUserId == uid) return;
    _loadedUserId = uid;
    _fullNameCtrl.text = fullName?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences(uid);
    });
  }

  Future<void> _loadPreferences(String uid) async {
    setState(() => _prefsLoading = true);
    try {
      final row = await SupabaseService.client
          .from('notification_preferences')
          .select(
            'email_notifications, new_course_notifications, job_alerts, newsletter',
          )
          .eq('user_id', uid)
          .maybeSingle();

      if (row == null) {
        await SupabaseService.client.from('notification_preferences').insert({
          'user_id': uid,
          'email_notifications': true,
          'new_course_notifications': true,
          'job_alerts': true,
          'newsletter': false,
        });
        if (!mounted) return;
        setState(() => _prefs = const _NotificationPrefs());
      } else {
        if (!mounted) return;
        setState(() => _prefs = _NotificationPrefs.fromMap(row));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = const _NotificationPrefs());
    } finally {
      if (mounted) setState(() => _prefsLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(authViewStateProvider).value?.user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'full_name': _fullNameCtrl.text.trim(),
      });

      await SupabaseService.client
          .from('profiles')
          .update({'full_name': _fullNameCtrl.text.trim()})
          .eq('id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.settingsProfileUpdated))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonUpdateFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePassword() async {
    final l10n = AppLocalizations.of(context);
    final newPassword = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (newPassword != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.commonPasswordsNoMatch))),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.commonPasswordMin))),
      );
      return;
    }

    setState(() => _loading = true);
    final err = await ref
        .read(authActionLoadingProvider.notifier)
        .updatePassword(newPassword);
    if (!mounted) return;

    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsPasswordUpdateFailed(err))),
      );
    } else {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.settingsPasswordUpdated))),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _togglePref(_PrefKey key) async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(authViewStateProvider).value?.user;
    if (user == null) return;

    final updated = _prefs.toggle(key);
    setState(() => _prefs = updated);

    final updates = <String, dynamic>{};
    if (key == _PrefKey.email) updates['email_notifications'] = updated.email;
    if (key == _PrefKey.newCourses) {
      updates['new_course_notifications'] = updated.newCourses;
    }
    if (key == _PrefKey.jobAlerts) updates['job_alerts'] = updated.jobAlerts;
    if (key == _PrefKey.newsletter) updates['newsletter'] = updated.newsletter;

    try {
      await SupabaseService.client
          .from('notification_preferences')
          .update(updates)
          .eq('user_id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.settingsPreferencesUpdated))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonUpdateFailed(e.toString()))),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(authViewStateProvider).value?.user;
    if (user == null) return;

    final ctrl = TextEditingController();
    final phrase = l10n.t(AppText.settingsDeleteAccountConfirmPhrase);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t(AppText.settingsDeleteAccountTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t(AppText.settingsDeleteAccountWarning)),
            const SizedBox(height: 10),
            Text(l10n.t(AppText.settingsDeleteAccountConsequences)),
            const SizedBox(height: 12),
            Text(l10n.settingsDeleteAccountTypeToConfirm(phrase)),
            const SizedBox(height: 6),
            TextField(controller: ctrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t(AppText.commonCancel)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(ctrl.text.trim() == phrase),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: Text(l10n.t(AppText.settingsDeleteAccountButton)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await SupabaseService.client.rpc('delete_user');
      if (!mounted) return;
      await ref.read(authActionLoadingProvider.notifier).signOut();
      if (!mounted) return;
      context.go(Routes.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsDeleteAccountFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Text(
            l10n.t(AppText.navSettings),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({required this.activeTab, required this.onSelect});

  final String activeTab;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _TabTile(
            id: 'profile',
            active: activeTab == 'profile',
            label: l10n.t(AppText.profile),
            icon: Icons.person_outline,
            onTap: onSelect,
          ),
          _TabTile(
            id: 'password',
            active: activeTab == 'password',
            label: l10n.t(AppText.commonPassword),
            icon: Icons.lock_outline,
            onTap: onSelect,
          ),
          _TabTile(
            id: 'notifications',
            active: activeTab == 'notifications',
            label: l10n.t(AppText.navNotifications),
            icon: Icons.notifications_none,
            onTap: onSelect,
          ),
          _TabTile(
            id: 'privacy',
            active: activeTab == 'privacy',
            label: l10n.t(AppText.settingsPrivacy),
            icon: Icons.shield_outlined,
            onTap: onSelect,
          ),
        ],
      ),
    );
  }
}

class _TabTile extends StatelessWidget {
  const _TabTile({
    required this.id,
    required this.active,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final bool active;
  final String label;
  final IconData icon;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTap(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF3E8FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? const Color(0xFF6D28D9) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: active
                    ? const Color(0xFF6D28D9)
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.activeTab,
    required this.fullNameCtrl,
    required this.email,
    required this.loading,
    required this.onSaveProfile,
    required this.currentPasswordCtrl,
    required this.newPasswordCtrl,
    required this.confirmPasswordCtrl,
    required this.showCurrent,
    required this.showNew,
    required this.showConfirm,
    required this.onToggleCurrent,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSavePassword,
    required this.prefs,
    required this.prefsLoading,
    required this.onTogglePref,
    required this.onDeleteAccount,
  });

  final String activeTab;
  final TextEditingController fullNameCtrl;
  final String email;
  final bool loading;
  final VoidCallback onSaveProfile;
  final TextEditingController currentPasswordCtrl;
  final TextEditingController newPasswordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool showCurrent;
  final bool showNew;
  final bool showConfirm;
  final VoidCallback onToggleCurrent;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSavePassword;
  final _NotificationPrefs prefs;
  final bool prefsLoading;
  final ValueChanged<_PrefKey> onTogglePref;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeTab == 'profile') ...[
            Text(
              l10n.t(AppText.settingsProfileInfoTitle),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: fullNameCtrl,
              decoration: InputDecoration(
                labelText: l10n.t(AppText.commonFullName),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: email,
              enabled: false,
              decoration: InputDecoration(
                labelText: l10n.t(AppText.commonEmail),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: loading ? null : onSaveProfile,
              icon: const Icon(Icons.save),
              label: Text(
                loading
                    ? l10n.t(AppText.commonSaving)
                    : l10n.t(AppText.settingsSaveChanges),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
              ),
            ),
          ],
          if (activeTab == 'password') ...[
            Text(
              l10n.t(AppText.settingsChangePasswordTitle),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: currentPasswordCtrl,
              label: l10n.t(AppText.settingsCurrentPassword),
              show: showCurrent,
              onToggle: onToggleCurrent,
            ),
            const SizedBox(height: 10),
            _PasswordField(
              controller: newPasswordCtrl,
              label: l10n.t(AppText.settingsNewPassword),
              show: showNew,
              onToggle: onToggleNew,
            ),
            const SizedBox(height: 10),
            _PasswordField(
              controller: confirmPasswordCtrl,
              label: l10n.t(AppText.settingsNewPasswordRepeat),
              show: showConfirm,
              onToggle: onToggleConfirm,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: loading ? null : onSavePassword,
              icon: const Icon(Icons.lock_outline),
              label: Text(
                loading
                    ? l10n.t(AppText.commonUpdating)
                    : l10n.t(AppText.settingsUpdatePassword),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
              ),
            ),
          ],
          if (activeTab == 'notifications') ...[
            Text(
              l10n.t(AppText.settingsNotificationPreferencesTitle),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            if (prefsLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _PrefTile(
                title: l10n.t(AppText.settingsPrefEmailTitle),
                subtitle: l10n.t(AppText.settingsPrefEmailSubtitle),
                value: prefs.email,
                onChanged: (_) => onTogglePref(_PrefKey.email),
              ),
              _PrefTile(
                title: l10n.t(AppText.settingsPrefNewCoursesTitle),
                subtitle: l10n.t(AppText.settingsPrefNewCoursesSubtitle),
                value: prefs.newCourses,
                onChanged: (_) => onTogglePref(_PrefKey.newCourses),
              ),
              _PrefTile(
                title: l10n.t(AppText.settingsPrefJobAlertsTitle),
                subtitle: l10n.t(AppText.settingsPrefJobAlertsSubtitle),
                value: prefs.jobAlerts,
                onChanged: (_) => onTogglePref(_PrefKey.jobAlerts),
              ),
              _PrefTile(
                title: l10n.t(AppText.settingsPrefNewsletterTitle),
                subtitle: l10n.t(AppText.settingsPrefNewsletterSubtitle),
                value: prefs.newsletter,
                onChanged: (_) => onTogglePref(_PrefKey.newsletter),
              ),
            ],
          ],
          if (activeTab == 'privacy') ...[
            Text(
              l10n.t(AppText.settingsPrivacySecurityTitle),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _InfoBox(
              title: l10n.t(AppText.settingsTwoFactorTitle),
              subtitle: l10n.t(AppText.settingsTwoFactorSubtitle),
              actionLabel: l10n.t(AppText.settingsEnableArrow),
            ),
            const SizedBox(height: 12),
            _VisibilityBox(),
            const SizedBox(height: 16),
            Text(
              l10n.t(AppText.settingsDangerZoneTitle),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 10),
            _DangerRow(
              title: l10n.t(AppText.settingsFreezeAccountTitle),
              subtitle: l10n.t(AppText.settingsFreezeAccountSubtitle),
              actionLabel: l10n.t(AppText.settingsFreezeAccountButton),
              actionColor: const Color(0xFF374151),
              onTap: () => context.go(Routes.excuseRequest),
            ),
            const SizedBox(height: 8),
            _DangerRow(
              title: l10n.t(AppText.settingsDeleteAccountTitle),
              subtitle: l10n.t(AppText.settingsDeleteAccountSubtitle),
              actionLabel: l10n.t(AppText.settingsDeleteAccountButton),
              actionColor: const Color(0xFFEF4444),
              onTap: onDeleteAccount,
            ),
          ],
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(show ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6D28D9),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF6D28D9)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Color(0xFF6D28D9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t(AppText.settingsProfileVisibilityTitle),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _RadioRow(
            label: l10n.t(AppText.settingsVisibilityPublic),
            value: true,
          ),
          _RadioRow(
            label: l10n.t(AppText.settingsVisibilityRegistered),
            value: false,
          ),
          _RadioRow(
            label: l10n.t(AppText.settingsVisibilityHidden),
            value: false,
          ),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.value});
  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 16,
          color: const Color(0xFF6D28D9),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: actionColor == const Color(0xFFEF4444)
            ? const Color(0xFFFEF2F2)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: actionColor == const Color(0xFFEF4444)
              ? const Color(0xFFFECACA)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: actionColor),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 46,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PrefKey { email, newCourses, jobAlerts, newsletter }

class _NotificationPrefs {
  const _NotificationPrefs({
    this.email = true,
    this.newCourses = true,
    this.jobAlerts = true,
    this.newsletter = false,
  });

  final bool email;
  final bool newCourses;
  final bool jobAlerts;
  final bool newsletter;

  _NotificationPrefs toggle(_PrefKey key) {
    switch (key) {
      case _PrefKey.email:
        return _NotificationPrefs(
          email: !email,
          newCourses: newCourses,
          jobAlerts: jobAlerts,
          newsletter: newsletter,
        );
      case _PrefKey.newCourses:
        return _NotificationPrefs(
          email: email,
          newCourses: !newCourses,
          jobAlerts: jobAlerts,
          newsletter: newsletter,
        );
      case _PrefKey.jobAlerts:
        return _NotificationPrefs(
          email: email,
          newCourses: newCourses,
          jobAlerts: !jobAlerts,
          newsletter: newsletter,
        );
      case _PrefKey.newsletter:
        return _NotificationPrefs(
          email: email,
          newCourses: newCourses,
          jobAlerts: jobAlerts,
          newsletter: !newsletter,
        );
    }
  }

  factory _NotificationPrefs.fromMap(Map<String, dynamic> map) {
    return _NotificationPrefs(
      email: (map['email_notifications'] as bool?) ?? true,
      newCourses: (map['new_course_notifications'] as bool?) ?? true,
      jobAlerts: (map['job_alerts'] as bool?) ?? true,
      newsletter: (map['newsletter'] as bool?) ?? false,
    );
  }
}
