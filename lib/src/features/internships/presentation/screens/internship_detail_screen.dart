import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../application/internships_providers.dart';
import '../../domain/internship_models.dart';

class InternshipDetailScreen extends ConsumerWidget {
  const InternshipDetailScreen({super.key, required this.internshipId});
  final String internshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncVm = ref.watch(internshipDetailProvider(internshipId));

    return asyncVm.when(
      loading: () => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.internshipDetailLoadFailed(e.toString()),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(internshipDetailProvider(internshipId).notifier)
                        .refresh(),
                    child: Text(l10n.t(AppText.retry)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (vm) => _InternshipDetailBody(vm: vm),
    );
  }
}

class _InternshipDetailBody extends ConsumerWidget {
  const _InternshipDetailBody({required this.vm});
  final InternshipDetailViewModel vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final item = vm.item;
    final i = item.internship;
    final app = item.myApplication;

    final req = i.requirements;
    final ben = i.benefits;
    final hasApplied = app != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          l10n.t(AppText.internshipDetailTitle),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () => ref
                .read(internshipDetailProvider(i.id).notifier)
                .toggleFavorite(),
            icon: Icon(
              item.isFavorite ? Icons.favorite : Icons.favorite_border,
            ),
            color: item.isFavorite
                ? const Color(0xFFEF4444)
                : const Color(0xFF64748B),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: LayoutBuilder(
              builder: (_, c) {
                final wide = c.maxWidth >= 980;

                final left = _MainDetail(
                  internship: i,
                  status: app?.status,
                  requirements: req,
                  benefits: ben,
                );

                final right = _ApplyCard(
                  internshipId: i.id,
                  hasApplied: hasApplied,
                  status: app?.status,
                  onApply: (motivation) async {
                    try {
                      await ref
                          .read(internshipDetailProvider(i.id).notifier)
                          .apply(motivation);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.t(AppText.internshipDetailApplySuccess),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.internshipDetailApplyFailed(e.toString()),
                            ),
                          ),
                        );
                      }
                    }
                  },
                );

                if (!wide) {
                  return Column(
                    children: [left, const SizedBox(height: 14), right],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: left),
                    const SizedBox(width: 16),
                    SizedBox(width: 380, child: right),
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

class _MainDetail extends StatelessWidget {
  const _MainDetail({
    required this.internship,
    required this.status,
    required this.requirements,
    required this.benefits,
  });

  final Internship internship;
  final InternshipApplicationStatus? status;
  final List<String> requirements;
  final List<String> benefits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final i = internship;
    final location = i.isRemote
        ? l10n.t(AppText.remote)
        : (i.location ?? l10n.t(AppText.internshipsNotSpecified));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
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
                  i.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (status != null) _StatusPill(status: status!),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            i.companyName,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(icon: Icons.place_outlined, text: location),
              _Chip(
                icon: Icons.timelapse,
                text: l10n.internshipsMonths(i.durationMonths),
              ),
              if (i.deadline != null)
                _Chip(
                  icon: Icons.event_outlined,
                  text: l10n.deadlineLabel(_fmtDate(context, i.deadline!)),
                ),
              if (i.isPaid)
                _Chip(
                  icon: Icons.payments_outlined,
                  text: i.monthlyStipend != null
                      ? l10n.internshipsMonthlyStipend(
                          i.monthlyStipend!.toStringAsFixed(0),
                        )
                      : l10n.t(AppText.internshipsPaid),
                  fg: const Color(0xFF16A34A),
                  bg: const Color(0xFFDCFCE7),
                ),
              if (i.providesCertificate)
                _Chip(
                  icon: Icons.verified_outlined,
                  text: l10n.t(AppText.internshipDetailCertificate),
                ),
              if (i.possibilityOfEmployment)
                _Chip(
                  icon: Icons.trending_up,
                  text: l10n.t(AppText.internshipDetailEmploymentChance),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle(l10n.t(AppText.internshipDetailAbout)),
          const SizedBox(height: 8),
          Text(
            i.description.isNotEmpty
                ? i.description
                : l10n.t(AppText.commonNoDescription),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle(l10n.t(AppText.internshipDetailBenefits)),
          const SizedBox(height: 8),
          if (benefits.isEmpty)
            Text(
              l10n.t(AppText.internshipsNotSpecified),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            _Bullets(items: benefits),
          const SizedBox(height: 14),
          _SectionTitle(l10n.t(AppText.internshipDetailRequirements)),
          const SizedBox(height: 8),
          if (requirements.isEmpty)
            Text(
              l10n.t(AppText.internshipsNotSpecified),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            _Bullets(items: requirements),
          const SizedBox(height: 14),
          _SectionTitle(l10n.t(AppText.internshipDetailProcess)),
          const SizedBox(height: 8),
          _Bullets(
            items: [
              l10n.t(AppText.internshipDetailProcessStep1),
              l10n.t(AppText.internshipDetailProcessStep2),
              l10n.t(AppText.internshipDetailProcessStep3),
              l10n.t(AppText.internshipDetailProcessStep4),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtDate(BuildContext context, DateTime d) {
    return MaterialLocalizations.of(context).formatShortDate(d.toLocal());
  }
}

class _ApplyCard extends StatelessWidget {
  const _ApplyCard({
    required this.internshipId,
    required this.hasApplied,
    required this.status,
    required this.onApply,
  });

  final String internshipId;
  final bool hasApplied;
  final InternshipApplicationStatus? status;
  final Future<void> Function(String motivation) onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = status ?? InternshipApplicationStatus.pending;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t(AppText.internshipDetailApplyTitle),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (hasApplied) ...[
            _StatusLine(status: s),
            const SizedBox(height: 10),
            Text(
              l10n.t(AppText.internshipDetailAlreadyApplied),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text(
              l10n.internshipDetailApplyHint(100),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openApplySheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.t(AppText.internshipDetailApplyButton),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openApplySheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              final len = ctrl.text.trim().length;
              final ok = len >= 100;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t(AppText.internshipDetailMotivationTitle),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    maxLines: 7,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.t(AppText.internshipDetailMotivationHint),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$len/100',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: ok
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: ok
                          ? () async {
                              final text = ctrl.text.trim();
                              Navigator.of(context).pop();
                              await onApply(text);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.t(AppText.commonSend),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});
  final InternshipApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(AppLocalizations.of(context), status);
    final color = _statusColor(status);

    return Row(
      children: [
        Icon(Icons.verified, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final InternshipApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(AppLocalizations.of(context), status);
    final bg = _statusBg(status);
    final fg = _statusColor(status);

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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    this.bg = const Color(0xFFF3F4F6),
    this.fg = const Color(0xFF374151),
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(AppLocalizations l10n, InternshipApplicationStatus status) {
  switch (status) {
    case InternshipApplicationStatus.accepted:
      return l10n.t(AppText.statusAccepted);
    case InternshipApplicationStatus.rejected:
      return l10n.t(AppText.statusRejected);
    case InternshipApplicationStatus.pending:
      return l10n.t(AppText.internshipDetailStatusSubmitted);
  }
}

Color _statusColor(InternshipApplicationStatus status) {
  switch (status) {
    case InternshipApplicationStatus.accepted:
      return const Color(0xFF16A34A);
    case InternshipApplicationStatus.rejected:
      return const Color(0xFFDC2626);
    case InternshipApplicationStatus.pending:
      return const Color(0xFFD97706);
  }
}

Color _statusBg(InternshipApplicationStatus status) {
  switch (status) {
    case InternshipApplicationStatus.accepted:
      return const Color(0xFFDCFCE7);
    case InternshipApplicationStatus.rejected:
      return const Color(0xFFFEE2E2);
    case InternshipApplicationStatus.pending:
      return const Color(0xFFFEF3C7);
  }
}
