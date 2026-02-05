import 'package:flutter/foundation.dart';

@immutable
class OiProfile {
  const OiProfile({
    required this.userId,
    required this.oiScore,
    required this.technical,
    required this.social,
    required this.fieldFit,
    required this.consistency,
    required this.updatedAt,
    this.deltaFromLastMonth = 0,
    this.history = const <OiHistoryPoint>[],
  });

  final String userId;
  final int oiScore; // 0..100
  final int technical; // 0..100
  final int social; // 0..100
  final int fieldFit; // 0..100
  final int consistency; // 0..100
  final DateTime updatedAt;
  final int deltaFromLastMonth;
  final List<OiHistoryPoint> history;

  static OiProfile defaultFor(String userId) {
    final now = DateTime.now().toUtc();
    return OiProfile(
      userId: userId,
      oiScore: 50,
      technical: 50,
      social: 50,
      fieldFit: 50,
      consistency: 50,
      updatedAt: now,
      deltaFromLastMonth: 0,
      history: const <OiHistoryPoint>[],
    );
  }

  static int _asInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static DateTime _asDate(dynamic v) {
    final s = v?.toString();
    final dt = s == null ? null : DateTime.tryParse(s);
    return dt?.toUtc() ?? DateTime.now().toUtc();
  }

  factory OiProfile.fromMap(Map<String, dynamic> map) {
    final uid = (map['user_id'] ?? '').toString();
    final technical = _asInt(map['technical'], fallback: 50).clamp(0, 100);
    final social = _asInt(map['social'], fallback: 50).clamp(0, 100);
    final fieldFit = _asInt(map['field_fit'], fallback: 50).clamp(0, 100);
    final consistency = _asInt(map['consistency'], fallback: 50).clamp(0, 100);
    final score = _asInt(
      map['oi_score'],
      fallback: ((technical + social + fieldFit + consistency) / 4).round(),
    ).clamp(0, 100);
    return OiProfile(
      userId: uid,
      oiScore: score,
      technical: technical,
      social: social,
      fieldFit: fieldFit,
      consistency: consistency,
      updatedAt: _asDate(map['updated_at']),
      deltaFromLastMonth: 0,
      history: const <OiHistoryPoint>[],
    );
  }
}

@immutable
class OiHistoryPoint {
  const OiHistoryPoint({required this.month, required this.oiScore});

  final DateTime month; // month start (UTC)
  final int oiScore;

  static DateTime _asDate(dynamic v) {
    final s = v?.toString();
    final dt = s == null ? null : DateTime.tryParse(s);
    return dt?.toUtc() ?? DateTime.now().toUtc();
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  factory OiHistoryPoint.fromMap(Map<String, dynamic> map) {
    return OiHistoryPoint(
      month: _asDate(map['month']),
      oiScore: _asInt(map['oi_score']).clamp(0, 100),
    );
  }
}
