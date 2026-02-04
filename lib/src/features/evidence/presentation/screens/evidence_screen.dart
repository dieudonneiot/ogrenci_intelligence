import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../focus_check/domain/focus_models.dart';
import '../../application/evidence_providers.dart';
import '../../domain/evidence_models.dart';

class EvidenceScreen extends ConsumerStatefulWidget {
  const EvidenceScreen({super.key});

  @override
  ConsumerState<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends ConsumerState<EvidenceScreen> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewStateProvider).value;
    final uid = auth?.user?.id;
    final isLoggedIn = auth?.isAuthenticated == true && uid != null && uid.isNotEmpty;

    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: Text('Please sign in to upload evidence.')),
      );
    }

    final asyncList = ref.watch(myEvidenceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: Color(0xFF6D28D9)),
                    const SizedBox(width: 10),
                    const Text('Evidence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => ref.read(myEvidenceProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : () => _openUpload(uid),
                        icon: const Icon(Icons.upload_file),
                        label: Text(_uploading ? 'Uploading...' : 'Upload'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upload proof of your work. Your company will approve or reject it.',
                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: asyncList.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Failed to load: $e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Center(child: Text('No evidence uploaded yet.'));
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _EvidenceCard(item: items[i]),
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

  Future<void> _openUpload(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = true);
    try {
      final repo = ref.read(evidenceRepositoryProvider);
      final internships = await repo.listMyAcceptedInternships(userId: userId);
      if (!mounted) return;
      if (internships.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need an accepted internship to upload evidence.')),
        );
        return;
      }

      final result = await showModalBottomSheet<_UploadResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _UploadSheet(internships: internships),
      );

      if (!mounted) return;
      if (result == null) return;

      await repo.pickFileAndUpload(
        userId: userId,
        draft: EvidenceUploadDraft(
          internshipApplicationId: result.internshipApplicationId,
          title: result.title,
          description: result.description,
        ),
      );

      ref.invalidate(myEvidenceProvider);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Uploaded. Pending approval.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.item});
  final EvidenceItem item;

  @override
  Widget build(BuildContext context) {
    Color tagBg;
    Color tagFg;
    String tag;
    switch (item.status) {
      case EvidenceStatus.approved:
        tagBg = const Color(0xFFDCFCE7);
        tagFg = const Color(0xFF16A34A);
        tag = 'Approved';
        break;
      case EvidenceStatus.rejected:
        tagBg = const Color(0xFFFFE4E6);
        tagFg = const Color(0xFFBE123C);
        tag = 'Rejected';
        break;
      case EvidenceStatus.pending:
        tagBg = const Color(0xFFFFF7ED);
        tagFg = const Color(0xFFB45309);
        tag = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF6D28D9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (item.title == null || item.title!.isEmpty) ? 'Evidence' : item.title!,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tagFg.withValues(alpha: 0.25)),
                      ),
                      child: Text(tag, style: TextStyle(color: tagFg, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                if ((item.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.description!, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 10),
                Text(
                  'Uploaded: ${item.createdAt.toLocal()}',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadResult {
  const _UploadResult({
    required this.internshipApplicationId,
    required this.title,
    required this.description,
  });

  final String internshipApplicationId;
  final String title;
  final String description;
}

class _UploadSheet extends StatefulWidget {
  const _UploadSheet({required this.internships});
  final List<AcceptedInternshipApplication> internships;

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  late AcceptedInternshipApplication _selected = widget.internships.first;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Evidence', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          const Text('Select your internship and choose a file.', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AcceptedInternshipApplication>(
                isExpanded: true,
                value: _selected,
                items: [
                  for (final it in widget.internships)
                    DropdownMenuItem(
                      value: it,
                      child: Text(
                        '${it.companyName} — ${it.internshipTitle}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _selected = v ?? _selected),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(
                  _UploadResult(
                    internshipApplicationId: _selected.applicationId,
                    title: _titleCtrl.text.trim(),
                    description: _descCtrl.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('Pick File & Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
