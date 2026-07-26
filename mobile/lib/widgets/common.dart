import 'package:flutter/material.dart';
import '../theme.dart';
export '../theme.dart' show upColor, downColor, warningColor, brandPurple, brandPurpleDeep, brandBlue;

/// Bottom padding that clears Android's system nav bar (3-button or gesture
/// pill) -- needed on any screen that doesn't sit above the app's own
/// bottomNavigationBar (Scaffold only reserves that space automatically for
/// an actual bottomNavigationBar, not for a plain scrollable body), otherwise
/// the last bit of content renders underneath/behind the system bar on
/// edge-to-edge Android.
double bottomSafePadding(BuildContext context, {double extra = 16}) {
  return MediaQuery.paddingOf(context).bottom + extra;
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A rounded, tonal card wrapping a block of content -- the app's one
/// container primitive, used instead of ad-hoc Container+BoxDecoration so
/// every "grouped" section of a screen reads consistently.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: padding, child: child));
  }
}

class DeltaText extends StatelessWidget {
  final double? value;
  final double fontSize;
  const DeltaText({super.key, this.value, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text('—', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: fontSize));
    }
    final positive = value! >= 0;
    final color = positive ? upColor : downColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(positive ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: color, size: fontSize + 6),
        Text(
          '${value!.abs().toStringAsFixed(2)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: fontSize),
        ),
      ],
    );
  }
}

class DataQualityBadge extends StatelessWidget {
  final String? quality;
  const DataQualityBadge({super.key, this.quality});

  @override
  Widget build(BuildContext context) {
    final q = quality ?? 'Unknown';
    final color = switch (q) {
      'Good' => upColor,
      'Degraded' => warningColor,
      'Poor' => downColor,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Text(q, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// A short project-category tag (DeFi/Perp/DEX/...) -- one consistent style
/// regardless of which category, so it reads as "informational tag" rather
/// than competing for attention with the data-quality/label badges already
/// on the same row.
class CategoryBadge extends StatelessWidget {
  final String category;
  const CategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(category, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: scheme.tertiary)),
    );
  }
}

/// A single metric in a card-based grid -- icon + label on top, value below,
/// consistent across Dashboard/Token Detail/Insight.
class StatTile extends StatelessWidget {
  final String label;
  final Widget value;
  final IconData? icon;
  final Color? iconColor;
  const StatTile({super.key, required this.label, required this.value, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: iconColor ?? scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              child: value,
            ),
          ],
        ),
      ),
    );
  }
}

String formatUsd(double? v) {
  if (v == null) return '—';
  final abs = v.abs();
  if (abs >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
  if (abs >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
  if (abs >= 1e3) return '\$${(v / 1e3).toStringAsFixed(1)}K';
  return '\$${v.toStringAsFixed(2)}';
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// A round token avatar for a list row -- the real CoinGecko logo when one's
/// been fetched (via a recent price refresh), otherwise a tinted initial
/// letter so there's still a visual anchor instead of just left-aligned text.
class TickerAvatar extends StatelessWidget {
  final String ticker;
  final String? imageUrl;
  final double radius;
  const TickerAvatar({super.key, required this.ticker, this.imageUrl, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hue = (ticker.codeUnitAt(0) * 37) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, scheme.brightness == Brightness.dark ? 0.32 : 0.85).toColor();
    final fg = HSLColor.fromAHSL(1, hue.toDouble(), 0.6, scheme.brightness == Brightness.dark ? 0.78 : 0.32).toColor();
    final letter = CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        ticker.isNotEmpty ? ticker[0] : '?',
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: radius * 0.8),
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return letter;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => letter,
        ),
      ),
    );
  }
}
