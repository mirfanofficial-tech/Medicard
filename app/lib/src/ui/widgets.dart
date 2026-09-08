import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Section title with an optional trailing "View all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onAction, this.actionLabel = 'View all'});

  final String title;
  final VoidCallback? onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: const Text('View all',
                  style: TextStyle(color: MediCardColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Icon + big count + label tile, used in the home "Health Summary" grid.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = MediCardColors.primary,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MediCardColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: MediCardColors.ink)),
                Text(label,
                    style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Row used in menu / list screens (Profile, Settings, Records…).
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = MediCardColors.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right, size: 20)),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline, this.color});

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? MediCardColors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: MediCardColors.muted),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600, color: MediCardColors.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// 6-box one-time-code input.
class PinBoxes extends StatelessWidget {
  const PinBoxes({super.key, required this.controller, this.length = 6, this.onCompleted});

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: length,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        if (v.length == length) onCompleted?.call(v);
      },
      decoration: const InputDecoration(counterText: '', hintText: '– – – – – –'),
      style: const TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    );
  }
}

/// Consistent loading + error placeholders for AsyncValue-backed bodies.
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
      );
}

class ErrorBlock extends StatelessWidget {
  const ErrorBlock(this.error, {super.key});
  final Object error;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load.\n$error', textAlign: TextAlign.center),
        ),
      );
}
