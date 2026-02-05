import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/domain/auth_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../application/evidence_providers.dart';
import '../../domain/evidence_models.dart';

class CompanyEvidenceScreen extends ConsumerWidget {
  const CompanyEvidenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authViewStateProvider).value;
    if (auth == null ||
        !auth.isAuthenticated ||
        auth.userType != UserType.company) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: Text('Company login required.')),
      );
    }

    final asyncList = ref.watch(companyPendingEvidenceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Evidence Approvals',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => ref
                          .read(companyPendingEvidenceProvider.notifier)
                          .refresh(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Review student uploads and approve or reject.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: asyncList.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Failed to load: $e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No pending evidence.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _PendingEvidenceCard(item: items[i]),
                      );
                    },
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

class _PendingEvidenceCard extends ConsumerStatefulWidget {
  const _PendingEvidenceCard({required this.item});
  final EvidenceItem item;

  @override
  ConsumerState<_PendingEvidenceCard> createState() =>
      _PendingEvidenceCardState();
}

class _PendingEvidenceCardState extends ConsumerState<_PendingEvidenceCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(evidenceRepositoryProvider);
    final item = widget.item;

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
              const Icon(
                Icons.insert_drive_file_outlined,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (item.title == null || item.title!.isEmpty)
                      ? 'Evidence'
                      : item.title!,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFB45309).withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if ((item.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Uploaded: ${item.createdAt.toLocal()}',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _busy = true);
                        try {
                          final url = await repo.createSignedUrl(
                            filePath: item.filePath,
                          );
                          final ok = await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                          if (!mounted) return;
                          if (!ok) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Could not open file.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Open failed: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.open_in_new),
                label: const Text('View'),
              ),
              ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _busy = true);
                        try {
                          await ref
                              .read(companyPendingEvidenceProvider.notifier)
                              .review(evidenceId: item.id, status: 'approved');
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Approved.')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Approve failed: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _rejectDialog(item.id),
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: Color(0xFFBE123C),
                ),
                label: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDialog(String evidenceId) async {
    final ctrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject evidence'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(companyPendingEvidenceProvider.notifier)
          .review(evidenceId: evidenceId, status: 'rejected', reason: reason);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Rejected.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Reject failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
