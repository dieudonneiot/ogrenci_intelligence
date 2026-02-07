import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _activeTab = 'all';
  _ViewMode _viewMode = _ViewMode.grid;
  bool _loading = true;
  String? _removingId;
  String? _loadedUserId;

  List<_FavoriteItem> _items = const [];

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
      return _GuestView(title: l10n.t(AppText.favoritesLoginRequired));
    }

    _ensureLoaded(user.id);

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Color(0xFFEF4444),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.t(AppText.navFavorites),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.t(AppText.favoritesSubtitle),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FiltersBar(
                    activeTab: _activeTab,
                    items: _items,
                    viewMode: _viewMode,
                    onTab: _setTab,
                    onView: (v) => setState(() => _viewMode = v),
                  ),
                  const SizedBox(height: 14),
                  if (_items.isEmpty)
                    _EmptyFavorites(
                      onCourses: () => context.go(Routes.courses),
                      onJobs: () => context.go(Routes.jobs),
                      onInternships: () => context.go(Routes.internships),
                    )
                  else
                    _viewMode == _ViewMode.grid
                        ? _FavoritesGrid(
                            items: _items,
                            removingId: _removingId,
                            onOpen: _openFavorite,
                            onRemove: _removeFavorite,
                          )
                        : _FavoritesList(
                            items: _items,
                            removingId: _removingId,
                            onOpen: _openFavorite,
                            onRemove: _removeFavorite,
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
      _fetchFavorites(uid);
    });
  }

  void _setTab(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _loading = true;
    });
    final uid = _loadedUserId;
    if (uid != null) {
      _fetchFavorites(uid);
    }
  }

  Future<void> _fetchFavorites(String uid) async {
    setState(() => _loading = true);
    try {
      var query = SupabaseService.client
          .from('favorites')
          .select('*')
          .eq('user_id', uid);

      if (_activeTab != 'all') {
        query = query.eq('type', _activeTab);
      }

      final rows = await query;
      final favorites = <_FavoriteItem>[];

      for (final raw in (rows as List)) {
        final m = raw as Map<String, dynamic>;
        final type = (m['type'] ?? '').toString();
        if (type.isEmpty) continue;

        final details = await _fetchDetails(type, m);
        if (details == null) continue;

        favorites.add(_FavoriteItem.fromMap(m, details));
      }

      if (!mounted) return;
      setState(() => _items = favorites);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).favoritesLoadFailed(e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchDetails(
    String type,
    Map<String, dynamic> fav,
  ) async {
    try {
      if (type == 'course' && fav['course_id'] != null) {
        return await SupabaseService.client
            .from('courses')
            .select('*')
            .eq('id', fav['course_id'])
            .maybeSingle();
      }
      if (type == 'job' && fav['job_id'] != null) {
        return await SupabaseService.client
            .from('jobs')
            .select('*')
            .eq('id', fav['job_id'])
            .maybeSingle();
      }
      if (type == 'internship' && fav['internship_id'] != null) {
        return await SupabaseService.client
            .from('internships')
            .select('*')
            .eq('id', fav['internship_id'])
            .maybeSingle();
      }
    } catch (_) {}

    return null;
  }

  Future<void> _removeFavorite(String id) async {
    setState(() => _removingId = id);
    try {
      await SupabaseService.client.from('favorites').delete().eq('id', id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.id != id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t(AppText.favoritesRemoved),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).commonActionFailed(e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  void _openFavorite(_FavoriteItem item) {
    final path = item.detailPath;
    if (path == null) return;
    context.go(path);
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.activeTab,
    required this.items,
    required this.viewMode,
    required this.onTab,
    required this.onView,
  });

  final String activeTab;
  final List<_FavoriteItem> items;
  final _ViewMode viewMode;
  final ValueChanged<String> onTab;
  final ValueChanged<_ViewMode> onView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = <_TabItem>[
      _TabItem(
        id: 'all',
        label: l10n.t(AppText.commonAll),
        count: items.length,
      ),
      _TabItem(
        id: 'course',
        label: l10n.t(AppText.navCourses),
        count: items.where((e) => e.type == 'course').length,
      ),
      _TabItem(
        id: 'job',
        label: l10n.t(AppText.navJobs),
        count: items.where((e) => e.type == 'job').length,
      ),
      _TabItem(
        id: 'internship',
        label: l10n.t(AppText.navInternships),
        count: items.where((e) => e.type == 'internship').length,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              children: [
                for (final t in tabs)
                  TextButton(
                    onPressed: () => onTab(t.id),
                    style: TextButton.styleFrom(
                      foregroundColor: activeTab == t.id
                          ? const Color(0xFF14B8A6)
                          : const Color(0xFF64748B),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (t.count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${t.count}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => onView(_ViewMode.grid),
            icon: const Icon(Icons.grid_view),
            color: viewMode == _ViewMode.grid
                ? const Color(0xFF14B8A6)
                : const Color(0xFF9CA3AF),
          ),
          IconButton(
            onPressed: () => onView(_ViewMode.list),
            icon: const Icon(Icons.view_list),
            color: viewMode == _ViewMode.list
                ? const Color(0xFF14B8A6)
                : const Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }
}

class _FavoritesGrid extends StatelessWidget {
  const _FavoritesGrid({
    required this.items,
    required this.removingId,
    required this.onOpen,
    required this.onRemove,
  });

  final List<_FavoriteItem> items;
  final String? removingId;
  final ValueChanged<_FavoriteItem> onOpen;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final crossAxis = w >= 1024
            ? 3
            : w >= 768
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (_, i) => _FavoriteCard(
            item: items[i],
            removing: removingId == items[i].id,
            onOpen: () => onOpen(items[i]),
            onRemove: () => onRemove(items[i].id),
          ),
        );
      },
    );
  }
}

class _FavoritesList extends StatelessWidget {
  const _FavoritesList({
    required this.items,
    required this.removingId,
    required this.onOpen,
    required this.onRemove,
  });

  final List<_FavoriteItem> items;
  final String? removingId;
  final ValueChanged<_FavoriteItem> onOpen;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          _FavoriteListRow(
            item: item,
            removing: removingId == item.id,
            onOpen: () => onOpen(item),
            onRemove: () => onRemove(item.id),
          ),
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.item,
    required this.removing,
    required this.onOpen,
    required this.onRemove,
  });

  final _FavoriteItem item;
  final bool removing;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TypeIcon(type: item.type),
                    _TypePill(type: item.type),
                  ],
                ),
              ),
              IconButton(
                onPressed: removing ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFF9CA3AF),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _DetailsBlock(item: item),
          const Spacer(),
          TextButton(
            onPressed: onOpen,
            child: Text(
              AppLocalizations.of(context).t(AppText.commonViewDetailsArrow),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteListRow extends StatelessWidget {
  const _FavoriteListRow({
    required this.item,
    required this.removing,
    required this.onOpen,
    required this.onRemove,
  });

  final _FavoriteItem item;
  final bool removing;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _TypeIcon(type: item.type),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypePill(type: item.type),
                  ],
                ),
                const SizedBox(height: 6),
                _DetailsInline(item: item),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onOpen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
            ),
            child: Text(
              AppLocalizations.of(context).t(AppText.commonViewDetails),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: removing ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
            color: const Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({required this.item});
  final _FavoriteItem item;

  @override
  Widget build(BuildContext context) {
    if (item.type == 'course') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.groups_outlined,
            text: '${item.enrolledCount} öğrenci',
          ),
          const SizedBox(height: 6),
          _DetailRow(icon: Icons.star, text: '${item.rating}/5'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(icon: Icons.business, text: item.company ?? '—'),
        const SizedBox(height: 6),
        _DetailRow(
          icon: Icons.location_on_outlined,
          text: item.location ?? '—',
        ),
      ],
    );
  }
}

class _DetailsInline extends StatelessWidget {
  const _DetailsInline({required this.item});
  final _FavoriteItem item;

  @override
  Widget build(BuildContext context) {
    final meta = item.type == 'course'
        ? '${item.instructor ?? '—'} • ${item.duration ?? '4 Hafta'}'
        : '${item.company ?? '—'} • ${item.location ?? '—'}';

    return Text(
      meta,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case 'course':
        icon = Icons.menu_book_outlined;
        color = const Color(0xFF14B8A6);
        break;
      case 'job':
        icon = Icons.work_outline;
        color = const Color(0xFF2563EB);
        break;
      case 'internship':
        icon = Icons.business_center_outlined;
        color = const Color(0xFF16A34A);
        break;
      default:
        icon = Icons.favorite_border;
        color = const Color(0xFF64748B);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label;
    Color bg;
    Color fg;
    switch (type) {
      case 'course':
        label = l10n.t(AppText.navCourses);
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF14B8A6);
        break;
      case 'job':
        label = l10n.t(AppText.navJobs);
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        break;
      case 'internship':
        label = l10n.t(AppText.navInternships);
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      default:
        label = l10n.t(AppText.navFavorites);
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({
    required this.onCourses,
    required this.onJobs,
    required this.onInternships,
  });

  final VoidCallback onCourses;
  final VoidCallback onJobs;
  final VoidCallback onInternships;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite_border, size: 44, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 8),
          Text(
            l10n.t(AppText.favoritesEmptyTitle),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              TextButton(
                onPressed: onCourses,
                child: Text(l10n.t(AppText.favoritesExploreCourses)),
              ),
              TextButton(
                onPressed: onJobs,
                child: Text(l10n.t(AppText.favoritesBrowseJobs)),
              ),
              TextButton(
                onPressed: onInternships,
                child: Text(l10n.t(AppText.favoritesBrowseInternships)),
              ),
            ],
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
                color: Color(0xFF64748B),
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

class _TabItem {
  const _TabItem({required this.id, required this.label, required this.count});

  final String id;
  final String label;
  final int count;
}

enum _ViewMode { grid, list }

class _FavoriteItem {
  const _FavoriteItem({
    required this.id,
    required this.type,
    required this.details,
    required this.courseId,
    required this.jobId,
    required this.internshipId,
  });

  final String id;
  final String type;
  final Map<String, dynamic> details;
  final String? courseId;
  final String? jobId;
  final String? internshipId;

  String get title => (details['title'] as String?) ?? 'İçerik';
  String? get company =>
      (details['company'] as String?) ??
      (details['company_name'] as String?) ??
      (details['companyName'] as String?);
  String? get location => details['location'] as String?;
  String? get instructor => details['instructor'] as String?;
  String? get duration => details['duration'] as String?;
  int get enrolledCount => (details['enrolled_count'] as num?)?.toInt() ?? 0;
  String get rating => (details['rating']?.toString() ?? '4.5');

  String? get detailPath {
    if (type == 'course' && courseId != null) return '/courses/$courseId';
    if (type == 'job' && jobId != null) return '/jobs/$jobId';
    if (type == 'internship' && internshipId != null) {
      return '/internships/$internshipId';
    }
    return null;
  }

  factory _FavoriteItem.fromMap(
    Map<String, dynamic> map,
    Map<String, dynamic> details,
  ) {
    return _FavoriteItem(
      id: map['id']?.toString() ?? '',
      type: (map['type'] ?? '').toString(),
      details: details,
      courseId: map['course_id']?.toString(),
      jobId: map['job_id']?.toString(),
      internshipId: map['internship_id']?.toString(),
    );
  }
}
