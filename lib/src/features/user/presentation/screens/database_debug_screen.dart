import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class DatabaseDebugScreen extends ConsumerStatefulWidget {
  const DatabaseDebugScreen({super.key});

  @override
  ConsumerState<DatabaseDebugScreen> createState() =>
      _DatabaseDebugScreenState();
}

class _DatabaseDebugScreenState extends ConsumerState<DatabaseDebugScreen> {
  bool _loading = true;
  Map<String, _TableResult> _tables = {};
  Map<String, dynamic>? _profile;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(authViewStateProvider).value?.user;
    final uid = user?.id;
    if (uid != null && uid != _lastUserId) {
      _lastUserId = uid;
      _checkDatabase();
    }
  }

  Future<void> _checkDatabase() async {
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    final user = ref.read(authViewStateProvider).value?.user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final results = <String, _TableResult>{};
    final client = SupabaseService.client;

    try {
      final profile = await client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        _profile = Map<String, dynamic>.from(profile);
        final dept = (_profile?['department'] ?? '').toString();
        results['profiles'] = _TableResult.success(
          count: 1,
          message: l10n.dbDebugProfileFound(
            dept.isEmpty ? l10n.t(AppText.commonNotSpecified) : dept,
          ),
          sample: [Map<String, dynamic>.from(profile)],
          columns: _columnsFromRows([profile]),
        );
      } else {
        results['profiles'] = _TableResult.error(
          l10n.t(AppText.dbDebugProfileNotFound),
        );
      }
    } catch (e) {
      results['profiles'] = _TableResult.error(e.toString());
    }

    final department = (_profile?['department'] ?? '').toString();

    results['courses'] = await _checkTable(
      table: 'courses',
      department: department,
      client: client,
    );

    results['internships'] = await _checkTable(
      table: 'internships',
      department: department,
      client: client,
    );

    results['jobs'] = await _checkTable(
      table: 'jobs',
      department: department,
      client: client,
      includePartTime: true,
    );

    if (!mounted) return;
    setState(() {
      _tables = results;
      _loading = false;
    });
  }

  Future<_TableResult> _checkTable({
    required String table,
    required String department,
    required SupabaseClient client,
    bool includePartTime = false,
  }) async {
    try {
      final rows = await client.from(table).select('*').limit(200);
      final list = (rows as List).cast<dynamic>();
      final sample = list
          .take(3)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final columns = _columnsFromRows(list);

      int? deptCount;
      if (department.isNotEmpty) {
        final deptRows = await client
            .from(table)
            .select('*')
            .eq('department', department);
        deptCount = (deptRows as List).length;
      }

      int? partTimeCount;
      if (includePartTime) {
        final ptRows = await client
            .from(table)
            .select('*')
            .eq('type', 'part-time');
        partTimeCount = (ptRows as List).length;
      }

      return _TableResult.success(
        count: list.length,
        columns: columns,
        sample: sample,
        departmentCount: deptCount,
        partTimeCount: partTimeCount,
      );
    } catch (e) {
      return _TableResult.error(e.toString());
    }
  }

  List<String> _columnsFromRows(List<dynamic> rows) {
    if (rows.isEmpty) return const [];
    final map = rows.first as Map;
    return map.keys.map((e) => e.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authViewStateProvider);
    final user = auth.value?.user;

    if (auth.isLoading || _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (user == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.t(AppText.commonPleaseSignIn),
            style: const TextStyle(color: Color(0xFF991B1B)),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storage_outlined,
                      color: Color(0xFF6D28D9),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.t(AppText.dbDebugTitle),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t(AppText.dbDebugSubtitle),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                _UserCard(user: user, profile: _profile),
                const SizedBox(height: 16),
                for (final entry in _tables.entries) ...[
                  _TableCard(name: entry.key, result: entry.value),
                  const SizedBox(height: 14),
                ],
                _TipsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.profile});

  final User user;
  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_outlined, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                l10n.t(AppText.dbDebugUserInfoTitle),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _InfoLine(label: l10n.t(AppText.commonUserId), value: user.id),
              _InfoLine(
                label: l10n.t(AppText.commonEmail),
                value: user.email ?? '-',
              ),
              _InfoLine(
                label: l10n.t(AppText.commonDepartment),
                value:
                    profile?['department']?.toString() ??
                    l10n.t(AppText.commonNotSpecified),
              ),
              _InfoLine(
                label: l10n.t(AppText.commonYear),
                value:
                    profile?['year']?.toString() ??
                    l10n.t(AppText.commonNotSpecified),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TableResult {
  const _TableResult({
    required this.success,
    this.count = 0,
    this.columns = const [],
    this.sample = const [],
    this.departmentCount,
    this.partTimeCount,
    this.message,
    this.error,
  });

  final bool success;
  final int count;
  final List<String> columns;
  final List<Map<String, dynamic>> sample;
  final int? departmentCount;
  final int? partTimeCount;
  final String? message;
  final String? error;

  factory _TableResult.success({
    required int count,
    List<String> columns = const [],
    List<Map<String, dynamic>> sample = const [],
    int? departmentCount,
    int? partTimeCount,
    String? message,
  }) {
    return _TableResult(
      success: true,
      count: count,
      columns: columns,
      sample: sample,
      departmentCount: departmentCount,
      partTimeCount: partTimeCount,
      message: message,
    );
  }

  factory _TableResult.error(String error) {
    return _TableResult(success: false, error: error);
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.name, required this.result});

  final String name;
  final _TableResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_outlined, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                l10n.dbDebugTableTitle(name),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Icon(
                result.success ? Icons.check_circle : Icons.error_outline,
                color: result.success
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (result.success) ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _Tag(
                  label: l10n.dbDebugTotalRecords(result.count),
                  bg: const Color(0xFFF3F4F6),
                ),
                if (result.departmentCount != null)
                  _Tag(
                    label: l10n.dbDebugDepartmentRecords(
                      result.departmentCount!,
                    ),
                    bg: const Color(0xFFEDE9FE),
                  ),
                if (result.partTimeCount != null)
                  _Tag(
                    label: l10n.dbDebugPartTimeRecords(result.partTimeCount!),
                    bg: const Color(0xFFDBEAFE),
                  ),
              ],
            ),
            if (result.columns.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.t(AppText.dbDebugTableColumnsTitle),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.columns
                    .map((c) => _Tag(label: c, bg: const Color(0xFFF3F4F6)))
                    .toList(),
              ),
            ],
            if (result.sample.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.t(AppText.dbDebugSampleRecordsTitle),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(result.sample),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
            if (result.message != null) ...[
              const SizedBox(height: 8),
              Text(
                result.message!,
                style: const TextStyle(color: Color(0xFF16A34A)),
              ),
            ],
          ] else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.dbDebugError(
                  result.error ?? l10n.t(AppText.commonUnknownError),
                ),
                style: const TextStyle(color: Color(0xFF991B1B)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.bg});

  final String label;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Text(
                l10n.t(AppText.dbDebugTipsTitle),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Tip(l10n.t(AppText.dbDebugTipProfileDepartment)),
          _Tip(l10n.t(AppText.dbDebugTipTablesHaveDepartment)),
          _Tip(l10n.t(AppText.dbDebugTipTablesHaveData)),
          _Tip(l10n.t(AppText.dbDebugTipRlsEnabled)),
          _Tip(l10n.t(AppText.dbDebugTipDepartmentHasMatches)),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('• $text', style: const TextStyle(color: Color(0xFF92400E))),
    );
  }
}
