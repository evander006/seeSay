import 'package:flutter/material.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/features/home/presentation/accessible_action.dart';

/// Shared building blocks so every tab has the same rhythm: 16 px gutters, white cards with a
/// 24 px radius, one large title per screen.
abstract final class Gaps {
  static const page = EdgeInsets.fromLTRB(16, 8, 16, 24);
  static const between = SizedBox(height: 12);
}

class PageTitle extends StatelessWidget {
  const PageTitle({
    required this.title,
    this.subtitle,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final item in trailing) ...[const SizedBox(width: 8), item],
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final String? title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Shadow outside, Material inside: list rows in the card keep their ink ripples.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x0F101828), blurRadius: 18, spreadRadius: -6, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Semantics(
                header: true,
                child: Text(
                  title!,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({required this.color, this.size = 10, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)],
      ),
    );
  }
}

/// Full-width pill button that also works with the app's touch exploration for blind users.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.id,
    required this.label,
    required this.onTap,
    this.hint = 'Двойное нажатие для активации',
    this.icon,
    this.busy = false,
    this.tone = ButtonTone.accent,
    super.key,
  });

  final String id;
  final String label;
  final String hint;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final (background, foreground) = switch (tone) {
      ButtonTone.accent => (AppColors.accent, Colors.white),
      ButtonTone.quiet => (AppColors.circle, AppColors.ink),
    };
    return AccessibleAction(
      id: id,
      label: label,
      hint: hint,
      enabled: enabled,
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled || busy ? 1 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(27),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground),
                )
              else if (icon != null)
                Icon(icon, color: foreground, size: 22),
              if (busy || icon != null) const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ButtonTone { accent, quiet }

String clock(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
