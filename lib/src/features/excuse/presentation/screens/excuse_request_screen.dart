import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/excuse_repository.dart';
import '../../domain/excuse_models.dart';

class ExcuseRequestScreen extends ConsumerStatefulWidget {
  const ExcuseRequestScreen({super.key});

  @override
  ConsumerState<ExcuseRequestScreen> createState() =>
      _ExcuseRequestScreenState();
}

class _ExcuseRequestScreenState extends ConsumerState<ExcuseRequestScreen> {
  final _detailsCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;

  List<AcceptedInternshipOption> _accepted = const [];
  List<MyExcuseRequest> _requests = const [];

  String? _selectedApplicationId;
  String _reason = 'illness';

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final auth = ref.read(authViewStateProvider).value;
    final user = auth?.user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final repo = const ExcuseRepository();
      final accepted = await repo.listMyAcceptedInternships(userId: user.id);
      final requests = await repo.listMyRequests(userId: user.id);

      if (!mounted) return;
      setState(() {
        _accepted = accepted;
        _requests = requests;
        _selectedApplicationId =
            (_selectedApplicationId != null &&
                accepted.any((e) => e.applicationId == _selectedApplicationId))
            ? _selectedApplicationId
            : (accepted.isNotEmpty ? accepted.first.applicationId : null);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final auth = ref.read(authViewStateProvider).value;
    final user = auth?.user;
    if (user == null) return;

    final appId = _selectedApplicationId;
    if (appId == null || appId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an internship.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = const ExcuseRepository();
      await repo.createExcuseRequest(
        internshipApplicationId: appId,
        reasonType: _reason,
        details: _detailsCtrl.text.trim(),
      );

      if (!mounted) return;
      _detailsCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request submitted.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authViewStateProvider).value;
    final user = auth?.user;

    if (user == null) {
      return const Center(child: Text('Login required.'));
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
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(Routes.settings),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Report Excuse / Freeze Term',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.t(AppText.retry),
                        onPressed: _submitting ? null : _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: const Text(
                      'If you have a serious reason (illness, family emergency, etc.), you can request a term freeze. '
                      'Your company will review and approve/reject it.',
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_accepted.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'No accepted internship found. Excuse requests require an accepted internship.',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'New Request',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            key: ValueKey<String?>(
                              'app:$_selectedApplicationId',
                            ),
                            initialValue: _selectedApplicationId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Internship',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            items: _accepted
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.applicationId,
                                    child: Text(
                                      '${e.internshipTitle} — ${e.companyName}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(
                                    () => _selectedApplicationId = v,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>('reason:$_reason'),
                            initialValue: _reason,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Reason',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'illness',
                                child: Text(
                                  'Illness',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'family_emergency',
                                child: Text(
                                  'Family emergency',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text(
                                  'Other',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                            onChanged: _submitting
                                ? null
                                : (v) =>
                                      setState(() => _reason = v ?? 'illness'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _detailsCtrl,
                            minLines: 3,
                            maxLines: 6,
                            decoration: InputDecoration(
                              labelText: 'Details (optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 46,
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: const Icon(Icons.send),
                              label: Text(
                                _submitting
                                    ? 'Submitting...'
                                    : 'Submit request',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D28D9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Requests',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_requests.isEmpty)
                          const Text(
                            'No requests yet.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _requests.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _MyRequestRow(item: _requests[i]),
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
    );
  }
}

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
            color: Color(0x07000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MyRequestRow extends StatelessWidget {
  const _MyRequestRow({required this.item});
  final MyExcuseRequest item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.reasonType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                if (item.details != null && item.details!.isNotEmpty)
                  Text(
                    item.details!,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Created: ${item.createdAt.toLocal()}',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(status: item.status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().trim();
    Color bg;
    Color fg;
    String label;

    switch (s) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Approved';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Rejected';
        break;
      case 'cancelled':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF374151);
        label = 'Cancelled';
        break;
      default:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
