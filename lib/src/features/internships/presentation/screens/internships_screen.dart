import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../application/internships_providers.dart';
import '../../domain/internship_models.dart';

class InternshipsScreen extends ConsumerStatefulWidget {
  const InternshipsScreen({super.key});

  @override
  ConsumerState<InternshipsScreen> createState() => _InternshipsScreenState();
}

class _InternshipsScreenState extends ConsumerState<InternshipsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      ref.read(internshipsSearchProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncVm = ref.watch(internshipsProvider);
    final selectedLoc = ref.watch(internshipsLocationProvider);
    final selectedDur = ref.watch(internshipsDurationProvider);

    final locations = <Map<String, String>>[
      {'value': 'all', 'label': l10n.t(AppText.internshipsLocationAll)},
      {'value': 'İstanbul', 'label': 'İstanbul'},
      {'value': 'Ankara', 'label': 'Ankara'},
      {'value': 'İzmir', 'label': 'İzmir'},
      {'value': 'Bursa', 'label': 'Bursa'},
      {'value': 'remote', 'label': l10n.t(AppText.remote)},
    ];

    final durations = <Map<String, String>>[
      {'value': 'all', 'label': l10n.t(AppText.internshipsDurationAll)},
      {'value': '1-3', 'label': l10n.t(AppText.internshipsDuration1_3)},
      {'value': '3-6', 'label': l10n.t(AppText.internshipsDuration3_6)},
      {'value': '6-12', 'label': l10n.t(AppText.internshipsDuration6_12)},
      {'value': '6+', 'label': l10n.t(AppText.internshipsDuration6Plus)},
      {'value': '12+', 'label': l10n.t(AppText.internshipsDuration12Plus)},
    ];

    return asyncVm.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t(AppText.internshipsLoadFailed),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.read(internshipsProvider.notifier).refresh(),
                  child: Text(l10n.t(AppText.retry)),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (vm) {
        return Container(
          color: const Color(0xFFF9FAFB),
          child: RefreshIndicator(
            onRefresh: () => ref.read(internshipsProvider.notifier).refresh(),
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
                        Text(
                          l10n.t(AppText.internshipsTitle),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.t(AppText.internshipsSubtitle),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (vm.departmentMissing) ...[
                          _Card(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF6D28D9),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.t(AppText.internshipsNoDepartmentInfo),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Filters
                        _Card(
                          child: Column(
                            children: [
                              TextField(
                                controller: _search,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  hintText: l10n.t(
                                    AppText.internshipsSearchHint,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              LayoutBuilder(
                                builder: (_, c) {
                                  final wide = c.maxWidth >= 760;
                                  final left = _Drop(
                                    value: selectedLoc,
                                    items: locations,
                                    onChanged: (v) =>
                                        ref
                                                .read(
                                                  internshipsLocationProvider
                                                      .notifier,
                                                )
                                                .state =
                                            v,
                                  );
                                  final right = _Drop(
                                    value: selectedDur,
                                    items: durations,
                                    onChanged: (v) =>
                                        ref
                                                .read(
                                                  internshipsDurationProvider
                                                      .notifier,
                                                )
                                                .state =
                                            v,
                                  );
                                  final clearBtn = SizedBox(
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _debounce?.cancel();
                                        _search.clear();
                                        ref
                                                .read(
                                                  internshipsSearchProvider
                                                      .notifier,
                                                )
                                                .state =
                                            '';
                                        ref
                                                .read(
                                                  internshipsLocationProvider
                                                      .notifier,
                                                )
                                                .state =
                                            'all';
                                        ref
                                                .read(
                                                  internshipsDurationProvider
                                                      .notifier,
                                                )
                                                .state =
                                            'all';
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: Text(
                                        l10n.t(AppText.resetFilters),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  );

                                  if (!wide) {
                                    return Column(
                                      children: [
                                        left,
                                        const SizedBox(height: 10),
                                        right,
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: clearBtn,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: left),
                                      const SizedBox(width: 10),
                                      Expanded(child: right),
                                      const SizedBox(width: 10),
                                      clearBtn,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Stats (match React)
                        LayoutBuilder(
                          builder: (_, c) {
                            final wide = c.maxWidth >= 980;

                            final cards = <Widget>[
                              _StatSmall(
                                title: l10n.t(
                                  AppText.internshipsActiveListings,
                                ),
                                value: '${vm.activeCount}',
                                icon: Icons.work_outline,
                                iconColor: const Color(0xFF7C3AED),
                                iconBg: const Color(0xFFEDE9FE),
                              ),
                              _StatSmall(
                                title: l10n.t(AppText.internshipsApplied),
                                value: '${vm.appliedCount}',
                                icon: Icons.track_changes_outlined,
                                iconColor: const Color(0xFF2563EB),
                                iconBg: const Color(0xFFDBEAFE),
                              ),
                              _StatSmall(
                                title: l10n.t(AppText.internshipsAvgDuration),
                                value: l10n.t(AppText.internshipsDuration3_6),
                                icon: Icons.schedule,
                                iconColor: const Color(0xFF6B7280),
                                iconBg: const Color(0xFFF3F4F6),
                              ),
                              _StatSmall(
                                title: l10n.t(AppText.internshipsPointsEarn),
                                value: '+100',
                                icon: Icons.emoji_events_outlined,
                                iconColor: const Color(0xFFF59E0B),
                                iconBg: const Color(0xFFFEF3C7),
                              ),
                            ];

                            if (wide) {
                              return Row(
                                children: [
                                  for (int i = 0; i < cards.length; i++) ...[
                                    Expanded(child: cards[i]),
                                    if (i != cards.length - 1)
                                      const SizedBox(width: 14),
                                  ],
                                ],
                              );
                            }

                            final half = (c.maxWidth - 14) / 2;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: cards
                                  .map((w) => SizedBox(width: half, child: w))
                                  .toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        if (!vm.departmentMissing && vm.items.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.t(AppText.internshipsNoResults),
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (_, c) {
                              final isGrid = c.maxWidth >= 900;
                              if (!isGrid) {
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: vm.items.length,
                                  itemBuilder: (_, i) => _InternshipCard(
                                    item: vm.items[i],
                                    onOpen: () => context.push(
                                      '/internships/${vm.items[i].internship.id}',
                                    ),
                                    onFav: () => ref
                                        .read(internshipsProvider.notifier)
                                        .toggleFavorite(
                                          vm.items[i].internship.id,
                                        ),
                                  ),
                                );
                              }

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: 1.55,
                                    ),
                                itemCount: vm.items.length,
                                itemBuilder: (_, i) => _InternshipCard(
                                  item: vm.items[i],
                                  onOpen: () => context.push(
                                    '/internships/${vm.items[i].internship.id}',
                                  ),
                                  onFav: () => ref
                                      .read(internshipsProvider.notifier)
                                      .toggleFavorite(
                                        vm.items[i].internship.id,
                                      ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 14),

                        _InfoCard(
                          onPointsSystem: () => context.go(Routes.pointsSystem),
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
}

/* ---------------- UI components ---------------- */

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: child,
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<Map<String, String>> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      items: items
          .map(
            (m) =>
                DropdownMenuItem(value: m['value']!, child: Text(m['label']!)),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _StatSmall extends StatelessWidget {
  const _StatSmall({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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

class _InternshipCard extends StatelessWidget {
  const _InternshipCard({
    required this.item,
    required this.onOpen,
    required this.onFav,
  });

  final InternshipCardItem item;
  final VoidCallback onOpen;
  final VoidCallback onFav;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final i = item.internship;
    final status = item.myApplication?.status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        i.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CompatibilityPill(value: i.compatibility),
                    if (status != null) ...[
                      const SizedBox(width: 8),
                      _StatusPill(status: status),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onFav,
                icon: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                color: item.isFavorite
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF9CA3AF),
                tooltip: l10n.t(AppText.internshipsFavorite),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.apartment, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  i.companyName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Meta(
                icon: Icons.location_on_outlined,
                text: i.location ?? l10n.t(AppText.internshipsNotSpecified),
              ),
              _Meta(
                icon: Icons.schedule,
                text: l10n.internshipsMonths(i.durationMonths),
              ),
              if (i.isRemote)
                _Meta(icon: Icons.wifi, text: l10n.t(AppText.remote)),
              if (i.deadline != null)
                _Meta(icon: Icons.event_outlined, text: _fmtDate(i.deadline!)),
              if (i.isPaid)
                _Meta(
                  icon: Icons.payments_outlined,
                  text: i.monthlyStipend != null
                      ? l10n.internshipsMonthlyStipend(
                          i.monthlyStipend!.toStringAsFixed(0),
                        )
                      : l10n.t(AppText.internshipsPaid),
                  fg: const Color(0xFF16A34A),
                  bg: const Color(0xFFDCFCE7),
                ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.t(AppText.internshipsDetails),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.bg = const Color(0xFFF3F4F6),
    this.fg = const Color(0xFF374151),
  });
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityPill extends StatelessWidget {
  const _CompatibilityPill({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    Color bg;
    Color fg;

    if (v >= 80) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (v >= 60) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$v%',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final InternshipApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label;
    Color bg;
    Color fg;

    switch (status) {
      case InternshipApplicationStatus.pending:
        label = l10n.t(AppText.statusPending);
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case InternshipApplicationStatus.accepted:
        label = l10n.t(AppText.statusAccepted);
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case InternshipApplicationStatus.rejected:
        label = l10n.t(AppText.statusRejected);
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.onPointsSystem});
  final VoidCallback onPointsSystem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates,
            color: Color(0xFF6D28D9),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(AppText.internshipsPointsTitle),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t(AppText.internshipsPointsDesc),
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onPointsSystem,
                    icon: const Icon(Icons.track_changes_outlined),
                    label: Text(l10n.t(AppText.internshipsPointsButton)),
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
