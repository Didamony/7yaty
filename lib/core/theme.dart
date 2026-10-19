import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colors of the app. Each [AppTheme] has its own palette, attached to
/// the Material theme as an extension.
class Palette extends ThemeExtension<Palette> {
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

  final Color bg, card, line, ink, muted, primary, onPrimary;

  /// The accent used for ornaments, frames and highlights.
  final Color gold;

  /// The accent dark (or light) enough for text.
  final Color goldText;
  final Color green, greenBg, greenLine, greenText;
  final Color red, redBg, redLine, redText;
  final Color chip, header, hint;

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>() ?? appThemes.first.palette;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      card: l(card, other.card),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      gold: l(gold, other.gold),
      goldText: l(goldText, other.goldText),
      green: l(green, other.green),
      greenBg: l(greenBg, other.greenBg),
      greenLine: l(greenLine, other.greenLine),
      greenText: l(greenText, other.greenText),
      red: l(red, other.red),
      redBg: l(redBg, other.redBg),
      redLine: l(redLine, other.redLine),
      redText: l(redText, other.redText),
      chip: l(chip, other.chip),
      header: l(header, other.header),
      hint: l(hint, other.hint),
    );
  }
}

class AppTheme {
  const AppTheme(this.id, this.name, this.brightness, this.palette);

  final String id;
  final String name;
  final Brightness brightness;
  final Palette palette;

  bool get isDark => brightness == Brightness.dark;

  static AppTheme byId(String id) =>
      appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);

  static AppTheme get darkTheme => byId('dark');

  /// The day theme for [d]: Saturday is the first.
  static AppTheme forDay(DateTime d) =>
      appThemes[(d.weekday - DateTime.saturday) % 7];
}

/// The eight looks of the app: one per day of the week (Saturday first)
/// and the dark "kiswa" theme. Each palette follows its picture.
const appThemes = [
  AppTheme(
    'sat',
    'ربيع النعناع',
    Brightness.light,
    Palette(
      bg: Color(0xFFF3F1EC),
      card: Color(0xFFFFFFFD),
      line: Color(0xFFE1DDD3),
      ink: Color(0xFF26302F),
      muted: Color(0xFF56615F),
      primary: Color(0xFF3B6F6A),
      onPrimary: Color(0xFFFFFFFF),
      gold: Color(0xFFC2707A),
      goldText: Color(0xFF94434F),
      green: Color(0xFF2E7D4F),
      greenBg: Color(0xFFE6F2EA),
      greenLine: Color(0xFFA9D3B6),
      greenText: Color(0xFF1E5634),
      red: Color(0xFFB3261E),
      redBg: Color(0xFFFBEAE8),
      redLine: Color(0xFFE8B4AE),
      redText: Color(0xFF9E2A22),
      chip: Color(0xFFC9BFB6),
      header: Color(0xFF45736E),
      hint: Color(0xFFF1E6E3),
    ),
  ),
  AppTheme(
    'sun',
    'غروب الخوخ',
    Brightness.light,
    Palette(
      bg: Color(0xFFFBF1EA),
      card: Color(0xFFFFFCFA),
      line: Color(0xFFEBD9CC),
      ink: Color(0xFF2B2622),
      muted: Color(0xFF665850),
      primary: Color(0xFF2F6B4F),
      onPrimary: Color(0xFFFFFFFF),
      gold: Color(0xFFD9826F),
      goldText: Color(0xFF9A4636),
      green: Color(0xFF2E7D4F),
      greenBg: Color(0xFFE6F2EA),
      greenLine: Color(0xFFA9D3B6),
      greenText: Color(0xFF1E5634),
      red: Color(0xFFB3261E),
      redBg: Color(0xFFFBEAE8),
      redLine: Color(0xFFE8B4AE),
      redText: Color(0xFF9E2A22),
      chip: Color(0xFFD9C2B3),
      header: Color(0xFF2F6B4F),
      hint: Color(0xFFF7E3D8),
    ),
  ),
  AppTheme(
    'mon',
    'ورد المدينة',
    Brightness.light,
    Palette(
      bg: Color(0xFFF8EFF0),
      card: Color(0xFFFFFCFC),
      line: Color(0xFFEAD7DA),
      ink: Color(0xFF2A2326),
      muted: Color(0xFF65565B),
      primary: Color(0xFF2E6E4E),
      onPrimary: Color(0xFFFFFFFF),
      gold: Color(0xFFC45C7C),
      goldText: Color(0xFF953A58),
      green: Color(0xFF2E7D4F),
      greenBg: Color(0xFFE6F2EA),
      greenLine: Color(0xFFA9D3B6),
      greenText: Color(0xFF1E5634),
      red: Color(0xFFB3261E),
      redBg: Color(0xFFFBEAE8),
      redLine: Color(0xFFE8B4AE),
      redText: Color(0xFF9E2A22),
      chip: Color(0xFFD8BEC3),
      header: Color(0xFF24563F),
      hint: Color(0xFFF4E1E5),
    ),
  ),
  AppTheme(
    'tue',
    'سماء الحديقة',
    Brightness.light,
    Palette(
      bg: Color(0xFFF2F6FA),
      card: Color(0xFFFFFFFF),
      line: Color(0xFFDCE5EE),
      ink: Color(0xFF22303D),
      muted: Color(0xFF566472),
      primary: Color(0xFF3F6D93),
      onPrimary: Color(0xFFFFFFFF),
      gold: Color(0xFFC97B95),
      goldText: Color(0xFF934563),
      green: Color(0xFF2E7D4F),
      greenBg: Color(0xFFE6F2EA),
      greenLine: Color(0xFFA9D3B6),
      greenText: Color(0xFF1E5634),
      red: Color(0xFFB3261E),
      redBg: Color(0xFFFBEAE8),
      redLine: Color(0xFFE8B4AE),
      redText: Color(0xFF9E2A22),
      chip: Color(0xFFC3CFDB),
      header: Color(0xFF3F6A8F),
      hint: Color(0xFFE8EEF5),
    ),
  ),
  AppTheme(
    'wed',
    'ليالي الشرفة',
    Brightness.light,
    Palette(
      bg: Color(0xFFF3EEE4),
      card: Color(0xFFFFFDF8),
      line: Color(0xFFE2D9C8),
      ink: Color(0xFF1E2433),
      muted: Color(0xFF575C6B),
      primary: Color(0xFF1F3A66),
      onPrimary: Color(0xFFFFFFFF),
      gold: Color(0xFFC9963B),
      goldText: Color(0xFF805A1C),
      green: Color(0xFF2E7D4F),
      greenBg: Color(0xFFE6F2EA),
      greenLine: Color(0xFFA9D3B6),
      greenText: Color(0xFF1E5634),
      red: Color(0xFFB3261E),
      redBg: Color(0xFFFBEAE8),
      redLine: Color(0xFFE8B4AE),
      redText: Color(0xFF9E2A22),
      chip: Color(0xFFCDBFA5),
      header: Color(0xFF1C2A4A),
      hint: Color(0xFFEFE6D2),
    ),
  ),
  AppTheme(
    'thu',
    'فيروز وسحاب',
    Brightness.light,
    Palette(
      bg: Color(0xFFF6F0EA),
      card: Color(0xFFFFFDFB),
      line: Color(0xFFE7DACF),
      ink: Color(0xFF22302E),
      muted: Color(0xFF566260),
      primary: Color(0xFF2A746D),
      onPrimary: Color(0xFFFFFFFF),
      gold: Color(0xFFE09A7A),
      goldText: Color(0xFF9A5534),
      green: Color(0xFF2E7D4F),
      greenBg: Color(0xFFE6F2EA),
      greenLine: Color(0xFFA9D3B6),
      greenText: Color(0xFF1E5634),
      red: Color(0xFFB3261E),
      redBg: Color(0xFFFBEAE8),
      redLine: Color(0xFFE8B4AE),
      redText: Color(0xFF9E2A22),
      chip: Color(0xFFD3C3B6),
      header: Color(0xFF2A746D),
      hint: Color(0xFFF5E5DA),
    ),
  ),
  AppTheme(
    'fri',
    'فجر الجمعة',
    Brightness.light,
    Palette(
      bg: Color(0xFFF6F2F9),
      card: Color(0xFFFFFFFF),
      line: Color(0xFFE4DCEC),
      ink: Color(0xFF2A2633),
      muted: Color(0xFF5E5869),
      primary: Color(0xFF5F5196),
      onPrimary: Color(0xFFFFFFFF),
      gold: Color(0xFFD98FB0),
      goldText: Color(0xFF97466C),
      green: Color(0xFF2E7D4F),
      greenBg: Color(0xFFE6F2EA),
      greenLine: Color(0xFFA9D3B6),
      greenText: Color(0xFF1E5634),
      red: Color(0xFFB3261E),
      redBg: Color(0xFFFBEAE8),
      redLine: Color(0xFFE8B4AE),
      redText: Color(0xFF9E2A22),
      chip: Color(0xFFCDC2DC),
      header: Color(0xFF665796),
      hint: Color(0xFFEEE6F5),
    ),
  ),
  AppTheme(
    'dark',
    'الكسوة',
    Brightness.dark,
    Palette(
      bg: Color(0xFF0C0C0D),
      card: Color(0xFF17171A),
      line: Color(0xFF2C2A24),
      ink: Color(0xFFEDE3C8),
      muted: Color(0xFFA79F8B),
      primary: Color(0xFFD4AF37),
      onPrimary: Color(0xFF141210),
      gold: Color(0xFFD4AF37),
      goldText: Color(0xFFE2C066),
      green: Color(0xFF4CAF7A),
      greenBg: Color(0xFF17322A),
      greenLine: Color(0xFF2E5A45),
      greenText: Color(0xFF9FD9B6),
      red: Color(0xFFE06A5F),
      redBg: Color(0xFF3A1D1C),
      redLine: Color(0xFF6B302C),
      redText: Color(0xFFF2A49C),
      chip: Color(0xFF4A4334),
      header: Color(0xFF111112),
      hint: Color(0xFF1E1C17),
    ),
  ),
];

const kBody = 'Plex';
const kDisplay = 'Kufi';

ThemeData buildTheme(AppTheme t) {
  final p = t.palette;
  final brightness = t.brightness;
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
    extensions: [p],
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
