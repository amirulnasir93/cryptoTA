import 'package:flutter/material.dart';

/// A pulsing placeholder box -- the one shimmer primitive every skeleton
/// screen in the app is built from, so loading states read as "the real
/// layout, dimmed" rather than a generic spinner with no sense of what's
/// about to appear.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _opacity = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: _opacity.value * 0.9),
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

/// Mirrors the Dashboard's real layout (stat tile grid + token list) so the
/// loading state reads as "the page is about to appear" rather than a bare
/// spinner with no shape.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: const [
            Expanded(child: _StatTileSkeleton()),
            SizedBox(width: 10),
            Expanded(child: _StatTileSkeleton()),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: _StatTileSkeleton()),
            SizedBox(width: 10),
            Expanded(child: _StatTileSkeleton()),
          ],
        ),
        const SizedBox(height: 24),
        const Skeleton(width: 90, height: 18),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                const _TokenRowSkeleton(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTileSkeleton extends StatelessWidget {
  const _StatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Skeleton(width: 70, height: 11),
            const SizedBox(height: 8),
            Skeleton(width: 48, height: 17, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      ),
    );
  }
}

class _TokenRowSkeleton extends StatelessWidget {
  const _TokenRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Skeleton.circle(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Skeleton(width: 56, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                Skeleton(width: 110, height: 11, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Skeleton(width: 52, height: 13, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }
}

/// Mirrors the Token Detail Overview tab's real layout.
class TokenOverviewSkeleton extends StatelessWidget {
  const TokenOverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            const Skeleton.circle(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Skeleton(width: 120, height: 16, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  Skeleton(width: 80, height: 11, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: const [
            _StatTileSkeleton(),
            _StatTileSkeleton(),
            _StatTileSkeleton(),
            _StatTileSkeleton(),
            _StatTileSkeleton(),
            _StatTileSkeleton(),
          ],
        ),
        const SizedBox(height: 20),
        const Skeleton(width: 100, height: 15),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Skeleton(width: double.infinity, height: 60))),
        const SizedBox(height: 20),
        const Skeleton(width: 80, height: 15),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Skeleton(width: double.infinity, height: 90))),
      ],
    );
  }
}

/// Mirrors the Technical Analysis tab's real layout (candlestick + indicator
/// panels), matching each real panel's actual fixed height.
class TechnicalAnalysisSkeleton extends StatelessWidget {
  const TechnicalAnalysisSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Skeleton(width: 70, height: 20, borderRadius: BorderRadius.circular(999)),
            const Skeleton(width: 80, height: 12),
          ],
        ),
        const SizedBox(height: 16),
        Card(child: SizedBox(height: 340, child: Center(child: Skeleton(width: double.infinity, height: 340)))),
        const SizedBox(height: 12),
        for (final h in [110.0, 90.0, 120.0, 120.0, 100.0]) ...[
          Card(child: SizedBox(height: h, child: Padding(padding: const EdgeInsets.all(14), child: Skeleton(width: double.infinity, height: h - 28)))),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Mirrors the Insight tab's real layout (description card + stat grid).
class InsightSkeleton extends StatelessWidget {
  const InsightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Skeleton(width: double.infinity, height: 70))),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Skeleton(width: 70, height: 26, borderRadius: BorderRadius.circular(999)),
            Skeleton(width: 90, height: 26, borderRadius: BorderRadius.circular(999)),
            Skeleton(width: 60, height: 26, borderRadius: BorderRadius.circular(999)),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: const [
            _StatTileSkeleton(),
            _StatTileSkeleton(),
            _StatTileSkeleton(),
            _StatTileSkeleton(),
          ],
        ),
      ],
    );
  }
}
