import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colors of the app, taken from the approved design.
class Palette {
  const Palette({
    required this.bg,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.gold,
    required this.goldText,
    required this.green,
    required this.greenBg,
    required this.greenLine,
    required this.greenText,
    required this.red,
    required this.redBg,
    required this.redLine,
    required this.redText,
    required this.chip,
    required this.header,
    required this.hint,
  });

  final Color bg, card, line, ink, muted, primary, onPrimary, gold, goldText;
  final Color green, greenBg, greenLine, greenText;
  final Color red, redBg, redLine, redText;
  final Color chip, header, hint;

  static const light = Palette(
    bg: Color(0xFFF6F1E7),
    card: Color(0xFFFFFDF8),
    line: Color(0xFFE4DCCB),
    ink: Color(0xFF1F2A2E),
    muted: Color(0xFF5A6466),
    primary: Color(0xFF0F5257),
    onPrimary: Color(0xFFF6F1E7),
    gold: Color(0xFFB08D3C),
    goldText: Color(0xFF8A6A1F),
    green: Color(0xFF2E7D4F),
    greenBg: Color(0xFFE6F2EA),
    greenLine: Color(0xFFA9D3B6),
    greenText: Color(0xFF1E5634),
    red: Color(0xFFB3261E),
    redBg: Color(0xFFFBEAE8),
    redLine: Color(0xFFE8B4AE),
    redText: Color(0xFF9E2A22),
    chip: Color(0xFFC9BFA9),
    header: Color(0xFF0F5257),
    hint: Color(0xFFF3EBDA),
  );

  static const dark = Palette(
    bg: Color(0xFF0E1A1C),
    card: Color(0xFF16282B),
    line: Color(0xFF2A4044),
    ink: Color(0xFFEDE6D6),
    muted: Color(0xFFA9B4B0),
    primary: Color(0xFFD4B26A),
    onPrimary: Color(0xFF0E1A1C),
    gold: Color(0xFFD4B26A),
    goldText: Color(0xFFD4B26A),
    green: Color(0xFF4CAF7A),
    greenBg: Color(0xFF17322A),
    greenLine: Color(0xFF2E5A45),
    greenText: Color(0xFF9FD9B6),
    red: Color(0xFFE06A5F),
    redBg: Color(0xFF3A1D1C),
    redLine: Color(0xFF6B302C),
    redText: Color(0xFFF2A49C),
    chip: Color(0xFF3A5458),
    header: Color(0xFF12282B),
    hint: Color(0xFF1D3236),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

const kBody = 'Plex';
const kDisplay = 'Kufi';

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    surface: p.card,
    onSurface: p.ink,
    error: p.red,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kBody,
    scaffoldBackgroundColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    dividerColor: p.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.chip),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.chip),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: kBody,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: p.primary),
        textStyle: const TextStyle(
          fontFamily: kBody,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: const TextStyle(
          fontFamily: kBody,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bg,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.bg),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: kBody, color: p.bg),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onPrimary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : null,
      ),
    ),
  );
}

/// The mashrabiya lattice drawn behind headers: diamonds with a ring at
/// each crossing, like a carved wooden screen.
class LatticePainter extends CustomPainter {
  const LatticePainter({required this.color, this.cell = 36});

  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final h = cell / 2;
    for (double y = 0; y < size.height + cell; y += cell) {
      for (double x = 0; x < size.width + cell; x += cell) {
        final c = Offset(x + h, y + h);
        canvas.drawPath(
          Path()
            ..moveTo(x, y + h)
            ..lineTo(x + h, y)
            ..lineTo(x + cell, y + h)
            ..lineTo(x + h, y + cell)
            ..close(),
          paint,
        );
        canvas.drawCircle(c, cell * 4 / 36, paint);
        canvas.drawCircle(Offset(x, y), cell * 3 / 36, paint);
        final t = cell * 10 / 36, u = cell * 6 / 36;
        canvas
          ..drawLine(c.translate(0, -t), c.translate(0, -u), paint)
          ..drawLine(c.translate(0, t), c.translate(0, u), paint)
          ..drawLine(c.translate(-t, 0), c.translate(-u, 0), paint)
          ..drawLine(c.translate(t, 0), c.translate(u, 0), paint);
      }
    }
  }

  @override
  bool shouldRepaint(LatticePainter old) => old.color != color;
}

/// A floral rosette (shamsa) of eight round petals, used as an ornament.
class Rosette extends StatelessWidget {
  const Rosette({super.key, this.size = 16, this.color, this.filled = false});

  final double size;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _RosettePainter(color ?? Palette.of(context).gold, filled),
    ),
  );
}

class _RosettePainter extends CustomPainter {
  _RosettePainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s / 18;
    final fill = Paint()..color = color.withValues(alpha: filled ? 0.35 : 0);
    canvas.save();
    canvas.translate(s / 2, s / 2);
    for (var i = 0; i < 8; i++) {
      final petal = Rect.fromCenter(
        center: Offset(0, -s * 0.25),
        width: s * 0.2,
        height: s * 0.4,
      );
      if (filled) canvas.drawOval(petal, fill);
      canvas.drawOval(petal, stroke);
      canvas.rotate(math.pi / 4);
    }
    canvas.restore();
    canvas.drawCircle(
      size.center(Offset.zero),
      s * 0.1,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.color != color || old.filled != filled;
}
