import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../points/application/points_providers.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  static const int _profileCompletionPoints = 20;

  String? _loadedUserId;
  bool _loading = true;
  bool _saving = false;
  bool _editingDept = false;

  _ProfileData? _profile;
  String _tempDepartment = '';
  List<_BadgeItem> _badges = const [];
  List<_CompletedCourse> _completed = const [];
  Map<String, _CourseLite> _courseMap = const {};

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
      return _GuestView(
        title: l10n.t(AppText.profileLoginRequired),
      );
    }

    _ensureLoaded(user.id);

    if (_loading || _profile == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final displayName = _displayName(user, _profile, fallback: l10n.t(AppText.commonStudent));

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
                  _ProfileHeader(
                    name: displayName,
                    email: user.email ?? '',
                  ),
                  const SizedBox(height: 16),
                  _ProfileInfoCard(
                    profile: _profile!,
                    editing: _editingDept,
                    tempDepartment: _tempDepartment,
                    onEdit: () => setState(() => _editingDept = true),
                    onCancel: () => setState(() {
                      _editingDept = false;
                      _tempDepartment = _profile?.department ?? '';
                    }),
                    onDepartmentChanged: (v) => setState(() => _tempDepartment = v),
                    onSave: _saving ? null : _saveDepartment,
                  ),
                  const SizedBox(height: 16),
                  _BadgesCard(badges: _badges),
                  const SizedBox(height: 16),
                  _CompletedCoursesCard(
                    completed: _completed,
                    courseMap: _courseMap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _ensureLoaded(String uid) {
    if (_loadedUserId == uid) return;
    _loadedUserId = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll(uid);
    });
  }

  Future<void> _loadAll(String uid) async {
    setState(() => _loading = true);
    final user = ref.read(authViewStateProvider).value?.user;
    if (user == null) return;

    try {
      final profile = await _loadProfile(user);
      final badges = await _fetchBadges(uid);
      final completedBundle = await _fetchCompletedCourses(uid);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _tempDepartment = profile.department ?? '';
        _badges = badges;
        _completed = completedBundle.items;
        _courseMap = completedBundle.courseMap;
      });

      await _checkProfileCompletion(profile, user.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileLoadFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_ProfileData> _loadProfile(User user) async {
    final row = await SupabaseService.client
        .from('profiles')
        .select('email, department, full_name, phone, year')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      await SupabaseService.client.from('profiles').insert({
        'id': user.id,
        'email': user.email,
        'department': '',
      });
      return _ProfileData(
        email: user.email ?? '',
        department: '',
        fullName: null,
        phone: null,
        year: null,
      );
    }

    return _ProfileData.fromMap(row);
  }

  Future<List<_BadgeItem>> _fetchBadges(String uid) async {
    final rows = await SupabaseService.client
        .from('user_badges')
        .select('id, badge_title, icon')
        .eq('user_id', uid);

    return (rows as List)
        .map((e) => _BadgeItem.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<_CompletedCoursesBundle> _fetchCompletedCourses(String uid) async {
    final rows = await SupabaseService.client
        .from('completed_courses')
        .select('course_id, completed_at')
        .eq('user_id', uid);

    final completed = (rows as List)
        .map((e) => _CompletedCourse.fromMap(e as Map<String, dynamic>))
        .toList();

    if (completed.isEmpty) {
      return _CompletedCoursesBundle(items: completed, courseMap: const {});
    }

    final courseIds = completed.map((e) => e.courseId).toList();

    final courseRows = await SupabaseService.client
        .from('courses')
        .select('id, title, description')
        .inFilter('id', courseIds);

    final map = <String, _CourseLite>{};
    for (final raw in (courseRows as List)) {
      final m = raw as Map<String, dynamic>;
      final id = m['id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = _CourseLite.fromMap(m);
    }

    return _CompletedCoursesBundle(items: completed, courseMap: map);
  }

  Future<void> _saveDepartment() async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(authViewStateProvider).value?.user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'department': _tempDepartment})
          .eq('id', user.id);

      await ref.read(authRepositoryProvider).updateProfile({
        'department': _tempDepartment,
      });

      if (!mounted) return;
      setState(() {
        _profile = _profile?.copyWith(department: _tempDepartment);
        _editingDept = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(AppText.profileUpdated))),
      );

      final updated = _profile;
      if (updated != null) {
        await _checkProfileCompletion(updated, user.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonUpdateFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkProfileCompletion(_ProfileData profile, String uid) async {
    final l10n = AppLocalizations.of(context);
    final completed = _isProfileComplete(profile);
    if (!completed) return;

    final existing = await SupabaseService.client
        .from('activity_logs')
        .select('id')
        .eq('user_id', uid)
        .contains('metadata', {'code': 'profile_completion'})
        .limit(1);

    if ((existing as List).isNotEmpty) return;

    await ref.read(pointsRepositoryProvider).addActivityAndPoints(
          userId: uid,
          category: 'platform',
          action: 'profile_completion',
          points: _profileCompletionPoints,
          source: 'platform',
          description: l10n.t(AppText.profileCompletionDescription),
          metadata: {'code': 'profile_completion'},
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileCompletionAwarded(_profileCompletionPoints))),
    );
  }

  static bool _isProfileComplete(_ProfileData p) {
    final hasName = p.fullName != null && p.fullName!.trim().isNotEmpty;
    final hasDept = p.department != null && p.department!.trim().isNotEmpty;
    final hasPhone = p.phone != null && p.phone!.trim().isNotEmpty;
    final hasYear = p.year != null && p.year! > 0;
    return hasName && hasDept && hasPhone && hasYear;
  }

  static String _displayName(User user, _ProfileData? profile, {required String fallback}) {
    final meta = user.userMetadata;
    final metaName =
        (meta is Map<String, dynamic>) ? (meta['full_name'] as String?)?.trim() : null;
    if (metaName != null && metaName.isNotEmpty) return metaName;
    if (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty) {
      return profile.fullName!.trim();
    }
    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return fallback;
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.mail_outline, color: Color(0xCCFFFFFF), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.profile,
    required this.editing,
    required this.tempDepartment,
    required this.onDepartmentChanged,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  final _ProfileData profile;
  final bool editing;
  final String tempDepartment;
  final ValueChanged<String> onDepartmentChanged;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: Color(0xFF6D28D9)),
              const SizedBox(width: 8),
              Text(l10n.t(AppText.profileInfoTitle),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          _LabeledRow(
            label: l10n.t(AppText.profileEmailAddressLabel),
            child: Row(
              children: [
                const Icon(Icons.mail_outline, size: 18, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Text(profile.email, style: const TextStyle(color: Color(0xFF4B5563))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LabeledRow(
            label: l10n.t(AppText.commonDepartment),
            child: editing
                ? Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: tempDepartment.isEmpty ? null : tempDepartment,
                          decoration: InputDecoration(
                            hintText: l10n.t(AppText.profileSelectDepartmentHint),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(l10n.t(AppText.profileSelectDepartmentHint)),
                            ),
                            for (final dept in _departmentOptions)
                              DropdownMenuItem<String>(
                                value: dept,
                                child: Text(dept),
                              ),
                          ],
                          onChanged: (v) => onDepartmentChanged(v ?? ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onSave,
                        icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                      ),
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 18, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.department?.isNotEmpty == true
                              ? profile.department!
                              : l10n.t(AppText.profileDepartmentNotSelected),
                          style: TextStyle(
                            color: profile.department?.isNotEmpty == true
                                ? const Color(0xFF374151)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, color: Color(0xFF6D28D9)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.badges});
  final List<_BadgeItem> badges;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(l10n.t(AppText.profileBadgesTitle),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          if (badges.isEmpty)
            Text(l10n.t(AppText.profileNoBadges), style: const TextStyle(color: Color(0xFF6B7280)))
          else
            LayoutBuilder(
              builder: (_, c) {
                final isWide = c.maxWidth >= 700;
                final crossAxis = isWide ? 6 : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: badges.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (_, i) {
                    final b = badges[i];
                    return Column(
                      children: [
                        _BadgeIcon(icon: b.icon),
                        const SizedBox(height: 6),
                        Text(
                          b.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CompletedCoursesCard extends StatelessWidget {
  const _CompletedCoursesCard({
    required this.completed,
    required this.courseMap,
  });

  final List<_CompletedCourse> completed;
  final Map<String, _CourseLite> courseMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = completed.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.school, color: Color(0xFF6D28D9)),
            const SizedBox(width: 8),
            Text(
              count == 0
                  ? l10n.t(AppText.profileCompletedCoursesTitle)
                  : l10n.profileCompletedCoursesTitleWithCount(count),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (completed.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                const Icon(Icons.menu_book_outlined, size: 44, color: Color(0xFFD1D5DB)),
                const SizedBox(height: 8),
                Text(l10n.t(AppText.profileNoCompletedCoursesTitle),
                    style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(l10n.t(AppText.profileNoCompletedCoursesSubtitle),
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (_, c) {
              final isWide = c.maxWidth >= 700;
              final crossAxis = isWide ? 2 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: completed.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.6 : 1.35,
                ),
                itemBuilder: (_, i) {
                  final item = completed[i];
                  final course = courseMap[item.courseId];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.menu_book_outlined, color: Color(0xFF6D28D9)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(l10n.t(AppText.profileCourseCompleted),
                                  style: const TextStyle(
                                      color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          course?.title ?? l10n.t(AppText.commonCourse),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          course?.description ?? l10n.t(AppText.profileCourseInfoNotFound),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 14, color: Color(0xFF6B7280)),
                            const SizedBox(width: 6),
                            Text(
                              _fmtDate(context, item.completedAt),
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  static String _fmtDate(BuildContext context, DateTime dt) {
    return MaterialLocalizations.of(context).formatShortDate(dt.toLocal());
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon});
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final raw = icon?.trim();
    if (raw == null || raw.isEmpty) {
      return const _BadgeCircle(child: Icon(Icons.emoji_events_outlined, size: 26));
    }

    if (raw.startsWith('<svg')) {
      return _BadgeCircle(
        child: SvgPicture.string(
          raw,
          width: 28,
          height: 28,
        ),
      );
    }

    return _BadgeCircle(
      child: Text(raw, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const _BadgeCircle({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ],
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
              const Icon(Icons.lock_outline, size: 46, color: Color(0xFF6B7280)),
              const SizedBox(height: 10),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.email,
    required this.department,
    required this.fullName,
    required this.phone,
    required this.year,
  });

  final String email;
  final String? department;
  final String? fullName;
  final String? phone;
  final int? year;

  _ProfileData copyWith({
    String? department,
  }) {
    return _ProfileData(
      email: email,
      department: department ?? this.department,
      fullName: fullName,
      phone: phone,
      year: year,
    );
  }

  factory _ProfileData.fromMap(Map<String, dynamic> map) {
    return _ProfileData(
      email: (map['email'] ?? '') as String,
      department: (map['department'] as String?)?.trim(),
      fullName: (map['full_name'] as String?)?.trim(),
      phone: (map['phone'] as String?)?.trim(),
      year: (map['year'] as num?)?.toInt(),
    );
  }
}

class _BadgeItem {
  const _BadgeItem({
    required this.id,
    required this.title,
    required this.icon,
  });

  final String id;
  final String title;
  final String? icon;

  factory _BadgeItem.fromMap(Map<String, dynamic> map) {
    return _BadgeItem(
      id: map['id']?.toString() ?? '',
      title: (map['badge_title'] ?? '') as String,
      icon: map['icon'] as String?,
    );
  }
}

class _CompletedCourse {
  const _CompletedCourse({
    required this.courseId,
    required this.completedAt,
  });

  final String courseId;
  final DateTime completedAt;

  factory _CompletedCourse.fromMap(Map<String, dynamic> map) {
    final raw = map['completed_at']?.toString() ?? '';
    return _CompletedCourse(
      courseId: map['course_id']?.toString() ?? '',
      completedAt: DateTime.tryParse(raw) ?? DateTime.now(),
    );
  }
}

class _CourseLite {
  const _CourseLite({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  factory _CourseLite.fromMap(Map<String, dynamic> map) {
    return _CourseLite(
      id: map['id']?.toString() ?? '',
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? 'Açıklama yok.') as String,
    );
  }
}

class _CompletedCoursesBundle {
  const _CompletedCoursesBundle({
    required this.items,
    required this.courseMap,
  });

  final List<_CompletedCourse> items;
  final Map<String, _CourseLite> courseMap;
}

const List<String> _departmentOptions = <String>[
  'Bilgisayar Mühendisliği',
  'Elektrik-Elektronik Mühendisliği',
  'İşletme',
  'İktisat',
  'Endüstri Mühendisliği',
  'Hukuk',
  'Psikoloji',
  'İletişim',
  'Mimarlık',
  'Uluslararası İlişkiler',
  'Yazılım Mühendisliği',
  'Sigortacılık',
  'Sanat',
  'İnternet ve Ağ Teknolojileri',
  'Diğer',
];
