import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../data/stats.dart';
import 'widgets.dart';

/// Stacked bars per bucket: done (green) under missed (red), with excused
/// (accent) and still-to-come (pale) on top. Tapping a bar shows its counts.
class StackedBars extends StatefulWidget {
  const StackedBars({
    super.key,
    required this.buckets,
    required this.label,
    this.height = 150,
    this.showLabel,
  });

  final List<Bucket> buckets;
  final String Function(Bucket b) label;

  /// Which bars get a label under them (all by default).
  final bool Function(int i)? showLabel;
  final double height;

  @override
  State<StackedBars> createState() => _StackedBarsState();
}

class _StackedBarsState extends State<StackedBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bs = widget.buckets;
    var max = 1;
    for (final b in bs) {
      final t = b.tally;
      final sum = t.done + t.missed + t.excused + t.pending;
      if (sum > max) max = sum;
    }
    final sel = _selected == null ? null : bs[_selected!];

    Widget seg(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Container(
            height: widget.height * n / max,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
            margin: const EdgeInsets.only(top: 1),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, b) in bs.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    label:
                        '${widget.label(b)}: ${tr('{d} اتعمل، {m} ما اتعملش', {'d': b.tally.done, 'm': b.tally.missed})}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _selected = _selected == i ? null : i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: bs.length > 14 ? 1 : 4,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _selected == i
                                ? p.gold.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              seg(b.tally.pending, p.line),
                              seg(
                                b.tally.excused,
                                p.gold.withValues(alpha: 0.6),
                              ),
                              seg(b.tally.missed, p.red),
                              seg(b.tally.done, p.green),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (i, b) in bs.indexed)
              Expanded(
                child: Text(
                  (widget.showLabel?.call(i) ?? true) ? widget.label(b) : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(fontSize: 10, color: p.muted),
                ),
              ),
          ],
        ),
        if (sel != null) ...[
          const SizedBox(height: 8),
          HintBox(
            '${widget.label(sel)}: ${tr('{d} اتعمل، {m} ما اتعملش', {'d': sel.tally.done, 'm': sel.tally.missed})}'
            '${sel.tally.excused > 0 ? '${listSep()}${tr('{n} معذور', {'n': sel.tally.excused})}' : ''}'
            '${sel.tally.pending > 0 ? '${listSep()}${tr('{n} لسه', {'n': sel.tally.pending})}' : ''}',
          ),
        ],
      ],
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget item(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(t, style: TextStyle(fontSize: 12, color: p.muted)),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(p.green, tr('اتعمل')),
        item(p.red, tr('ما اتعملش')),
        item(p.gold.withValues(alpha: 0.6), tr('معذور')),
        item(p.line, tr('لسه')),
      ],
    );
  }
}

/// Short label for a bucket of [span].
String bucketLabel(Span span, Bucket b) => switch (span) {
  Span.week => weekdayShort(b.from.weekday),
  Span.month => n(b.from.day),
  Span.year => n(b.from.month),
};

/// Color for a completion rate: red when low, accent in the middle, green
/// when high; pale when there is nothing to judge.
Color rateColor(BuildContext context, double? rate) {
  final p = context.pal;
  if (rate == null) return p.line;
  if (rate >= 0.75) return p.green;
  if (rate >= 0.4) return p.gold;
  return p.red;
}

String rateText(double? rate) => rate == null ? '—' : pct(rate);
