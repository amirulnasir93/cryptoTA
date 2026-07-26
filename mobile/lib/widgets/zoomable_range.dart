import 'package:flutter/material.dart';

/// fl_chart's CandlestickChart/LineChart/BarChart have no built-in pinch-zoom
/// or pan -- each one just renders whatever fixed data range it's given, so
/// without this the Technical Analysis tab was a fully static full-range
/// chart. This tracks a visible [start, end) index window over some fixed
/// total length and drives it from a two-finger pinch (zoom, anchored at the
/// pinch's focal point so the point under your fingers stays put) and a
/// one-finger drag (pan) -- both arrive through the same onScaleUpdate
/// callback, since Flutter's scale gesture recognizer unifies them (a plain
/// drag reports scale: 1.0). A double-tap resets to the full range.
class ZoomableRange extends StatefulWidget {
  final int totalLength;
  final int minVisible;
  final Widget Function(BuildContext context, int startIndex, int endIndex) builder;

  const ZoomableRange({
    super.key,
    required this.totalLength,
    required this.builder,
    this.minVisible = 20,
  });

  @override
  State<ZoomableRange> createState() => _ZoomableRangeState();
}

class _ZoomableRangeState extends State<ZoomableRange> {
  double? _start; // null == full range (not zoomed)
  double? _end;

  double? _gestureStart;
  double? _gestureEnd;

  @override
  void didUpdateWidget(covariant ZoomableRange oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new interval/token swaps the underlying data length -- stale pixel
    // offsets from the old series would be meaningless against it.
    if (oldWidget.totalLength != widget.totalLength) {
      _start = null;
      _end = null;
    }
  }

  int get _minVisible => widget.minVisible.clamp(1, widget.totalLength);

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStart = _start ?? 0;
    _gestureEnd = _end ?? widget.totalLength.toDouble();
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    if (_gestureStart == null || _gestureEnd == null || width <= 0) return;
    final total = widget.totalLength.toDouble();
    final oldSpan = _gestureEnd! - _gestureStart!;
    final minSpan = _minVisible.toDouble();
    var newSpan = (oldSpan / details.scale).clamp(minSpan, total);

    // Anchor the zoom at the pinch's focal point -- the candle under your
    // fingers stays under your fingers instead of the view recentering.
    final focalFraction = (details.localFocalPoint.dx / width).clamp(0.0, 1.0);
    final focalIndex = _gestureStart! + oldSpan * focalFraction;
    var newStart = focalIndex - newSpan * focalFraction;

    // One-finger drag arrives as scale: 1.0 with a non-zero focal delta --
    // shift the window by the same fraction of the chart the finger moved.
    final panDelta = -details.focalPointDelta.dx / width * newSpan;
    newStart += panDelta;

    newStart = newStart.clamp(0.0, (total - newSpan).clamp(0.0, total));
    setState(() {
      _start = newStart;
      _end = newStart + newSpan;
    });
  }

  void _resetZoom() => setState(() {
    _start = null;
    _end = null;
  });

  @override
  Widget build(BuildContext context) {
    final zoomed = _start != null;
    final startIndex = (_start ?? 0).floor().clamp(0, widget.totalLength - 1);
    final endIndex = (_end ?? widget.totalLength.toDouble()).ceil().clamp(startIndex + 1, widget.totalLength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (zoomed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetZoom,
                icon: const Icon(Icons.zoom_out_map_rounded, size: 16),
                label: const Text('Reset zoom'),
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _resetZoom,
              onScaleStart: _onScaleStart,
              onScaleUpdate: (details) => _onScaleUpdate(details, constraints.maxWidth),
              child: widget.builder(context, startIndex, endIndex),
            );
          },
        ),
      ],
    );
  }
}
