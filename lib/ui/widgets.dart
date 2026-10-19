import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/store.dart';

extension StoreX on BuildContext {
  AppStore get store => read<AppStore>();
  Palette get pal => Palette.of(this);
}

/// The teal header with the khatam lattice and a gold rule underneath.
class OrnateHeader extends StatelessWidget {
  const OrnateHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: p.header,
        border: Border(bottom: BorderSide(color: p.gold, width: 3)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: KhatamPainter(
                color: const Color(0xFFD4B26A).withValues(alpha: 0.3),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: kDisplay,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF6F1E7),
                                height: 1.2,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xE6F6F1E7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  if (bottom != null) ...[const SizedBox(height: 14), bottom!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 8),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFFF6F1E7), size: 22),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: Colors.black.withValues(alpha: 0.15),
        side: const BorderSide(color: Color(0x66F6F1E7)),
      ),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? p.line),
      ),
      child: child,
    );
  }
}

class GoldLabel extends StatelessWidget {
  const GoldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: context.pal.goldText,
    ),
  );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 12, this.color});

  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: size, color: color ?? context.pal.muted),
  );
}

class HintBox extends StatelessWidget {
  const HintBox(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: context.pal.hint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, height: 1.6, color: context.pal.muted),
    ),
  );
}

class StarDivider extends StatelessWidget {
  const StarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: context.pal.gold.withValues(alpha: 0.4),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          line,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: StarMark(size: 16),
          ),
          line,
        ],
      ),
    );
  }
}

class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.label});

  final double value;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${(value * 100).round()}%',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        backgroundColor: context.pal.line,
        color: Theme.of(context).brightness == Brightness.dark
            ? context.pal.primary
            : const Color(0xFF0F5257),
      ),
    ),
  );
}

/// Single-choice pill row.
class Pills<T> extends StatelessWidget {
  const Pills({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onSelected(v),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontFamily: kBody,
              fontSize: 13,
              fontWeight: v == selected ? FontWeight.w600 : FontWeight.w400,
              color: v == selected ? p.onPrimary : p.ink,
            ),
            selectedColor: p.primary,
            backgroundColor: Colors.transparent,
            side: BorderSide(color: v == selected ? p.primary : p.chip),
            shape: const StadiumBorder(),
          ),
      ],
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        const StarMark(size: 36),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pal.muted, fontSize: 14),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String message, {String? ok}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(tr('إلغاء')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok ?? tr('تأكيد')),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

Future<int?> pickMinutesOfDay(BuildContext context, int current) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}
