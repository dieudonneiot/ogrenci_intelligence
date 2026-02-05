import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/oi_models.dart';

class OiScoreCard extends StatelessWidget {
  const OiScoreCard({super.key, required this.profile});
  final OiProfile profile;

  @override
  Widget build(BuildContext context) {
    final score = profile.oiScore.clamp(0, 100);
    final value = score / 100.0;
    final hist = profile.history;
    final delta = profile.deltaFromLastMonth;
    final spark = hist.isEmpty
        ? const <int>[]
        : hist
              .map((e) => e.oiScore.clamp(0, 100))
              .toList(growable: false)
              .reversed
              .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 9,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6D28D9)),
                ),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OI Score',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your score is computed from 4 dimensions (0–100).',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (spark.length >= 2) ...[
                  const SizedBox(height: 10),
                  SizedBox(height: 28, child: _Sparkline(values: spark)),
                ],
                if (hist.length >= 2) ...[
                  const SizedBox(height: 8),
                  _DeltaRow(delta: delta),
                ],
                const SizedBox(height: 8),
                Text(
                  'Updated: ${profile.updatedAt.toLocal()}',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class OiRadarCard extends StatelessWidget {
  const OiRadarCard({super.key, required this.profile});
  final OiProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Analysis',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _RadarPainter(
                technical: profile.technical,
                social: profile.social,
                fieldFit: profile.fieldFit,
                consistency: profile.consistency,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Tag(label: 'Technical', value: profile.technical),
              _Tag(label: 'Social', value: profile.social),
              _Tag(label: 'Field Fit', value: profile.fieldFit),
              _Tag(label: 'Consistency', value: profile.consistency),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    final v = delta;
    final isUp = v > 0;
    final isDown = v < 0;

    final Color fg;
    final IconData icon;

    if (isUp) {
      fg = const Color(0xFF16A34A);
      icon = Icons.trending_up;
    } else if (isDown) {
      fg = const Color(0xFFDC2626);
      icon = Icons.trending_down;
    } else {
      fg = const Color(0xFF6B7280);
      icon = Icons.trending_flat;
    }

    final label = '${v >= 0 ? '+' : ''}$v compared to last month';

    return Row(
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, color: fg),
        ),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});
  final List<int> values; // chronological, 0..100

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final dx = size.width / (values.length - 1);
    double yFor(num v) =>
        size.height - (((v.toDouble() - minV) / range) * size.height);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = yFor(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6D28D9);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6D28D9).withValues(alpha: 0.12);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.technical,
    required this.social,
    required this.fieldFit,
    required this.consistency,
  });

  final int technical;
  final int social;
  final int fieldFit;
  final int consistency;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.38;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFE5E7EB);

    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFD1D5DB);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF6D28D9).withValues(alpha: 0.20);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF6D28D9);

    // 4 axes: top, right, bottom, left
    final angles = <double>[-pi / 2, 0, pi / 2, pi];

    // grid rings
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      final r = radius * t;
      final path = Path();
      for (int i = 0; i < angles.length; i++) {
        final a = angles[i];
        final p = center + Offset(cos(a) * r, sin(a) * r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // axes
    for (final a in angles) {
      canvas.drawLine(
        center,
        center + Offset(cos(a) * radius, sin(a) * radius),
        axisPaint,
      );
    }

    double n(int v) => (v.clamp(0, 100)) / 100.0;

    final values = <double>[
      n(technical),
      n(social),
      n(fieldFit),
      n(consistency),
    ];

    final poly = Path();
    for (int i = 0; i < angles.length; i++) {
      final a = angles[i];
      final r = radius * values[i];
      final p = center + Offset(cos(a) * r, sin(a) * r);
      if (i == 0) {
        poly.moveTo(p.dx, p.dy);
      } else {
        poly.lineTo(p.dx, p.dy);
      }
    }
    poly.close();
    canvas.drawPath(poly, fillPaint);
    canvas.drawPath(poly, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return technical != oldDelegate.technical ||
        social != oldDelegate.social ||
        fieldFit != oldDelegate.fieldFit ||
        consistency != oldDelegate.consistency;
  }
}
