import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../application/leaderboard_providers.dart';
import '../../domain/leaderboard_models.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this); // overall + department
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncVm = ref.watch(leaderboardProvider);

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
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text('Leaderboard yüklenemedi',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
                  child: const Text('Tekrar dene'),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (vm) {
        final dept = (vm.department ?? '').trim();
        final hasDept = dept.isNotEmpty;

        return Container(
          color: const Color(0xFFF9FAFB),
          child: RefreshIndicator(
            onRefresh: () => ref.read(leaderboardProvider.notifier).refresh(),
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
                            Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 30),
                            SizedBox(width: 10),
                            Text('Liderlik Tablosu',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'En aktif öğrenciler arasında yerini al. Puan kazan, yüksel, ödüllere yaklaş.',
                          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),

                        // Always show hero (React-style), even if points are 0
                        _UserStatsHero(vm: vm),

                        const SizedBox(height: 14),

                        // Tabs
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: TabBar(
                            controller: _tabs,
                            labelColor: const Color(0xFF111827),
                            unselectedLabelColor: const Color(0xFF6B7280),
                            labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                            indicatorColor: const Color(0xFF6D28D9),
                            tabs: const [
                              Tab(text: 'Genel'),
                              Tab(text: 'Bölüm'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          height: 720,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _LeaderboardList(
                                meId: vm.meId,
                                showDepartment: true,
                                entries: vm.overall,
                                emptyText: 'Henüz sıralama verisi yok.',
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasDept) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                                      child: Text(
                                        'Bölüm: $dept',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: _LeaderboardList(
                                      meId: vm.meId,
                                      showDepartment: false,
                                      entries: vm.departmentList,
                                      emptyText: !hasDept
                                          ? 'Profilinde bölüm bilgisi yok.'
                                          : 'Bu bölüm için sıralama verisi yok.',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

/* ---------------- UI ---------------- */

class _UserStatsHero extends StatelessWidget {
  const _UserStatsHero({required this.vm});
  final LeaderboardViewModel vm;

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
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= 860;

          final items = <Widget>[
            _HeroMetric(title: 'Toplam Puanın', value: '${vm.totalPoints}'),
            _HeroMetric(title: 'Genel Sıralama', value: vm.overallRank != null ? '${vm.overallRank}.' : '—'),
            _HeroMetric(title: 'Bölüm Sıralaması', value: vm.departmentRank != null ? '${vm.departmentRank}.' : '—'),
          ];

          if (wide) {
            return Row(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  Expanded(child: items[i]),
                  if (i != items.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((w) => SizedBox(width: (c.maxWidth - 10) / 2, child: w)).toList(),
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.meId,
    required this.entries,
    required this.showDepartment,
    required this.emptyText,
  });

  final String meId;
  final List<LeaderboardEntry> entries;
  final bool showDepartment;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyText,
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      padding: const EdgeInsets.only(bottom: 12),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = entries[i];
        final isMe = e.userId == meId;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFF3E8FF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 8))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RankBadge(rank: e.rank),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(letter: e.displayName.isNotEmpty ? e.displayName[0].toUpperCase() : '?'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  e.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Sen',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (showDepartment) ...[
                      const SizedBox(height: 8),
                      Text(
                        e.department?.isNotEmpty == true ? e.department! : 'Belirtilmemiş',
                        style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${e.totalPoints}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF6D28D9)),
                  ),
                  const SizedBox(height: 6),
                  _LevelPill(points: e.totalPoints, rank: e.rank),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final icon = _rankIcon(rank);
    final color = _rankColor(rank);

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: (rank <= 3) ? const Color(0xFF111827) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _rankIcon(int r) {
    if (r == 1) return Icons.workspace_premium;
    if (r == 2) return Icons.emoji_events;
    if (r == 3) return Icons.emoji_events_outlined;
    return Icons.star_border;
  }

  static Color _rankColor(int r) {
    if (r == 1) return const Color(0xFFF59E0B);
    if (r == 2) return const Color(0xFF9CA3AF);
    if (r == 3) return const Color(0xFFD97706);
    return const Color(0xFF6B7280);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      alignment: Alignment.center,
      child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6D28D9))),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.points, required this.rank});
  final int points;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final label = points >= 1000
        ? 'Uzman'
        : points >= 500
            ? 'İleri'
            : points >= 100
                ? 'Orta'
                : 'Başlangıç';

    final bg = rank <= 3 ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6);
    final fg = rank <= 3 ? const Color(0xFF92400E) : const Color(0xFF374151);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.onPointsSystem});
  final VoidCallback onPointsSystem;

  @override
  Widget build(BuildContext context) {
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
          const Icon(Icons.tips_and_updates, color: Color(0xFF6D28D9), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nasıl puan kazanırım?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  '• Kurs tamamla: +50 puan\n• Kursa kayıt ol: +10 puan\n• Günlük giriş: +2 puan\n• 7 gün seri: +15 puan',
                  style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onPointsSystem,
                    icon: const Icon(Icons.track_changes_outlined),
                    label: const Text('Puan Sistemini Gör'),
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
