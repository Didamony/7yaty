import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../services/files.dart';
import 'widgets.dart';

/// Share of the picture's area the note itself covers.
const kFrameContentArea = 0.6;

/// Built-in frames drawn in the current theme's colors.
const builtinFrames = ['arch', 'lattice', 'roses', 'dawn'];

String frameName(String id) => tr(switch (id) {
  'arch' => 'قوس',
  'lattice' => 'مشربية',
  'roses' => 'ورود',
  _ => 'فجر',
});

/// A note or recording shown on a picture, the content covering 60% of the
/// picture's area and centered on it like a photo in a frame.
class FramedCard extends StatelessWidget {
  const FramedCard({super.key, required this.frame, required this.child});

  /// `builtin:<id>` or a file name in the media folder.
  final String frame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(child: FrameBackground(frame: frame)),
          _FrameLayout(
            side: math.sqrt(kFrameContentArea),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.card.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.gold.withValues(alpha: 0.6)),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class FrameBackground extends StatelessWidget {
  const FrameBackground({super.key, required this.frame});

  final String frame;

  @override
  Widget build(BuildContext context) {
    if (frame.startsWith('builtin:')) {
      return CustomPaint(
        painter: _BuiltinFramePainter(frame.substring(8), context.pal),
      );
    }
    final image = Files.image(frame);
    if (image == null) return ColoredBox(color: context.pal.hint);
    return Image(image: image, fit: BoxFit.cover);
  }
}

/// Lays its child out at [side] of the available width and makes itself
/// tall enough that the child also takes [side] of the height, so the
/// child covers side² of the area, centered.
class _FrameLayout extends SingleChildRenderObjectWidget {
  const _FrameLayout({required this.side, super.child});

  final double side;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFrameLayout(side);

  @override
  void updateRenderObject(BuildContext context, _RenderFrameLayout r) =>
      r.side = side;
}

class _RenderFrameLayout extends RenderShiftedBox {
  _RenderFrameLayout(this._side) : super(null);

  double _side;
  set side(double v) {
    if (v == _side) return;
    _side = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final c = child!;
    c.layout(BoxConstraints.tightFor(width: w * _side), parentUsesSize: true);
    size = constraints.constrain(Size(w, c.size.height / _side));
    (c.parentData! as BoxParentData).offset = Offset(
      (size.width - c.size.width) / 2,
      (size.height - c.size.height) / 2,
    );
  }
}

class _BuiltinFramePainter extends CustomPainter {
  _BuiltinFramePainter(this.id, this.p);

  final String id;
  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final line = Paint()
      ..color = p.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    switch (id) {
      case 'arch':
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.header, p.primary],
            ).createShader(rect),
        );
        LatticePainter(color: p.gold.withValues(alpha: 0.18))
            .paint(canvas, size);
        final inset = size.width * 0.05;
        final top = size.height * 0.05;
        final path = Path()
          ..moveTo(inset, size.height - inset)
          ..lineTo(inset, size.height * 0.32)
          ..quadraticBezierTo(
            inset,
            top + size.height * 0.08,
            size.width / 2,
            top,
          )
          ..quadraticBezierTo(
            size.width - inset,
            top + size.height * 0.08,
            size.width - inset,
            size.height * 0.32,
          )
          ..lineTo(size.width - inset, size.height - inset)
          ..close();
        canvas.drawPath(path, line..strokeWidth = 3);
      case 'lattice':
        canvas.drawRect(rect, Paint()..color = p.hint);
        LatticePainter(color: p.gold.withValues(alpha: 0.45))
            .paint(canvas, size);
        canvas.drawRect(rect.deflate(8), line);
        canvas.drawRect(rect.deflate(14), line..strokeWidth = 1);
      case 'roses':
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(colors: [p.bg, p.hint])
                .createShader(rect),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(10), const Radius.circular(14)),
          line,
        );
        final r = math.min(size.width, size.height) * 0.09;
        for (final c in [
          Offset(r + 6, r + 6),
          Offset(size.width - r - 6, r + 6),
          Offset(r + 6, size.height - r - 6),
          Offset(size.width - r - 6, size.height - r - 6),
        ]) {
          _rosette(canvas, c, r);
        }
      default:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                p.gold.withValues(alpha: 0.55),
                p.hint,
                p.primary.withValues(alpha: 0.45),
              ],
            ).createShader(rect),
        );
        canvas.drawCircle(
          Offset(size.width * 0.78, size.height * 0.2),
          size.width * 0.07,
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
    }
  }

  void _rosette(Canvas canvas, Offset c, double r) {
    final petal = Paint()
      ..color = p.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    for (var i = 0; i < 8; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -r * 0.5),
          width: r * 0.4,
          height: r * 0.8,
        ),
        petal,
      );
      canvas.rotate(math.pi / 4);
    }
    canvas.restore();
    canvas.drawCircle(c, r * 0.2, Paint()..color = p.gold);
  }

  @override
  bool shouldRepaint(_BuiltinFramePainter old) => old.id != id || old.p != p;
}

/// Lets the user choose a frame. Returns `''` for "no frame", null if the
/// sheet was dismissed.
Future<String?> pickFrame(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('خلفية'),
              style: const TextStyle(
                fontFamily: kDisplay,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.8,
              children: [
                _FrameOption(
                  label: tr('صورة من الموبايل'),
                  onTap: () async {
                    final img = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 85,
                    );
                    if (img == null) return;
                    final name = 'frame-${newId()}.jpg';
                    await Files.write('media', name, await img.readAsBytes());
                    if (c.mounted) Navigator.pop(c, name);
                  },
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: context.pal.primary,
                  ),
                ),
                for (final id in builtinFrames)
                  _FrameOption(
                    label: frameName(id),
                    selected: current == 'builtin:$id',
                    onTap: () => Navigator.pop(c, 'builtin:$id'),
                    child: SizedBox.expand(
                      child: FrameBackground(frame: 'builtin:$id'),
                    ),
                  ),
                if (current != null)
                  _FrameOption(
                    label: tr('من غير خلفية'),
                    onTap: () => Navigator.pop(c, ''),
                    child: Icon(
                      Icons.block,
                      size: 32,
                      color: context.pal.muted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _FrameOption extends StatelessWidget {
  const _FrameOption({
    required this.label,
    required this.onTap,
    required this.child,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? p.primary : p.line,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Center(child: child),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Deletes a picture the user added for a frame (built-ins have no file).
Future<void> dropFrameFile(String? frame) async {
  if (frame == null || frame.startsWith('builtin:') || frame.contains(':')) {
    return;
  }
  await Files.delete('media', frame);
}
