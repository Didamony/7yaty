import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/adhkar.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'quran_page.dart';
import 'widgets.dart';

/// Bead colors for each sebha style: base, highlight, string.
const _beadStyles = {
  'wood': (Color(0xFF7A4A24), Color(0xFFC08A55), Color(0xFF5A3A1E)),
  'amber': (Color(0xFFC46A0E), Color(0xFFFFC56A), Color(0xFF8A5A20)),
  'pearl': (Color(0xFFD9D4CC), Color(0xFFFFFFFF), Color(0xFFA89F90)),
  'emerald': (Color(0xFF0E6B4F), Color(0xFF5FD3A6), Color(0xFFB08D3C)),
};

String styleName(String s) => tr(switch (s) {
  'wood' => 'خشب',
  'amber' => 'كهرمان',
  'pearl' => 'لؤلؤ',
  'emerald' => 'زمرد',
  _ => 'عداد رقمي',
});

/// After-prayer tasbih: 33 + 33 + 34.
const _afterPrayer = [(0, 33), (1, 33), (2, 34)];

class TasbihPage extends StatefulWidget {
  const TasbihPage({super.key});

  @override
  State<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<TasbihPage>
    with SingleTickerProviderStateMixin {
  late final AppStore _store;
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  int _count = 0;
  int _rounds = 0;
  int _session = 0;
  int _stage = 0;
  Timer? _save;

  Worship get _w => _store.data.worship;

  List<String> get _dhikrList => [...tasbihDhikr, ..._w.customDhikr];

  bool get _afterPrayerMode => _w.target == -1;

  String get _currentDhikr => _afterPrayerMode
      ? tasbihDhikr[_afterPrayer[_stage].$1]
      : _dhikrList[_w.dhikr.clamp(0, _dhikrList.length - 1)];

  int get _currentTarget =>
      _afterPrayerMode ? _afterPrayer[_stage].$2 : _w.target;

  @override
  void initState() {
    super.initState();
    _store = context.store;
  }

  @override
  void dispose() {
    if (_save?.isActive ?? false) {
      _save!.cancel();
      _store.update((_) {});
    }
    _slide.dispose();
    super.dispose();
  }

  void _tap() {
    final dhikr = _currentDhikr;
    _w.totals[dhikr] = (_w.totals[dhikr] ?? 0) + 1;
    _save?.cancel();
    _save = Timer(const Duration(seconds: 2), () => _store.update((_) {}));
    _slide.forward(from: 0);
    setState(() {
      _count++;
      _session++;
    });
    final target = _currentTarget;
    if (target > 0 && _count >= target) {
      if (_w.vibrate) HapticFeedback.heavyImpact();
      setState(() {
        _count = 0;
        _rounds++;
        if (_afterPrayerMode) {
          if (_stage < _afterPrayer.length - 1) {
            _stage++;
          } else {
            _stage = 0;
            toast(
              context,
              tr('تمّت المائة · قل: لا إله إلا الله وحده لا شريك له…'),
            );
          }
        }
      });
    } else if (_w.vibrate) {
      HapticFeedback.selectionClick();
    }
  }

  void _reset() => setState(() {
    _count = 0;
    _rounds = 0;
    _session = 0;
    _stage = 0;
  });

  void _set(void Function(Worship w) change) {
    _store.update((d) => change(d.worship));
    _reset();
  }

  Future<void> _addCustom() async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('ذكر جديد')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('اكتب الذكر')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text.trim()),
            child: Text(tr('أضف')),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (text == null || text.isEmpty) return;
    _set((w) {
      w.customDhikr.add(text);
      w.dhikr = tasbihDhikr.length + w.customDhikr.length - 1;
      if (w.target == -1) w.target = 33;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppStore>();
    final p = context.pal;
    final w = _w;
    final target = _currentTarget;
    final digital = w.tasbihStyle == 'digital';

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('السبحة'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
            actions: [
              HeaderIconButton(
                icon: w.vibrate ? Icons.vibration : Icons.mobile_off,
                tooltip: tr('الاهتزاز'),
                onPressed: () => _store.update(
                  (d) => d.worship.vibrate = !d.worship.vibrate,
                ),
              ),
              HeaderIconButton(
                icon: Icons.restart_alt,
                tooltip: tr('صفّر العداد'),
                onPressed: _reset,
              ),
            ],
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                for (final (i, d) in _dhikrList.indexed)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(
                        d,
                        style: const TextStyle(
                          fontFamily: kQuran,
                          fontSize: 15,
                        ),
                      ),
                      selected: !_afterPrayerMode && w.dhikr == i,
                      onSelected: (_) => _set((w) {
                        w.dhikr = i;
                        if (w.target == -1) w.target = 33;
                      }),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(tr('ذكر جديد')),
                  onPressed: _addCustom,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Pills<int>(
                  values: const [33, 99, 100, 1000, 0, -1],
                  selected: w.target,
                  label: (v) => switch (v) {
                    0 => tr('مفتوح'),
                    -1 => tr('بعد الصلاة ٣٣/٣٣/٣٤'),
                    _ => n(v),
                  },
                  onSelected: (v) => _set((w) => w.target = v),
                ),
                const SizedBox(height: 6),
                Pills<String>(
                  values: const [
                    'wood',
                    'amber',
                    'pearl',
                    'emerald',
                    'digital',
                  ],
                  selected: w.tasbihStyle,
                  label: styleName,
                  onSelected: (v) =>
                      _store.update((d) => d.worship.tasbihStyle = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: tr('سبّح: {d}', {'d': _currentDhikr}),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tap,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _currentDhikr,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: kQuran,
                          fontSize: 30,
                          height: 1.7,
                          color: p.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      child: digital
                          ? _DigitalCounter(
                              count: _count,
                              target: target,
                              onTap: _tap,
                            )
                          : AnimatedBuilder(
                              animation: _slide,
                              builder: (_, _) => CustomPaint(
                                size: Size.infinite,
                                painter: _BeadsPainter(
                                  colors: _beadStyles[w.tasbihStyle]!,
                                  count: _count,
                                  slide: _slide.value,
                                  ink: p.ink,
                                  label: target > 0
                                      ? '${n(_count)} / ${n(target)}'
                                      : n(_count),
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        children: [
                          Muted(tr('الجولات: {n}', {'n': _rounds}), size: 13),
                          Muted(tr('الجلسة: {n}', {'n': _session}), size: 13),
                          Muted(
                            tr('المجموع: {n}', {
                              'n': w.totals[_currentDhikr] ?? 0,
                            }),
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                    Muted(tr('اضغط في أي مكان عشان تسبّح')),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A loop of beads hanging from the top. Each tap slides the string by one
/// bead; every 33rd bead is a longer separator bead.
class _BeadsPainter extends CustomPainter {
  _BeadsPainter({
    required this.colors,
    required this.count,
    required this.slide,
    required this.ink,
    required this.label,
  });

  final (Color, Color, Color) colors;
  final int count;
  final double slide;
  final Color ink;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final (base, light, string) = colors;
    final cx = size.width / 2;
    final r = math.min(size.width * 0.42, size.height * 0.46);
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = string
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    const beads = 22;
    const step = 2 * math.pi / beads;
    for (var i = 0; i < beads; i++) {
      // Beads move clockwise; index 0 sits at the top.
      // During a tap the string moves from the previous spot to the new one.
      final angle = -math.pi / 2 + (i - 1 + slide) * step;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * r;
      final number = count - i;
      final separator = number % 33 == 0 && number > 0;
      final br = separator ? r * 0.11 : r * 0.085;
      final rect = Rect.fromCircle(center: pos, radius: br);
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [light, base],
        ).createShader(rect);
      if (separator) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle + math.pi / 2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: br * 1.6,
            height: br * 2.4,
          ),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(pos, br, paint);
      }
    }

    // The tassel hanging under the top bead.
    final top = center + Offset(0, -r);
    final tassel = Paint()
      ..color = string
      ..strokeWidth = 2;
    for (var k = -2; k <= 2; k++) {
      canvas.drawLine(
        top + const Offset(0, -6),
        top + Offset(k * 4.0, -r * 0.22),
        tassel,
      );
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: kDisplay,
          fontSize: r * 0.32,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: r * 1.6);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BeadsPainter old) =>
      old.count != count ||
      old.slide != slide ||
      old.colors != colors ||
      old.label != label ||
      old.ink != ink;
}

/// The handheld digital tasbih counter.
class _DigitalCounter extends StatelessWidget {
  const _DigitalCounter({
    required this.count,
    required this.target,
    required this.onTap,
  });

  final int count;
  final int target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2A2E),
          borderRadius: BorderRadius.circular(110),
          border: Border.all(color: const Color(0xFFB08D3C), width: 3),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x55000000),
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9DB89A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    count.toString().padLeft(4, '0'),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2B1B),
                      letterSpacing: 4,
                    ),
                  ),
                  if (target > 0)
                    Text(
                      '/ $target',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2E432C),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: const Color(0xFFD4B26A),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const SizedBox.square(
                  dimension: 96,
                  child: Center(
                    child: StarMark(size: 40, color: Color(0xFF1F2A2E)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
