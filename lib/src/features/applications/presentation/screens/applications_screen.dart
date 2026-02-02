import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../application/applications_providers.dart';
import '../../domain/applications_models.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();

  String _search = '';
  ApplicationStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this); // All, Jobs, Internships, Courses
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {
          // reset invalid status filters per-tab if needed
          _statusFilter = _sanitizeStatusFilter(_tabs.index, _statusFilter);
        });
      }
    });

    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  ApplicationStatus? _sanitizeStatusFilter(int tabIndex, ApplicationStatus? current) {
    if (current == null) return null;

    if (tabIndex == 1 || tabIndex == 2) {
      // jobs or internships
      if (current == ApplicationStatus.active || current == ApplicationStatus.completed) return null;
    }
    if (tabIndex == 3) {
      // courses
      if (current == ApplicationStatus.pending || current == ApplicationStatus.accepted || current == ApplicationStatus.rejected) {
        return null;
      }
    }
    return current;
  }

  Future<void> _refresh() async {
    ref.invalidate(myApplicationsBundleProvider);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewStateProvider);
    final isLoggedIn = (!authAsync.isLoading) && (authAsync.value?.isAuthenticated ?? false);

    if (!isLoggedIn) {
      return _Guest();
    }

    final bundleAsync = ref.watch(myApplicationsBundleProvider);

    return bundleAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (e, _) => _ErrorState(
        text: 'Başvurular yüklenemedi: $e',
        onRetry: () => ref.invalidate(myApplicationsBundleProvider),
      ),
      data: (bundle) {
        final all = bundle.all;
        final jobsCount = bundle.jobs.length;
        final internshipsCount = bundle.internships.length;
        final coursesCount = bundle.courses.length;

        final activeItems = _itemsForTab(bundle, _tabs.index);

        // Stats like React
        final total = activeItems.length;
        final pending = _countStatus(activeItems, ApplicationStatus.pending);
        final accepted = _countStatus(activeItems, ApplicationStatus.accepted);
        final active = _countStatus(activeItems, ApplicationStatus.active);

        return Container(
          color: const Color(0xFFF9FAFB),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF6D28D9), size: 30),
                            SizedBox(width: 10),
                            Text('Başvurularım', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tüm başvuru ve kayıtlarınızı buradan takip edebilirsiniz.',
                          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),

                        LayoutBuilder(
                          builder: (_, c) {
                            final wide = c.maxWidth >= 900;
                            final cards = <Widget>[
                              _StatTile(title: 'Toplam', value: '$total', icon: Icons.list_alt),
                              _StatTile(title: 'Beklemede', value: '$pending', icon: Icons.hourglass_bottom),
                              _StatTile(title: 'Kabul', value: '$accepted', icon: Icons.check_circle_outline),
                              _StatTile(title: 'Aktif', value: '$active', icon: Icons.bolt_outlined),
                            ];

                            if (wide) {
                              return Row(
                                children: [
                                  for (int i = 0; i < cards.length; i++) ...[
                                    Expanded(child: cards[i]),
                                    if (i != cards.length - 1) const SizedBox(width: 12),
                                  ],
                                ],
                              );
                            }
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: cards.map((w) => SizedBox(width: (c.maxWidth - 12) / 2, child: w)).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        _FiltersBar(
                          controller: _searchCtrl,
                          status: _statusFilter,
                          statusOptions: _statusOptionsForTab(_tabs.index),
                          onStatusChanged: (s) => setState(() => _statusFilter = s),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: TabBar(
                            controller: _tabs,
                            isScrollable: true,
                            labelColor: const Color(0xFF111827),
                            unselectedLabelColor: const Color(0xFF6B7280),
                            labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                            indicatorColor: const Color(0xFF6D28D9),
                            onTap: (i) => setState(() => _statusFilter = _sanitizeStatusFilter(i, _statusFilter)),
                            tabs: [
                              Tab(child: _TabLabel(text: 'Tümü', count: all.length)),
                              Tab(child: _TabLabel(text: 'İş İlanları', count: jobsCount)),
                              Tab(child: _TabLabel(text: 'Stajlar', count: internshipsCount)),
                              Tab(child: _TabLabel(text: 'Kurslar', count: coursesCount)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          height: 740,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _ListViewTab(
                                items: _applyFilter(all),
                                emptyText: 'Henüz başvurunuz bulunmuyor.',
                                onOpen: _openItem,
                              ),
                              _ListViewTab(
                                items: _applyFilter(bundle.jobs),
                                emptyText: 'Henüz başvurunuz bulunmuyor.',
                                onOpen: _openItem,
                              ),
                              _ListViewTab(
                                items: _applyFilter(bundle.internships),
                                emptyText: 'Henüz başvurunuz bulunmuyor.',
                                onOpen: _openItem,
                              ),
                              _ListViewTab(
                                items: _applyFilter(bundle.courses),
                                emptyText: 'Henüz başvurunuz bulunmuyor.',
                                onOpen: _openItem,
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
          ),
        );
      },
    );
  }

  List<ApplicationStatus> _statusOptionsForTab(int tabIndex) {
    // 0 all, 1 jobs, 2 internships, 3 courses
    if (tabIndex == 1 || tabIndex == 2) {
      return const [ApplicationStatus.pending, ApplicationStatus.accepted, ApplicationStatus.rejected];
    }
    if (tabIndex == 3) return const [ApplicationStatus.active, ApplicationStatus.completed];
    return const [
      ApplicationStatus.pending,
      ApplicationStatus.accepted,
      ApplicationStatus.rejected,
      ApplicationStatus.active,
      ApplicationStatus.completed,
    ];
  }

  List<ApplicationListItem> _itemsForTab(ApplicationsBundle bundle, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return bundle.jobs;
      case 2:
        return bundle.internships;
      case 3:
        return bundle.courses;
      default:
        return bundle.all;
    }
  }

  int _countStatus(List<ApplicationListItem> items, ApplicationStatus status) {
    return items.where((e) => e.status == status).length;
  }

  List<ApplicationListItem> _applyFilter(List<ApplicationListItem> items) {
    Iterable<ApplicationListItem> out = items;

    if (_search.isNotEmpty) {
      out = out.where((e) => e.searchBlob.contains(_search));
    }
    if (_statusFilter != null) {
      out = out.where((e) => e.status == _statusFilter);
    }

    final list = out.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  void _openItem(BuildContext context, ApplicationListItem item) {
    switch (item.kind) {
      case ApplicationKind.internship:
        context.go('/internships/${item.refId}');
        return;
      case ApplicationKind.course:
        context.go('/courses/${item.refId}');
        return;
      case ApplicationKind.job:
        // when jobs screens exist
        context.go('/jobs/${item.refId}');
        return;
    }
  }
}

/* ---------------- UI bits ---------------- */

class _Guest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock_outline, size: 44, color: Color(0xFF6B7280)),
              SizedBox(height: 10),
              Text('Başvuruları görmek için giriş yapmalısın.',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SizedBox(height: 44, child: ElevatedButton(onPressed: onRetry, child: const Text('Tekrar dene'))),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF6D28D9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.controller,
    required this.status,
    required this.statusOptions,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final ApplicationStatus? status;
  final List<ApplicationStatus> statusOptions;
  final ValueChanged<ApplicationStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Başvuru ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (statusOptions.isEmpty)
          const SizedBox(width: 160)
        else
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<ApplicationStatus?>(
              initialValue: status,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              items: [
                const DropdownMenuItem<ApplicationStatus?>(value: null, child: Text('Tüm Durumlar')),
                for (final s in statusOptions)
                  DropdownMenuItem<ApplicationStatus?>(value: s, child: Text(_statusText(s))),
              ],
              onChanged: onStatusChanged,
            ),
          ),
      ],
    );
  }

  static String _statusText(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.pending:
        return 'Beklemede';
      case ApplicationStatus.accepted:
        return 'Kabul';
      case ApplicationStatus.rejected:
        return 'Reddedildi';
      case ApplicationStatus.active:
        return 'Aktif';
      case ApplicationStatus.completed:
        return 'Tamamlandı';
    }
  }
}

class _ListViewTab extends StatelessWidget {
  const _ListViewTab({
    required this.items,
    required this.emptyText,
    required this.onOpen,
  });

  final List<ApplicationListItem> items;
  final String emptyText;
  final void Function(BuildContext, ApplicationListItem) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.work_outline, size: 46, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 10),
                Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _EmptyCta(
                      label: 'İş İlanlarına Göz At',
                      onTap: () => context.go('/jobs'),
                    ),
                    const Text('•', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w900)),
                    _EmptyCta(
                      label: 'Stajları Keşfet',
                      onTap: () => context.go('/internships'),
                    ),
                    const Text('•', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w900)),
                    _EmptyCta(
                      label: 'Kurslara Katıl',
                      onTap: () => context.go('/courses'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      padding: const EdgeInsets.only(bottom: 12),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ApplicationCard(item: items[i], onOpen: onOpen),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.item, required this.onOpen});
  final ApplicationListItem item;
  final void Function(BuildContext, ApplicationListItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final pill = _pill(item.status);

    final kindLabel = item.kind == ApplicationKind.internship
        ? 'Staj'
        : item.kind == ApplicationKind.course
            ? 'Kurs'
            : 'İş';

    final detailText = [
      if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
      if (item.department != null && item.department!.isNotEmpty) item.department!,
      if (item.meta != null && item.meta!.isNotEmpty) item.meta!,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(14)),
            child: Icon(
              item.kind == ApplicationKind.internship
                  ? Icons.business_center_outlined
                  : item.kind == ApplicationKind.course
                      ? Icons.menu_book_outlined
                      : Icons.work_outline,
              color: const Color(0xFF6D28D9),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: pill.bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(pill.text,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: pill.fg)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (detailText.isNotEmpty) ...[
                  Text(
                    detailText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                ] else
                  const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                      child: Text(kindLabel,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF374151))),
                    ),
                    const Spacer(),
                    Text(
                      _fmt(item.date),
                      style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => onOpen(context, item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Detay →', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
                if (item.progress != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('İlerleme', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('%${item.progress}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (item.progress ?? 0) / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6D28D9)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static _Pill _pill(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.pending:
        return const _Pill('Beklemede', Color(0xFF92400E), Color(0xFFFEF3C7));
      case ApplicationStatus.accepted:
        return const _Pill('Kabul', Color(0xFF065F46), Color(0xFFDCFCE7));
      case ApplicationStatus.rejected:
        return const _Pill('Reddedildi', Color(0xFF991B1B), Color(0xFFFEE2E2));
      case ApplicationStatus.active:
        return const _Pill('Aktif', Color(0xFF1D4ED8), Color(0xFFDBEAFE));
      case ApplicationStatus.completed:
        return const _Pill('Tamamlandı', Color(0xFF065F46), Color(0xFFDCFCE7));
    }
  }
}

class _Pill {
  const _Pill(this.text, this.fg, this.bg);
  final String text;
  final Color fg;
  final Color bg;
}

class _EmptyCta extends StatelessWidget {
  const _EmptyCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text, required this.count});
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ],
    );
  }
}
