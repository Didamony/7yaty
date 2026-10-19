import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/prayer.dart';
import 'widgets.dart';

const _prayerReminderOptions = [0, 5, 10, 15, 20, 30];
const _apptReminderOptions = [0, 10, 30, 60, 120, 1440];

String reminderLabel(int m) => m == 1440
    ? tr('قبلها بيوم')
    : (m == 0 ? tr('في الميعاد') : tr('قبلها {m}', {'m': minutesLabel(m)}));

String dayLabel(DateTime d) {
  final diff = daysBetween(today(), d);
  if (diff == 0) return tr('النهارده');
  if (diff == 1) return tr('بكرة');
  if (diff < 7) return weekdayName(d.weekday);
  return fmtDayMonth(d);
}

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final data = store.data;
    final s = data.settings;
    final p = context.pal;
    final now = DateTime.now();
    final times = PrayerTimes.forDay(now, s.city);
    final (next, _) = PrayerTimes.next(now, s.city);
    final upcoming = [
      for (final a in data.appointments)
        if (a.nextOccurrence(now) case final at?) (a, at),
    ]..sort((x, y) => x.$2.compareTo(y.$2));
    final ended = data.appointments
        .where((a) => a.nextOccurrence(now) == null)
        .toList();

    return Column(
      children: [
        OrnateHeader(title: tr('المواعيد'), subtitle: cityName(s.city)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('مواعيد الصلاة'),
                            style: TextStyle(
                              fontFamily: kDisplay,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: p.goldText,
                            ),
                          ),
                        ),
                        Muted(tr('التنبيه قبلها بـ')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final pr in Prayer.values)
                      _PrayerRow(
                        prayer: pr,
                        time: times[pr]!,
                        isNext: pr == next && sameDay(times[pr]!, now),
                        minutes: s.prayerBefore[pr.name] ?? 10,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('مواعيدي'),
                      style: TextStyle(
                        fontFamily: kDisplay,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: p.goldText,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => openAppointmentEditor(context),
                    icon: const Icon(Icons.add),
                    label: Text(tr('موعد جديد')),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (upcoming.isEmpty)
                EmptyNote(
                  tr('مفيش مواعيد جاية. ضيف موعد زي "بكرة ٧ الصبح الشغل".'),
                ),
              for (final (a, at) in upcoming) ...[
                _AppointmentCard(appointment: a, at: at),
                const SizedBox(height: 8),
              ],
              if (ended.isNotEmpty) ...[
                const SizedBox(height: 10),
                GoldLabel(tr('مواعيد خلصت')),
                const SizedBox(height: 6),
                for (final a in ended)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.title),
                    subtitle: Text(fmtDateShort(parseKey(a.dateKey))),
                    trailing: IconButton(
                      tooltip: tr('امسح'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => store.update(
                        (d) => d.appointments.removeWhere((x) => x.id == a.id),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.isNext,
    required this.minutes,
  });

  final Prayer prayer;
  final DateTime time;
  final bool isNext;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final store = context.read<AppStore>();
    final mins = time.difference(DateTime.now()).inMinutes;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: isNext
          ? BoxDecoration(
              color: p.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.gold),
            )
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  prayerName(prayer),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
                    color: isNext ? p.goldText : p.ink,
                  ),
                ),
                if (isNext) Muted('${tr('القادمة')} · ${inDuration(mins)}'),
              ],
            ),
          ),
          Text(
            fmtTime(time),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<int>(
            tooltip: tr('التنبيه قبل {p}', {'p': prayerName(prayer)}),
            initialValue: minutes,
            onSelected: (v) =>
                store.update((d) => d.settings.prayerBefore[prayer.name] = v),
            itemBuilder: (_) => [
              for (final o in _prayerReminderOptions)
                PopupMenuItem(
                  value: o,
                  child: Text(
                    o == 0 ? tr('من غير تنبيه مسبق') : minutesLabel(o),
                  ),
                ),
            ],
            child: Container(
              constraints: const BoxConstraints(minWidth: 68, minHeight: 36),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isNext ? p.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isNext ? p.gold : p.chip),
              ),
              child: Text(
                minutes == 0 ? tr('لا') : minutesLabel(minutes),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isNext ? const Color(0xFF1F2A2E) : p.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.at});

  final Appointment appointment;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final a = appointment;
    final repeat = switch (a.repeat) {
      Repeat.none => tr('مرة واحدة'),
      Repeat.daily => tr('كل يوم'),
      Repeat.weekdays => a.weekdays.map(weekdayName).join('، '),
    };
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openAppointmentEditor(context, appointment: a),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Muted(dayLabel(at)),
                      Text(
                        fmtTime(at),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(color: p.line, width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Muted(
                        [if (a.place.isNotEmpty) a.place, repeat].join(' · '),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final r in a.reminders)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                reminderLabel(r),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openAppointmentEditor(
  BuildContext context, {
  Appointment? appointment,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => ChangeNotifierProvider.value(
    value: context.read<AppStore>(),
    child: _AppointmentEditor(appointment: appointment),
  ),
);

class _AppointmentEditor extends StatefulWidget {
  const _AppointmentEditor({this.appointment});

  final Appointment? appointment;

  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  late final Appointment _a = widget.appointment == null
      ? Appointment(
          id: newId(),
          title: '',
          dateKey: dkey(addDays(today(), 1)),
          timeMin: 7 * 60,
        )
      : Appointment.fromJson(widget.appointment!.toJson());
  late final _title = TextEditingController(text: _a.title);
  late final _place = TextEditingController(text: _a.place);

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, tr('اكتب اسم الموعد'));
      return;
    }
    _a
      ..title = _title.text.trim()
      ..place = _place.text.trim();
    if (_a.repeat == Repeat.weekdays && _a.weekdays.isEmpty) {
      _a.repeat = Repeat.daily;
    }
    await context.store.update((d) {
      final i = d.appointments.indexWhere((x) => x.id == _a.id);
      i >= 0 ? d.appointments[i] = _a : d.appointments.add(_a);
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final date = parseKey(_a.dateKey);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.appointment == null ? tr('موعد جديد') : tr('تعديل الموعد'),
              style: const TextStyle(
                fontFamily: kDisplay,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.appointment == null,
              decoration: InputDecoration(
                labelText: tr('الموعد'),
                hintText: tr('مثلًا: الذهاب للشغل'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _place,
              decoration: InputDecoration(labelText: tr('المكان (اختياري)')),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: addDays(today(), -30),
                        lastDate: addDays(today(), 3650),
                      );
                      if (d != null) setState(() => _a.dateKey = dkey(d));
                    },
                    icon: const Icon(Icons.event),
                    label: Text(fmtDateShort(date)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final m = await pickMinutesOfDay(context, _a.timeMin);
                    if (m != null) setState(() => _a.timeMin = m);
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(fmtMinutes(_a.timeMin)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GoldLabel(tr('التكرار')),
            const SizedBox(height: 6),
            Pills<Repeat>(
              values: Repeat.values,
              selected: _a.repeat,
              label: (r) => switch (r) {
                Repeat.none => tr('مرة واحدة'),
                Repeat.daily => tr('كل يوم'),
                Repeat.weekdays => tr('أيام محددة'),
              },
              onSelected: (r) => setState(() => _a.repeat = r),
            ),
            if (_a.repeat == Repeat.weekdays) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in const [6, 7, 1, 2, 3, 4, 5])
                    FilterChip(
                      label: Text(weekdayName(w)),
                      selected: _a.weekdays.contains(w),
                      onSelected: (on) => setState(
                        () => on ? _a.weekdays.add(w) : _a.weekdays.remove(w),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            GoldLabel(tr('نبّهني')),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in _apptReminderOptions)
                  FilterChip(
                    label: Text(reminderLabel(r)),
                    selected: _a.reminders.contains(r),
                    onSelected: (on) => setState(
                      () => on ? _a.reminders.add(r) : _a.reminders.remove(r),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(tr('حفظ الموعد'))),
            if (widget.appointment != null) ...[
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.pal.redText,
                ),
                onPressed: () async {
                  await context.store.update(
                    (d) => d.appointments.removeWhere((x) => x.id == _a.id),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(tr('امسح الموعد')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
