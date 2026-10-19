import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/drive_sync.dart';
import '../services/files.dart';
import '../services/notifications.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final p = context.pal;

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [GoldLabel(title), const SizedBox(height: 8), ...children],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          OrnateHeader(
            title: tr('الإعدادات'),
            leading: const BackButton(color: Color(0xFFF6F1E7)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _AccountSection(),
                section(tr('المظهر'), [
                  Pills<String>(
                    values: const ['light', 'dark', 'system'],
                    selected: s.theme,
                    label: (v) => switch (v) {
                      'light' => tr('فاتح'),
                      'dark' => tr('داكن'),
                      _ => tr('حسب الجهاز'),
                    },
                    onSelected: (v) =>
                        store.update((d) => d.settings.theme = v),
                  ),
                  const SizedBox(height: 12),
                  const _BackgroundPicker(),
                ]),
                section(tr('اللغة'), [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 3.6,
                    children: [
                      for (final l in L10n.supported)
                        l == s.lang
                            ? FilledButton(
                                onPressed: () {},
                                child: Text(L10n.names[l]!),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: p.ink,
                                  side: BorderSide(color: p.chip),
                                ),
                                onPressed: () =>
                                    store.update((d) => d.settings.lang = l),
                                child: Text(L10n.names[l]!),
                              ),
                    ],
                  ),
                ]),
                section(tr('التنبيهات'), [
                  _Row(
                    title: tr('مراجعة الأهداف اليومية'),
                    subtitle: tr(
                      'إشعار لكل هدف فيه أزرار: تم، ما اتعملش، رحّله',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final m = await pickMinutesOfDay(context, s.reviewMin);
                        if (m != null) {
                          store.update((d) => d.settings.reviewMin = m);
                        }
                      },
                      child: Text(fmtMinutes(s.reviewMin)),
                    ),
                  ),
                  Divider(color: p.line),
                  Text(
                    tr('التنبيه قبل كل الصلوات'),
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Pills<int>(
                    values: const [0, 5, 10, 15, 30],
                    selected: s.prayerBefore.values.toSet().length == 1
                        ? s.prayerBefore.values.first
                        : null,
                    label: (v) => v == 0 ? tr('لا') : minutesLabel(v),
                    onSelected: (v) => store.update((d) {
                      for (final pr in Prayer.values) {
                        d.settings.prayerBefore[pr.name] = v;
                      }
                    }),
                  ),
                  const SizedBox(height: 4),
                  Muted(tr('تقدر تغيّر كل صلاة لوحدها من شاشة المواعيد.')),
                  Divider(color: p.line),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.adhanAtTime,
                    onChanged: (v) =>
                        store.update((d) => d.settings.adhanAtTime = v),
                    title: Text(tr('تنبيه عند دخول الوقت')),
                    subtitle: Muted(tr('بالإضافة للتنبيه المسبق')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: store.data.worship.adhkarReminders,
                    onChanged: (v) =>
                        store.update((d) => d.worship.adhkarReminders = v),
                    title: Text(tr('تذكير بأذكار الصباح والمساء')),
                    subtitle: Muted(tr('بعد الفجر وبعد العصر بنص ساعة')),
                  ),
                  if (!Notifier.instance.supported)
                    HintBox(
                      tr(
                        'نسخة الويب مفيهاش تنبيهات في المواعيد، لأن الآيفون مش بيسمح بيها للمواقع. افتح التطبيق وراجع أهدافك ومواعيدك، والتنبيهات كاملة في تطبيق أندرويد.',
                      ),
                    ),
                  if (Notifier.instance.supported)
                    TextButton.icon(
                      onPressed: () => Notifier.instance.requestPermissions(),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(tr('اسمح بالإشعارات')),
                    ),
                ]),
                section(tr('مواقيت الصلاة'), [
                  DropdownButtonFormField<int>(
                    initialValue: s.city,
                    decoration: InputDecoration(labelText: tr('المدينة')),
                    items: [
                      for (var i = 0; i < cities.length; i++)
                        DropdownMenuItem(value: i, child: Text(cityName(i))),
                    ],
                    onChanged: (v) =>
                        store.update((d) => d.settings.city = v ?? 0),
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    title: tr('طريقة الحساب'),
                    trailing: Muted(
                      tr('الهيئة المصرية العامة للمساحة'),
                      size: 13,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15)),
              if (subtitle != null) Muted(subtitle!),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker();

  Future<void> _pick(BuildContext context) async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (img == null || !context.mounted) return;
    final store = context.store;
    final old = store.settings.bgImage;
    final name = '${newId()}.jpg';
    await Files.write('media', name, await img.readAsBytes());
    if (old != null && !old.startsWith('data:')) {
      await Files.delete('media', old);
    }
    await store.update((d) => d.settings.bgImage = name);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final image = Files.image(s.bgImage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('صورة الخلفية'), style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 64,
              height: 96,
              decoration: BoxDecoration(
                color: context.pal.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.pal.chip),
                image: image == null
                    ? null
                    : DecorationImage(image: image, fit: BoxFit.cover),
              ),
              child: image == null
                  ? const Center(child: StarMark(size: 24))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pick(context),
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(tr('اختار صورة من الموبايل')),
                  ),
                  if (s.bgImage != null)
                    TextButton(
                      onPressed: () async {
                        final old = s.bgImage!;
                        if (!old.startsWith('data:')) {
                          await Files.delete('media', old);
                        }
                        await store.update((d) => d.settings.bgImage = null);
                      },
                      child: Text(tr('شيل الصورة')),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (s.bgImage != null) ...[
          const SizedBox(height: 8),
          Text(tr('وضوح الصورة'), style: const TextStyle(fontSize: 13)),
          Slider(
            value: s.bgOpacity,
            min: 0.1,
            max: 1,
            label: pct(s.bgOpacity),
            onChanged: (v) {
              s.bgOpacity = v;
              store.touch();
            },
            onChangeEnd: (v) => store.update((d) => d.settings.bgOpacity = v),
          ),
        ],
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  static String _when(DateTime t) => '${fmtTime(t)} · ${fmtDayMonth(t)}';

  Future<void> _signIn(BuildContext context) async {
    final store = context.store;
    final sync = DriveSync.instance;
    try {
      final email = await sync.signIn();
      await store.update((d) => d.settings.googleEmail = email);
      final remoteAt = await sync.remoteUpdatedAt();
      if (!context.mounted) return;
      if (remoteAt == null) {
        await sync.backup(store.data);
      } else if (store.data.isEmpty) {
        await _restore(context);
      } else {
        final restore = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr('لقيت نسخة على درايف')),
            content: Text(
              tr(
                'في نسخة محفوظة من {d}. تحب ترجّعها على الموبايل، ولا ترفع اللي على الموبايل مكانها؟',
                {
                  'd': fmtDateLong(
                    DateTime.fromMillisecondsSinceEpoch(remoteAt),
                  ),
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('ارفع اللي هنا')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr('رجّع نسخة درايف')),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        if (restore == true) {
          await _restore(context);
        } else if (restore == false) {
          await sync.backup(store.data);
        }
      }
    } catch (e) {
      if (context.mounted) {
        toast(context, tr('ما قدرتش أسجّل الدخول بجوجل. جرّب تاني.'));
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    final store = context.store;
    final email = store.settings.googleEmail;
    final data = await DriveSync.instance.restore(prompt: true);
    if (!context.mounted) return;
    if (data == null) {
      toast(context, tr('مفيش نسخة على درايف لسه'));
      return;
    }
    data.settings.googleEmail = email;
    await store.replaceAll(data);
    if (context.mounted) toast(context, tr('رجعت كل حاجة من درايف'));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final sync = context.watch<DriveSync>();
    final p = context.pal;
    final signedIn = s.googleEmail != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        border: p.gold.withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GoldLabel(tr('الحساب والحفظ على جوجل درايف')),
            const SizedBox(height: 8),
            if (!sync.supported) ...[
              Muted(
                tr('تسجيل الدخول بجوجل لسه مش متظبط في النسخة دي.'),
                size: 13,
              ),
            ] else if (!signedIn) ...[
              Muted(
                tr(
                  'سجّل دخول بحساب جوجل، وكل حاجة (أهداف، يوميات، ريكوردات، كتب) هتتحفظ على درايف بتاعك. لو التطبيق اتمسح، تسجّل دخول تاني وكل حاجة ترجع.',
                ),
                size: 13,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: sync.busy ? null : () => _signIn(context),
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(tr('تسجيل الدخول بجوجل')),
              ),
            ] else ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: p.primary,
                    child: Text(
                      s.googleEmail!.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: p.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.googleEmail!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Muted(
                          sync.busy
                              ? tr('بيحفظ دلوقتي…')
                              : s.lastSync == null
                              ? tr('لسه ما اتحفظش')
                              : tr('آخر حفظ: {d}', {
                                  'd': _when(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      s.lastSync!,
                                    ),
                                  ),
                                }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (sync.error != null) ...[
                const SizedBox(height: 6),
                Muted(
                  tr('آخر محاولة حفظ ما نجحتش، هيحاول تاني لوحده.'),
                  color: p.redText,
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.syncBooks,
                onChanged: (v) => store.update((d) => d.settings.syncBooks = v),
                title: Text(tr('احفظ ملفات الكتب كمان')),
                subtitle: Muted(tr('لو قفلتها، بيتحفظ مكانك في الكتاب بس')),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: sync.busy
                          ? null
                          : () async {
                              final ok = await DriveSync.instance.backup(
                                store.data,
                                prompt: true,
                              );
                              if (context.mounted) {
                                toast(
                                  context,
                                  ok
                                      ? tr('اتحفظ على درايف')
                                      : tr('الحفظ ما نجحش'),
                                );
                              }
                            },
                      child: Text(tr('احفظ دلوقتي')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: sync.busy
                          ? null
                          : () async {
                              if (await confirm(
                                    context,
                                    tr(
                                      'ده هيبدّل اللي على الموبايل بالنسخة اللي على درايف. متأكد؟',
                                    ),
                                    ok: tr('رجّع'),
                                  ) &&
                                  context.mounted) {
                                await _restore(context);
                              }
                            },
                      child: Text(tr('رجّع من درايف')),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await DriveSync.instance.signOut();
                  await store.update((d) => d.settings.googleEmail = null);
                },
                child: Text(tr('تسجيل الخروج')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
