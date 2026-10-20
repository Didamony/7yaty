import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/cloud.dart';
import 'admin_page.dart';
import 'auth_page.dart';
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
                  const _ThemePicker(),
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

/// The eight themes: automatic by weekday or a fixed pick, each with an
/// optional picture from the phone.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  Future<void> _pickImage(BuildContext context, AppTheme t) async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (img == null || !context.mounted) return;
    final store = context.store;
    final old = store.settings.themeImages[t.id];
    final name = 'theme-${t.id}-${newId()}.jpg';
    await Files.write('media', name, await img.readAsBytes());
    if (old != null && !old.contains(':')) await Files.delete('media', old);
    await store.update((d) => d.settings.themeImages[t.id] = name);
  }

  Future<void> _menu(BuildContext context, AppTheme t) async {
    final store = context.store;
    final hasImage = store.settings.themeImages[t.id] != null;
    await showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(t.name),
              style: const TextStyle(
                fontFamily: kDisplay,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(tr('استخدم الشكل ده على طول')),
              onTap: () {
                store.update((d) {
                  d.settings.themeChoice = t.id;
                  if (!t.isDark && d.settings.theme == 'dark') {
                    d.settings.theme = 'light';
                  }
                });
                Navigator.pop(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(
                hasImage ? tr('غيّر الصورة') : tr('اختار صورة للشكل ده'),
              ),
              onTap: () {
                Navigator.pop(c);
                _pickImage(context, t);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: Text(tr('شيل الصورة')),
                onTap: () async {
                  final old = store.settings.themeImages[t.id]!;
                  Navigator.pop(c);
                  if (!old.contains(':')) await Files.delete('media', old);
                  await store.update(
                    (d) => d.settings.themeImages.remove(t.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final p = context.pal;
    final today = AppTheme.forDay(DateTime.now());
    const days = [
      'السبت',
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('شكل التطبيق'), style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: s.themeChoice == 'auto',
          onChanged: (v) => store.update(
            (d) => d.settings.themeChoice = v ? 'auto' : today.id,
          ),
          title: Text(tr('شكل مختلف لكل يوم')),
          subtitle: Muted(tr('وفي الوضع الداكن بيبقى شكل الكسوة')),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 0.52,
          children: [
            for (final (i, t) in appThemes.indexed)
              _ThemeThumb(
                theme: t,
                label: i < 7 ? tr(days[i]) : tr('الداكن'),
                image: Files.image(s.themeImages[t.id]),
                selected: s.themeChoice == 'auto'
                    ? (t.isDark ? false : t.id == today.id)
                    : s.themeChoice == t.id,
                onTap: () => _menu(context, t),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Muted(tr('اضغط على أي شكل عشان تختاره أو تحط له صورة من الموبايل.')),
        const SizedBox(height: 8),
        Text(tr('وضوح الصورة'), style: TextStyle(fontSize: 13, color: p.ink)),
        Slider(
          value: s.bgOpacity.clamp(0.1, 1),
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
    );
  }
}

class _ThemeThumb extends StatelessWidget {
  const _ThemeThumb({
    required this.theme,
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final AppTheme theme;
  final String label;
  final ImageProvider? image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme.palette;
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label · ${tr(theme.name)}',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? p.primary : p.line,
                    width: selected ? 3 : 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.bg, t.hint],
                  ),
                  image: image == null
                      ? null
                      : DecorationImage(image: image!, fit: BoxFit.cover),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: t.header,
                        border: Border(
                          bottom: BorderSide(color: t.gold, width: 2),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final c in [t.primary, t.gold, t.card])
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  static String _when(DateTime t) => '${fmtTime(t)} · ${fmtDayMonth(t)}';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final cloud = context.watch<Cloud>();
    final p = context.pal;
    final email = cloud.user?.email;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        border: p.gold.withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GoldLabel(tr('الحساب والحفظ')),
            const SizedBox(height: 8),
            if (email == null)
              Muted(tr('الحساب والحفظ لسه مش متظبطين في النسخة دي.'), size: 13)
            else ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: p.primary,
                    child: Text(
                      email.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: p.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Muted(
                          cloud.busy
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
              const SizedBox(height: 6),
              Muted(
                tr(
                  'كل حاجة بتتحفظ في حسابك لوحدها. لو مسحت التطبيق، ادخل بنفس الإيميل والباسورد وكل حاجة ترجع.',
                ),
                size: 12,
              ),
              if (cloud.error != null) ...[
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
                      onPressed: cloud.busy
                          ? null
                          : () async {
                              final ok = await cloud.backup(store.data);
                              if (context.mounted) {
                                toast(
                                  context,
                                  ok ? tr('اتحفظ') : tr('الحفظ ما نجحش'),
                                );
                              }
                            },
                      child: Text(tr('احفظ دلوقتي')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await cloud.resetPassword(email);
                          if (context.mounted) {
                            toast(
                              context,
                              tr('بعتنالك على إيميلك لينك تغيّر بيه الباسورد'),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) toast(context, authMessage(e));
                        }
                      },
                      child: Text(tr('غيّر الباسورد')),
                    ),
                  ),
                ],
              ),
              if (cloud.isAdmin)
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPage()),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(tr('لوحة التفعيل')),
                ),
              TextButton(
                onPressed: () async {
                  if (await confirm(
                        context,
                        tr(
                          'تخرج من حسابك؟ بياناتك محفوظة فيه وترجع لما تدخل تاني.',
                        ),
                        ok: tr('خروج'),
                      ) &&
                      context.mounted) {
                    await cloud.signOut(store.data);
                  }
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
