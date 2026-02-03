import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _subject = '';
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _subject.trim().isEmpty ||
        _messageCtrl.text.trim().isEmpty) {
      _snack(l10n.t(AppText.contactFillRequired), isError: true);
      return;
    }

    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() => _sending = false);
    _nameCtrl.clear();
    _emailCtrl.clear();
    _messageCtrl.clear();
    _subject = '';

    _snack(l10n.t(AppText.contactSendSuccess));
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : null),
    );
  }

  Future<void> _launch(String uri) async {
    final url = Uri.tryParse(uri);
    if (url == null) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) {
                    final isNarrow = c.maxWidth < 860;
                    return Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        SizedBox(
                          width: isNarrow ? c.maxWidth : c.maxWidth * 0.36,
                          child: Column(
                            children: [
                              _InfoCard(
                                icon: Icons.mail_outline,
                                color: const Color(0xFF7C3AED),
                                title: l10n.t(AppText.contactEmailTitle),
                                child: InkWell(
                                  onTap: () => _launch('mailto:info@ogrenciintelligence.com'),
                                  child: const Text(
                                    'info@ogrenciintelligence.com',
                                    style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              _InfoCard(
                                icon: Icons.phone_outlined,
                                color: const Color(0xFF16A34A),
                                title: l10n.t(AppText.contactPhoneTitle),
                                child: InkWell(
                                  onTap: () => _launch('tel:+905524635992'),
                                  child: const Text(
                                    '+90 (552) 463 59 92',
                                    style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              _InfoCard(
                                icon: Icons.location_on_outlined,
                                color: Color(0xFF2563EB),
                                title: l10n.t(AppText.contactAddressTitle),
                                child: Text(l10n.t(AppText.contactAddressBody),
                                    style: const TextStyle(color: Color(0xFF6B7280))),
                              ),
                              _InfoCard(
                                icon: Icons.schedule,
                                color: Color(0xFFF59E0B),
                                title: l10n.t(AppText.contactHoursTitle),
                                child: Text(l10n.t(AppText.contactHoursBody),
                                    style: const TextStyle(color: Color(0xFF6B7280))),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: isNarrow ? c.maxWidth : c.maxWidth * 0.6,
                          child: Column(
                            children: [
                              _FormCard(
                                nameCtrl: _nameCtrl,
                                emailCtrl: _emailCtrl,
                                messageCtrl: _messageCtrl,
                                subject: _subject,
                                onSubjectChanged: (v) => setState(() => _subject = v ?? ''),
                                sending: _sending,
                                onSend: _send,
                              ),
                              const SizedBox(height: 20),
                              const _FaqCard(),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const _MapPlaceholder(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: _GlowCircle(color: Colors.white.withValues(alpha: 0.08), size: 140),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: _GlowCircle(color: Colors.white.withValues(alpha: 0.06), size: 120),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t(AppText.contactHeroTitle),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                l10n.t(AppText.contactHeroSubtitle),
                style: const TextStyle(color: Color(0xFFCBD5F5), height: 1.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.messageCtrl,
    required this.subject,
    required this.onSubjectChanged,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController messageCtrl;
  final String subject;
  final ValueChanged<String?> onSubjectChanged;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Color(0xFF6D28D9)),
              const SizedBox(width: 8),
              Text(l10n.t(AppText.contactFormTitle), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 600;
              final fieldWidth = isNarrow ? c.maxWidth : (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _Field(
                      label: l10n.t(AppText.contactNameLabelRequired),
                      controller: nameCtrl,
                      hint: l10n.t(AppText.contactNameHint),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _Field(
                      label: l10n.t(AppText.contactEmailLabelRequired),
                      controller: emailCtrl,
                      hint: l10n.t(AppText.contactEmailHint),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: subject.isEmpty ? null : subject,
            onChanged: onSubjectChanged,
            items: [
              DropdownMenuItem(value: 'general', child: Text(l10n.t(AppText.contactSubjectGeneral))),
              DropdownMenuItem(value: 'support', child: Text(l10n.t(AppText.contactSubjectSupport))),
              DropdownMenuItem(value: 'partnership', child: Text(l10n.t(AppText.contactSubjectPartnership))),
              DropdownMenuItem(value: 'feedback', child: Text(l10n.t(AppText.contactSubjectFeedback))),
              DropdownMenuItem(value: 'other', child: Text(l10n.t(AppText.contactSubjectOther))),
            ],
            decoration: InputDecoration(
              labelText: l10n.t(AppText.contactSubjectLabelRequired),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          _Field(
            label: l10n.t(AppText.contactMessageLabelRequired),
            controller: messageCtrl,
            hint: l10n.t(AppText.contactMessageHint),
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.t(AppText.contactRequiredNote), style: const TextStyle(color: Color(0xFF6B7280))),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(sending ? l10n.t(AppText.commonSending) : l10n.t(AppText.commonSend)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.hint, this.maxLines = 1});

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t(AppText.contactFaqTitle), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _FaqItem(
            question: l10n.t(AppText.contactFaqQ1),
            answer: l10n.t(AppText.contactFaqA1),
          ),
          _FaqItem(
            question: l10n.t(AppText.contactFaqQ2),
            answer: l10n.t(AppText.contactFaqA2),
          ),
          _FaqItem(
            question: l10n.t(AppText.contactFaqQ3),
            answer: l10n.t(AppText.contactFaqA3),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(answer, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 8),
            Text(l10n.t(AppText.contactMapPlaceholder), style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
