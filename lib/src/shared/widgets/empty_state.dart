import 'package:flutter/material.dart';

class PlaceholderAction {
  const PlaceholderAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

/// Use this INSIDE a ShellRoute / existing Scaffold.
/// (No Scaffold here to avoid nesting.)
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.padding = const EdgeInsets.all(24),
    this.maxWidth = 520,
  });

  final String title;
  final String? subtitle;

  /// Optional icon at top (simple & clean)
  final IconData? icon;

  /// Optional actions (CTA buttons)
  final PlaceholderAction? primaryAction;
  final PlaceholderAction? secondaryAction;

  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = subtitle?.trim();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (primaryAction != null || secondaryAction != null) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (primaryAction != null)
                        FilledButton.icon(
                          onPressed: primaryAction!.onPressed,
                          icon: primaryAction!.icon == null
                              ? const SizedBox.shrink()
                              : Icon(primaryAction!.icon, size: 18),
                          label: Text(primaryAction!.label),
                        ),
                      if (secondaryAction != null)
                        OutlinedButton.icon(
                          onPressed: secondaryAction!.onPressed,
                          icon: secondaryAction!.icon == null
                              ? const SizedBox.shrink()
                              : Icon(secondaryAction!.icon, size: 18),
                          label: Text(secondaryAction!.label),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Use this ONLY when you really want a standalone page with its own Scaffold.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.showAppBar = false,
    this.appBarTitle,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final PlaceholderAction? primaryAction;
  final PlaceholderAction? secondaryAction;

  final bool showAppBar;
  final String? appBarTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(appBarTitle ?? title)) : null,
      body: PlaceholderView(
        title: title,
        subtitle: subtitle,
        icon: icon,
        primaryAction: primaryAction,
        secondaryAction: secondaryAction,
      ),
    );
  }
}
