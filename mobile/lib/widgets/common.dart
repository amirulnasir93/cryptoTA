import 'package:flutter/material.dart';

const Color upColor = Color(0xFF0CA30C);
const Color downColor = Color(0xFFE66767);

class DeltaText extends StatelessWidget {
  final double? value;
  const DeltaText({super.key, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null) return const Text('—', style: TextStyle(color: Colors.grey));
    final positive = value! >= 0;
    return Text(
      '${positive ? '+' : ''}${value!.toStringAsFixed(2)}%',
      style: TextStyle(color: positive ? upColor : downColor, fontWeight: FontWeight.w600),
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
      'Degraded' => const Color(0xFFC98500),
      'Poor' => downColor,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(q, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final Widget value;
  const StatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 4),
          DefaultTextStyle.merge(style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), child: value),
        ],
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
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
