import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/csv_export.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/domain/company_models.dart';

class CompanyReportsScreen extends ConsumerStatefulWidget {
  const CompanyReportsScreen({super.key});

  @override
  ConsumerState<CompanyReportsScreen> createState() => _CompanyReportsScreenState();
}

class _CompanyReportsScreenState extends ConsumerState<CompanyReportsScreen> {
  bool _loading = true;
  CompanyReportSummary _summary = CompanyReportSummary.empty();
  CompanyReportTrends _trends = CompanyReportTrends.empty();
  String _rangeKey = 'last30';

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _rangeStart() {
    final now = DateTime.now();
    switch (_rangeKey) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'last7':
        return now.subtract(const Duration(days: 7));
      case 'last90':
        return now.subtract(const Duration(days: 90));
      case 'all':
        return null;
      case 'last30':
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    final companyId = auth?.companyId;
    if (auth == null || auth.userType != UserType.company || companyId == null) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(companyRepositoryProvider);
      final summary = await repo.fetchReportSummary(
        companyId: companyId,
        startDate: _rangeStart(),
      );
      final trends = await repo.fetchReportTrends(
        companyId: companyId,
        days: 7,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _trends = trends;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('Sirket Raporu');
    buffer.writeln('Tarih Araligi,$_rangeKey');
    buffer.writeln('');
    buffer.writeln('GENEL METRIKLER');
    buffer.writeln('Toplam Görüntüleme,${_summary.totalViews}');
    buffer.writeln('Benzersiz Ziyaretçi,${_summary.uniqueVisitors}');
    buffer.writeln('Toplam Basvuru,${_summary.totalApplications}');
    buffer.writeln('Kabul Edilen,${_summary.acceptedApplications}');
    buffer.writeln('Reddedilen,${_summary.rejectedApplications}');
    buffer.writeln('Dönüsüm Orani,%${_summary.conversionRate.toStringAsFixed(1)}');
    buffer.writeln('Ortalama Yanit Süresi,${_summary.avgResponseTimeHours.toStringAsFixed(1)} saat');
    buffer.writeln('');
    buffer.writeln('GÖRÜNTÜLEME TRENDI (7 gün)');
    buffer.writeln('Tarih,Adet');
    for (final p in _trends.views) {
      buffer.writeln('${_fmtDate(p.date)},${p.count}');
    }
    buffer.writeln('');
    buffer.writeln('BASVURU TRENDI (7 gün)');
    buffer.writeln('Tarih,Adet');
    for (final p in _trends.applications) {
      buffer.writeln('${_fmtDate(p.date)},${p.count}');
    }
    buffer.writeln('');
    buffer.writeln('DEPARTMAN DAGILIMI');
    buffer.writeln('Departman,Adet');
    final sorted = _trends.departmentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      buffer.writeln('${_escape(e.key)},${e.value}');
    }

    final now = DateTime.now();
    final fileName =
        'rapor-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';
    await downloadCsv(buffer.toString(), fileName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV indirildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authViewStateProvider);
    if (authAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = authAsync.value;
    if (auth == null || !auth.isAuthenticated || auth.userType != UserType.company) {
      return const Center(child: Text('Sirket raporlarini görmek için giris yapmalisiniz.'));
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (_, c) {
                      final isNarrow = c.maxWidth < 640;
                      final titleRow = Row(
                        children: const [
                          Icon(Icons.bar_chart_outlined, color: Color(0xFF6D28D9)),
                          SizedBox(width: 8),
                          Text('Raporlar',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      );
                      final actions = Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<String>(
                            value: _rangeKey,
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _rangeKey = v);
                              _load();
                            },
                            items: const [
                              DropdownMenuItem(value: 'today', child: Text('Bugün')),
                              DropdownMenuItem(value: 'last7', child: Text('Son 7 Gün')),
                              DropdownMenuItem(value: 'last30', child: Text('Son 30 Gün')),
                              DropdownMenuItem(value: 'last90', child: Text('Son 90 Gün')),
                              DropdownMenuItem(value: 'all', child: Text('Tümü')),
                            ],
                          ),
                          IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                          ),
                          ElevatedButton.icon(
                            onPressed: _exportCsv,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('CSV Indir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow,
                            const SizedBox(height: 8),
                            actions,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          titleRow,
                          const Spacer(),
                          actions,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else ...[
                    LayoutBuilder(
                      builder: (_, c) {
                        final crossAxis = c.maxWidth >= 980
                            ? 4
                            : c.maxWidth >= 720
                                ? 2
                                : 1;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxis,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.25,
                          children: [
                            _MetricCard(
                              title: 'Toplam Görüntüleme',
                              value: _summary.totalViews.toString(),
                              icon: Icons.visibility_outlined,
                              color: const Color(0xFF3B82F6),
                            ),
                            _MetricCard(
                              title: 'Benzersiz Ziyaretçi',
                              value: _summary.uniqueVisitors.toString(),
                              icon: Icons.people_outline,
                              color: const Color(0xFF10B981),
                            ),
                            _MetricCard(
                              title: 'Toplam Basvuru',
                              value: _summary.totalApplications.toString(),
                              icon: Icons.assignment_turned_in_outlined,
                              color: const Color(0xFF7C3AED),
                            ),
                            _MetricCard(
                              title: 'Dönüsüm Orani',
                              value: '%${_summary.conversionRate.toStringAsFixed(1)}',
                              icon: Icons.trending_up,
                              color: const Color(0xFFF59E0B),
                            ),
                            _MetricCard(
                              title: 'Ortalama Yanit Süresi',
                              value: '${_summary.avgResponseTimeHours.toStringAsFixed(1)} saat',
                              icon: Icons.schedule,
                              color: const Color(0xFF6366F1),
                            ),
                            _MetricCard(
                              title: 'Kabul Edilen',
                              value: _summary.acceptedApplications.toString(),
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF16A34A),
                            ),
                            _MetricCard(
                              title: 'Reddedilen',
                              value: _summary.rejectedApplications.toString(),
                              icon: Icons.cancel_outlined,
                              color: const Color(0xFFDC2626),
                            ),
                            _MetricCard(
                              title: 'Aktif Ilan',
                              value:
                                  '${_summary.activeJobs} is • ${_summary.activeInternships} staj',
                              icon: Icons.work_outline,
                              color: const Color(0xFF111827),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Son 7 Gün Trendleri',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (_, c) {
                        final crossAxis = c.maxWidth >= 980 ? 2 : 1;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxis,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                          children: [
                            _TrendCard(
                              title: 'Görüntüleme Trendi',
                              points: _trends.views,
                              color: const Color(0xFF3B82F6),
                            ),
                            _TrendCard(
                              title: 'Basvuru Trendi',
                              points: _trends.applications,
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (_, c) {
                        final crossAxis = c.maxWidth >= 980 ? 2 : 1;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxis,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.45,
                          children: [
                            _DistributionCard(counts: _trends.departmentCounts),
                            _FunnelCard(funnel: _trends.funnel),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day.$month.${d.year}';
  }

  String _escape(String input) {
    final escaped = input.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.points,
    required this.color,
  });

  final String title;
  final List<CompanyTrendPoint> points;
  final Color color;

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
          Expanded(
            child: _LineChart(points: points, color: color),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points, required this.color});

  final List<CompanyTrendPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('Veri yok'));
    }

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _LineChartPainter(points: points, color: color),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final p in points)
              Expanded(
                child: Text(
                  '${p.date.day}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points, required this.color});

  final List<CompanyTrendPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points.map((e) => e.count.toDouble()).toList();
    final maxValue = values.fold<double>(0, (max, v) => math.max(max, v));
    final safeMax = maxValue == 0 ? 1 : maxValue;
    final dx = size.width / math.max(1, values.length - 1);

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 1; i <= 2; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height - (values[i] / safeMax) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (int i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height - (values[i] / safeMax) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final maxValue = top.isEmpty ? 1 : top.first.value;

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
          const Text('Departman Dagilimi', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (top.isEmpty)
            const Expanded(child: Center(child: Text('Veri yok')))
          else
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: top.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final entry = top[i];
                  final ratio = entry.value / maxValue;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(entry.value.toString(),
                              style: const TextStyle(color: Color(0xFF6B7280))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF6D28D9)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.funnel});

  final CompanyFunnel funnel;

  @override
  Widget build(BuildContext context) {
    final maxValue = funnel.views == 0 ? 1 : funnel.views;
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
          const Text('Dönüsüm Hunisi', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _FunnelRow(label: 'Görüntüleme', value: funnel.views, max: maxValue),
          const SizedBox(height: 10),
          _FunnelRow(label: 'Basvuru', value: funnel.applications, max: maxValue),
          const SizedBox(height: 10),
          _FunnelRow(label: 'Kabul', value: funnel.accepted, max: maxValue),
        ],
      ),
    );
  }
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow({
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : value / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(value.toString(), style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
          ),
        ),
      ],
    );
  }
}
