import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../application/points_providers.dart';
import '../../domain/points_models.dart';

class PointsSystemScreen extends ConsumerWidget {
  const PointsSystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authViewStateProvider);
    final isLoggedIn = (!authAsync.isLoading) && (authAsync.value?.isAuthenticated ?? false);

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: isLoggedIn ? const _AuthedPointsView() : const _GuestPointsView(),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestPointsView extends StatelessWidget {
  const _GuestPointsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Puan Sistemi', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Kurslara kayıt ol, ilerleme kaydet, rozet kazan ve ödülleri aç.',
          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Bullet('Kurs kaydı → puan kazan'),
              _Bullet('Kurs tamamla → ekstra puan + rozet'),
              _Bullet('Toplanan puanlarla ödüllerin kilidini aç'),
              SizedBox(height: 10),
              Text(
                'Giriş yaptıktan sonra puan geçmişini ve ödüllerini burada göreceksin.',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthedPointsView extends ConsumerWidget {
  const _AuthedPointsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPointsAsync = ref.watch(myTotalPointsProvider);
    final rewardsAsync = ref.watch(rewardsProvider);
    final historyAsync = ref.watch(myPointsHistoryProvider);
    final badgesAsync = ref.watch(myBadgesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Puan Sistemi', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Puanlarını takip et, ödülleri hedefle.',
          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),

        // Summary header
        _Card(
          child: totalPointsAsync.when(
            loading: () => const _MiniLoading(height: 84),
            error: (e, _) => _MiniError('Puanlar yüklenemedi: $e'),
            data: (total) {
              return rewardsAsync.when(
                loading: () => _Summary(totalPoints: total, next: null),
                error: (_, __) => _Summary(totalPoints: total, next: null),
                data: (rewards) {
                  final next = _findNextReward(total, rewards);
                  return _Summary(totalPoints: total, next: next);
                },
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFF111827),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                  indicatorColor: const Color(0xFF6D28D9),
                  tabs: const [
                    Tab(text: 'Geçmiş'),
                    Tab(text: 'Ödüller'),
                    Tab(text: 'Rozetler'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 720,
                child: TabBarView(
                  children: [
                    // History
                    historyAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      error: (e, _) => _MiniError('Geçmiş yüklenemedi: $e'),
                      data: (items) => items.isEmpty
                          ? const _Empty(text: 'Henüz puan hareketi yok.')
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (_, i) => _PointRow(p: items[i]),
                            ),
                    ),

                    // Rewards
                    rewardsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      error: (e, _) => _MiniError('Ödüller yüklenemedi: $e'),
                      data: (items) => items.isEmpty
                          ? const _Empty(text: 'Ödül bulunamadı.')
                          : totalPointsAsync.maybeWhen(
                              data: (total) => ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (_, i) => _RewardCard(reward: items[i], totalPoints: total),
                              ),
                              orElse: () => ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (_, i) => _RewardCard(reward: items[i], totalPoints: 0),
                              ),
                            ),
                    ),

                    // Badges
                    badgesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      error: (e, _) => _MiniError('Rozetler yüklenemedi: $e'),
                      data: (items) => items.isEmpty
                          ? const _Empty(text: 'Henüz rozet yok. Kurs tamamlayınca rozetler gelir 😉')
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (_, i) => _BadgeCard(b: items[i]),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Reward? _findNextReward(int total, List<Reward> rewards) {
    for (final r in rewards) {
      if (r.requiredPoints > total) return r;
    }
    return null;
  }
}

/* ---------------------------- UI bits ---------------------------- */

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
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.totalPoints, required this.next});
  final int totalPoints;
  final Reward? next;

  @override
  Widget build(BuildContext context) {
    final nextPoints = next?.requiredPoints;
    final progress = (nextPoints == null || nextPoints <= 0)
        ? 1.0
        : (totalPoints / nextPoints).clamp(0.0, 1.0);

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.track_changes_outlined, color: Color(0xFF6D28D9)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Toplam Puan', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('$totalPoints', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (next != null) ...[
                Text(
                  'Sonraki ödül: ${next!.title} (${next!.requiredPoints} puan)',
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                  ),
                ),
              ] else ...[
                const Text(
                  'Tüm ödüller açılmış olabilir 🎉',
                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.p});
  final UserPoint p;

  @override
  Widget build(BuildContext context) {
    final isPositive = p.points >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPositive ? Icons.add : Icons.remove,
              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.description, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  '${p.source} • ${_fmt(p.createdAt)}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            (isPositive ? '+' : '') + p.points.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.totalPoints});

  final Reward reward;
  final int totalPoints;

  @override
  Widget build(BuildContext context) {
    final unlocked = totalPoints >= reward.requiredPoints;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              unlocked ? Icons.lock_open_outlined : Icons.lock_outline,
              color: unlocked ? const Color(0xFF16A34A) : const Color(0xFF6D28D9),
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
                      child: Text(reward.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: unlocked ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unlocked ? 'Açıldı' : 'Kilitli',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: unlocked ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  reward.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${reward.requiredPoints} puan',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.b});
  final UserBadge b;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events_outlined, color: Color(0xFFF97316)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.badgeTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  (b.badgeDescription ?? b.badgeType),
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '+${b.pointsAwarded} • ${b.earnedAt.day.toString().padLeft(2, '0')}.${b.earnedAt.month.toString().padLeft(2, '0')}.${b.earnedAt.year}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLoading extends StatelessWidget {
  const _MiniLoading({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}

class _MiniError extends StatelessWidget {
  const _MiniError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
