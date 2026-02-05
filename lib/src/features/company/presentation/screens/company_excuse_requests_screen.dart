import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../excuse/data/excuse_repository.dart';
import '../../../excuse/domain/excuse_models.dart';

class CompanyExcuseRequestsScreen extends ConsumerStatefulWidget {
  const CompanyExcuseRequestsScreen({super.key});

  @override
  ConsumerState<CompanyExcuseRequestsScreen> createState() =>
      _CompanyExcuseRequestsScreenState();
}

class _CompanyExcuseRequestsScreenState
    extends ConsumerState<CompanyExcuseRequestsScreen> {
  bool _loading = true;
  String _filter = 'pending'; // pending | all

  List<CompanyExcuseRequest> _items = const [];

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
      final repo = const ExcuseRepository();
      final status = _filter == 'pending' ? 'pending' : null;
      final items = await repo.listCompanyRequests(
        companyId: companyId,
        status: status,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(CompanyExcuseRequest r, String status) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            status == 'approved' ? 'Approve request?' : 'Reject request?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${r.studentName} • ${r.internshipTitle}'),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reviewer note (optional)',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'approved'
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final repo = const ExcuseRepository();
      await repo.reviewRequest(
        requestId: r.id,
        newStatus: status,
        reviewerNote: noteCtrl.text.trim().isEmpty
            ? null
            : noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Excuse Requests',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.t(AppText.retry),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Pending'),
                      selected: _filter == 'pending',
                      onSelected: (v) => setState(() {
                        _filter = 'pending';
                        _load();
                      }),
                      selectedColor: const Color(0xFFEDE9FE),
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == 'all',
                      onSelected: (v) => setState(() {
                        _filter = 'all';
                        _load();
                      }),
                      selectedColor: const Color(0xFFEDE9FE),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text(
                            'No requests.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _RequestCard(
                            item: _items[i],
                            onApprove: _items[i].status == 'pending'
                                ? () => _review(_items[i], 'approved')
                                : null,
                            onReject: _items[i].status == 'pending'
                                ? () => _review(_items[i], 'rejected')
                                : null,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });
  final CompanyExcuseRequest item;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.studentName.isEmpty
                      ? item.studentEmail
                      : item.studentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _StatusPill(status: item.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.internshipTitle,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(text: item.reasonType.replaceAll('_', ' ')),
              _Tag(text: 'Created: ${item.createdAt.toLocal()}'),
            ],
          ),
          if (item.details != null && item.details!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.details!,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (item.reviewerNote != null && item.reviewerNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                'Note: ${item.reviewerNote!}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: Color(0xFF374151),
        ),
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
