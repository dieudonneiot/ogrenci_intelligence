import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/talent_mining_repository.dart';
import '../../domain/talent_models.dart';

class CompanyTalentMiningScreen extends ConsumerStatefulWidget {
  const CompanyTalentMiningScreen({super.key});

  @override
  ConsumerState<CompanyTalentMiningScreen> createState() =>
      _CompanyTalentMiningScreenState();
}

class _CompanyTalentMiningScreenState
    extends ConsumerState<CompanyTalentMiningScreen> {
  bool _loading = true;
  List<TalentCandidate> _items = const [];

  String? _department; // null = all
  RangeValues _oiRange = const RangeValues(80, 100);
  final Set<String> _badgeFilters = <String>{};

  List<String> _availableDepartments = const [];
  List<String> _availableBadges = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    final companyId = auth?.companyId;
    if (auth == null || companyId == null || companyId.isEmpty) return;

    setState(() => _loading = true);
    try {
      final repo = const TalentMiningRepository();
      final list = await repo.listTalentPool(
        companyId: companyId,
        department: _department,
        minScore: _oiRange.start.round(),
        maxScore: _oiRange.end.round(),
        badges: _badgeFilters.isEmpty
            ? null
            : _badgeFilters.toList(growable: false),
        limit: 60,
      );

      final departments =
          list
              .map((e) => (e.department ?? '').trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList(growable: false)
            ..sort();

      final badges = <String>{};
      for (final c in list) {
        badges.addAll(c.badges);
      }
      final badgeList = badges.toList(growable: false)..sort();

      if (!mounted) return;
      setState(() {
        _items = list;
        _availableDepartments = departments;
        _availableBadges = badgeList;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    setState(() {
      _department = null;
      _oiRange = const RangeValues(80, 100);
      _badgeFilters.clear();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authViewStateProvider).value;

    if (auth == null || auth.userType != UserType.company) {
      return const Center(child: Text('Company login required.'));
    }

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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
            child: LayoutBuilder(
              builder: (_, c) {
                final isWide = c.maxWidth >= 980;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Talent Mining',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clear,
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            l10n.t(AppText.retry),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isWide) ...[
                      _FiltersCard(
                        departments: _availableDepartments,
                        badges: _availableBadges,
                        selectedDepartment: _department,
                        oiRange: _oiRange,
                        selectedBadges: _badgeFilters,
                        onDepartmentChanged: (v) =>
                            setState(() => _department = v),
                        onOiRangeChanged: (v) => setState(() => _oiRange = v),
                        onToggleBadge: (b) => setState(() {
                          if (_badgeFilters.contains(b)) {
                            _badgeFilters.remove(b);
                          } else {
                            _badgeFilters.add(b);
                          }
                        }),
                        onApply: _load,
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _Results(items: _items)),
                    ] else
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 360,
                              child: _FiltersCard(
                                departments: _availableDepartments,
                                badges: _availableBadges,
                                selectedDepartment: _department,
                                oiRange: _oiRange,
                                selectedBadges: _badgeFilters,
                                onDepartmentChanged: (v) =>
                                    setState(() => _department = v),
                                onOiRangeChanged: (v) =>
                                    setState(() => _oiRange = v),
                                onToggleBadge: (b) => setState(() {
                                  if (_badgeFilters.contains(b)) {
                                    _badgeFilters.remove(b);
                                  } else {
                                    _badgeFilters.add(b);
                                  }
                                }),
                                onApply: _load,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: _Results(items: _items)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.departments,
    required this.badges,
    required this.selectedDepartment,
    required this.oiRange,
    required this.selectedBadges,
    required this.onDepartmentChanged,
    required this.onOiRangeChanged,
    required this.onToggleBadge,
    required this.onApply,
  });

  final List<String> departments;
  final List<String> badges;
  final String? selectedDepartment;
  final RangeValues oiRange;
  final Set<String> selectedBadges;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<RangeValues> onOiRangeChanged;
  final ValueChanged<String> onToggleBadge;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          const Text(
            'Smart Filters',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey<String?>('dept:$selectedDepartment'),
            initialValue: selectedDepartment,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Department',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All departments'),
              ),
              ...departments.map(
                (d) => DropdownMenuItem(
                  value: d,
                  child: Text(
                    d,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
            onChanged: onDepartmentChanged,
          ),
          const SizedBox(height: 14),
          const Text(
            'OI score range',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          RangeSlider(
            values: oiRange,
            min: 0,
            max: 100,
            divisions: 20,
            labels: RangeLabels(
              '${oiRange.start.round()}',
              '${oiRange.end.round()}',
            ),
            onChanged: onOiRangeChanged,
          ),
          const SizedBox(height: 10),
          if (badges.isNotEmpty) ...[
            const Text(
              'Badges / types',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in badges.take(18))
                  FilterChip(
                    label: Text(b),
                    selected: selectedBadges.contains(b),
                    onSelected: (_) => onToggleBadge(b),
                    selectedColor: const Color(0xFFEDE9FE),
                    checkmarkColor: const Color(0xFF14B8A6),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text(
                'Apply',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.items});
  final List<TalentCandidate> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No results.',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CandidateCard(item: items[i]),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.item});
  final TalentCandidate item;

  static const _dash = '—';

  String _pct(int num, int den) {
    if (den <= 0) return _dash;
    final v = (num / den * 100).clamp(0, 100);
    return '${v.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final score = item.oiScore.clamp(0, 100);
    final Color bg = score >= 80
        ? const Color(0xFFDCFCE7)
        : score >= 60
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFF3F4F6);
    final Color fg = score >= 80
        ? const Color(0xFF16A34A)
        : score >= 60
        ? const Color(0xFFB45309)
        : const Color(0xFF374151);

    final name = item.fullName.trim().isEmpty
        ? item.email
        : item.fullName.trim();

    final focusTotal = item.focusSubmitted + item.focusExpired;
    final focusRateText = _pct(item.focusSubmitted, focusTotal);

    final quizAccuracyText = _pct(item.nanoQuizCorrect, item.nanoQuizAttempts);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              _Avatar(url: item.avatarUrl, fallback: name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.department ?? _dash} • Year ${item.year ?? _dash}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Points',
                value: item.metricsAvailable ? '${item.totalPoints}' : _dash,
                color: const Color(0xFF2563EB),
                bg: const Color(0xFFDBEAFE),
              ),
              _MetricPill(
                label: 'Focus',
                value: item.metricsAvailable && focusTotal > 0
                    ? '$focusRateText • ${item.focusAvgSecondsToAnswer}s'
                    : _dash,
                color: const Color(0xFF16A34A),
                bg: const Color(0xFFDCFCE7),
              ),
              _MetricPill(
                label: 'Nano',
                value: item.metricsAvailable && item.nanoQuizAttempts > 0
                    ? '$quizAccuracyText • +${item.nanoQuizPoints}'
                    : (item.metricsAvailable && item.nanoCoursesCompleted > 0
                          ? '${item.nanoCoursesCompleted} done'
                          : _dash),
                color: const Color(0xFF14B8A6),
                bg: const Color(0xFFEDE9FE),
              ),
              _MetricPill(
                label: 'Cases',
                value: item.metricsAvailable && item.casesSolved > 0
                    ? '${item.casesSolved}'
                    : _dash,
                color: const Color(0xFFB45309),
                bg: const Color(0xFFFFEDD5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (item.badges.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in item.badges.take(10))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: item.email.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: item.email),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email copied.')),
                          );
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text(
                    'Copy email',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showDetails(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View profile',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    final focusTotal = item.focusSubmitted + item.focusExpired;
    final focusRate = focusTotal == 0 ? null : item.focusSubmitted / focusTotal;
    final quizAccuracy = item.nanoQuizAttempts == 0
        ? null
        : item.nanoQuizCorrect / item.nanoQuizAttempts;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item.fullName.trim().isEmpty
              ? 'Student profile'
              : item.fullName.trim(),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${item.email.isEmpty ? _dash : item.email}'),
                const SizedBox(height: 6),
                Text('Department: ${item.department ?? _dash}'),
                const SizedBox(height: 6),
                Text('Year: ${item.year ?? _dash}'),
                const SizedBox(height: 6),
                Text('OI Score: ${item.oiScore}'),
                if (!item.metricsAvailable) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Extended performance metrics are not available in this environment.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Apply the updated SQL in docs/sql/24_talent_mining.sql to enable focus speed, nano-learning knowledge, and case reaction signals.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  _DimensionBars(item: item),
                  const SizedBox(height: 14),
                  _DetailsRow(
                    label: 'Total points',
                    value: '${item.totalPoints}',
                  ),
                  const SizedBox(height: 8),
                  _DetailsRow(
                    label: 'Case analysis (reactions)',
                    value: item.casesSolved == 0
                        ? _dash
                        : '${item.casesSolved} total • L ${item.casesLeft} / R ${item.casesRight}',
                  ),
                  const SizedBox(height: 8),
                  _DetailsRow(
                    label: 'Instant focus (speed)',
                    value: focusTotal == 0
                        ? _dash
                        : '${(focusRate! * 100).toStringAsFixed(0)}% on-time • avg ${item.focusAvgSecondsToAnswer}s • ${item.focusSubmitted}/$focusTotal',
                  ),
                  const SizedBox(height: 8),
                  _DetailsRow(
                    label: 'Nano-learning (knowledge)',
                    value:
                        (item.nanoCoursesCompleted == 0 &&
                            item.nanoQuizAttempts == 0)
                        ? _dash
                        : '${item.nanoCoursesCompleted} completed • quiz ${quizAccuracy == null ? _dash : '${(quizAccuracy * 100).toStringAsFixed(0)}%'} • +${item.nanoQuizPoints} pts',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  final String label;
  final String value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _DimensionBars extends StatelessWidget {
  const _DimensionBars({required this.item});
  final TalentCandidate item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Strength profile (OI dimensions)',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _Bar(label: 'Technical', value: item.technical, color: Colors.blue),
        const SizedBox(height: 8),
        _Bar(label: 'Social', value: item.social, color: Colors.green),
        const SizedBox(height: 8),
        _Bar(label: 'Field fit', value: item.fieldFit, color: Colors.orange),
        const SizedBox(height: 8),
        _Bar(
          label: 'Consistency',
          value: item.consistency,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value.clamp(0, 100)) / 100.0,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});
  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final initial = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().characters.first.toUpperCase();
    if (url == null || url!.trim().isEmpty) {
      return _initial(initial);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _initial(initial),
      ),
    );
  }

  Widget _initial(String t) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        t,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF14B8A6),
        ),
      ),
    );
  }
}
