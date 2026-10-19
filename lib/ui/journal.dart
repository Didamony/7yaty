import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/files.dart';
import 'widgets.dart';

const _speechLocales = {
  'ar': 'ar_EG',
  'en': 'en_US',
  'fr': 'fr_FR',
  'de': 'de_DE',
};

String _clock(int ms) {
  final s = ms ~/ 1000;
  return n('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}');
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  DateTime _day = today();
  late final AppStore _store;
  final _text = TextEditingController();
  Timer? _saveTimer;

  final _speech = SpeechToText();
  bool _listening = false;
  String _beforeDictation = '';

  final _recorder = AudioRecorder();
  String? _recFile;
  DateTime? _recStart;
  Timer? _recTick;

  final _player = AudioPlayer();
  String? _playing;

  @override
  void initState() {
    super.initState();
    _store = context.store;
    _loadDay();
    _player.onPlayerComplete.listen((_) => setState(() => _playing = null));
  }

  @override
  void dispose() {
    _flush();
    _text.dispose();
    _recTick?.cancel();
    _recorder.dispose();
    _player.dispose();
    _speech.stop();
    super.dispose();
  }

  void _loadDay() {
    _text.text = _store.data.journal[dkey(_day)]?.text ?? '';
  }

  void _goTo(DateTime d) {
    _flush();
    setState(() => _day = d);
    _loadDay();
  }

  void _onTextChanged(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    final key = dkey(_day);
    final text = _text.text;
    if ((_store.data.journal[key]?.text ?? '') == text) return;
    _store.update((d) {
      final e = d.journal.putIfAbsent(key, JournalEntry.new)..text = text;
      if (e.isEmpty) d.journal.remove(key);
    });
  }

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      _flush();
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
          _flush();
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) {
      if (mounted) {
        toast(
          context,
          tr(
            'الكتابة بالصوت مش متاحة. اتأكد إن خدمة التعرف على الكلام من جوجل شغالة على موبايلك.',
          ),
        );
      }
      return;
    }
    _beforeDictation = _text.text.trim();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        final joined = [
          _beforeDictation,
          r.recognizedWords,
        ].where((s) => s.isNotEmpty).join(' ');
        _text.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
        if (r.finalResult) _flush();
      },
      listenOptions: SpeechListenOptions(
        localeId: _speechLocales[L10n.lang],
        partialResults: true,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (!Files.supported) {
      toast(context, tr('التسجيل متاح في تطبيق الموبايل'));
      return;
    }
    if (_recFile != null) {
      await _recorder.stop();
      _recTick?.cancel();
      final ms = DateTime.now().difference(_recStart!).inMilliseconds;
      final file = _recFile!;
      setState(() => _recFile = null);
      await _store.update(
        (d) => d.journal
            .putIfAbsent(dkey(_day), JournalEntry.new)
            .recordings
            .add(
              Recording(
                file: file,
                ms: ms,
                at: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
      );
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) toast(context, tr('محتاج إذن الميكروفون عشان أسجّل'));
      return;
    }
    final file = '${newId()}.m4a';
    await Files.ensure('recordings');
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: Files.path('recordings', file),
    );
    setState(() {
      _recFile = file;
      _recStart = DateTime.now();
    });
    _recTick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  Future<void> _play(Recording r) async {
    if (_playing == r.file) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(Files.path('recordings', r.file)));
    setState(() => _playing = r.file);
  }

  Future<void> _deleteRecording(Recording r) async {
    if (!await confirm(context, tr('تمسح الريكورد ده؟'), ok: tr('امسحه'))) {
      return;
    }
    await Files.delete('recordings', r.file);
    if (!mounted) return;
    await context.store.update((d) {
      final e = d.journal[dkey(_day)];
      e?.recordings.removeWhere((x) => x.file == r.file);
      if (e != null && e.isEmpty) d.journal.remove(dkey(_day));
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppStore>().data;
    final p = context.pal;
    final entry = data.journal[dkey(_day)];
    final recording = _recFile != null;
    final past =
        data.journal.entries
            .where((e) => e.key != dkey(_day) && !e.value.isEmpty)
            .toList()
          ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      children: [
        OrnateHeader(
          title: tr('يومياتي'),
          bottom: Row(
            children: [
              IconButton(
                tooltip: tr('اليوم السابق'),
                onPressed: () => _goTo(addDays(_day, -1)),
                icon: const Icon(Icons.chevron_left, color: Color(0xFFF6F1E7)),
              ),
              Expanded(
                child: Text(
                  fmtDateShort(_day),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF6F1E7),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('اليوم التالي'),
                onPressed: sameDay(_day, today())
                    ? null
                    : () => _goTo(addDays(_day, 1)),
                icon: Icon(
                  Icons.chevron_right,
                  color: sameDay(_day, today())
                      ? const Color(0x55F6F1E7)
                      : const Color(0xFFF6F1E7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GoldLabel(tr('مكتوب')),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _text,
                      onChanged: _onTextChanged,
                      onTapOutside: (_) => _flush(),
                      minLines: 5,
                      maxLines: null,
                      style: const TextStyle(fontSize: 15, height: 1.8),
                      decoration: InputDecoration(
                        hintText: tr('اكتب يومك هنا…'),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_listening) ...[
                      const SizedBox(height: 6),
                      HintBox(tr('بسمعك… اتكلم وأنا هكتب')),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleDictation,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                      ),
                      icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                      label: Text(_listening ? tr('وقّف') : tr('اكتب بصوتك')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleRecording,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        foregroundColor: recording ? p.red : null,
                        side: BorderSide(
                          color: recording
                              ? p.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      icon: Icon(
                        recording
                            ? Icons.stop_circle_outlined
                            : Icons.fiber_manual_record,
                        color: p.red,
                      ),
                      label: Text(
                        recording
                            ? tr('وقّف · {t}', {
                                't': _clock(
                                  DateTime.now()
                                      .difference(_recStart!)
                                      .inMilliseconds,
                                ),
                              })
                            : tr('سجّل ريكورد'),
                      ),
                    ),
                  ),
                ],
              ),
              if (entry != null && entry.recordings.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GoldLabel(tr('ريكوردات اليوم')),
                      for (final r in entry.recordings)
                        Row(
                          children: [
                            IconButton.filled(
                              tooltip: _playing == r.file
                                  ? tr('إيقاف')
                                  : tr('تشغيل'),
                              onPressed: () => _play(r),
                              icon: Icon(
                                _playing == r.file
                                    ? Icons.stop
                                    : Icons.play_arrow,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fmtTime(
                                      DateTime.fromMillisecondsSinceEpoch(r.at),
                                    ),
                                  ),
                                  Muted(_clock(r.ms)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: tr('امسح'),
                              onPressed: () => _deleteRecording(r),
                              icon: Icon(Icons.delete_outline, color: p.muted),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GoldLabel(tr('أيام سابقة')),
                      for (final e in past.take(30))
                        InkWell(
                          onTap: () => _goTo(parseKey(e.key)),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: p.line)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(fmtDateShort(parseKey(e.key))),
                                ),
                                Muted(
                                  [
                                    if (e.value.text.trim().isNotEmpty)
                                      tr('مكتوب'),
                                    if (e.value.recordings.isNotEmpty)
                                      tr('{n} ريكورد', {
                                        'n': e.value.recordings.length,
                                      }),
                                  ].join(' + '),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
