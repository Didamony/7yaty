import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/dates.dart';
import '../core/i18n.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/files.dart';
import 'frames.dart';
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

  /// The note being written; saved as a new note with the save button.
  final _text = TextEditingController();

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
    _player.onPlayerComplete.listen((_) => setState(() => _playing = null));
  }

  @override
  void dispose() {
    _addNote(rebuild: false);
    _text.dispose();
    _recTick?.cancel();
    _recorder.dispose();
    _player.dispose();
    _speech.stop();
    super.dispose();
  }

  void _goTo(DateTime d) {
    _addNote();
    setState(() => _day = d);
  }

  /// Saves what is being written as a new note of the day and clears the
  /// box for the next one.
  void _addNote({bool rebuild = true}) {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final key = dkey(_day);
    _store.update((d) {
      final e = d.journal.putIfAbsent(key, JournalEntry.new);
      e.notes.add(
        Note(
          id: newId(),
          text: text,
          frame: e.frame,
          at: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
    _text.clear();
    if (rebuild && mounted) {
      FocusScope.of(context).unfocus();
      setState(() {});
    }
  }

  /// Deletes a picture file once nothing uses it.
  Future<void> _dropFrame(String? frame) async {
    if (frame == null) return;
    if (_store.data.journal.values.any((e) => e.usesFrame(frame))) return;
    await dropFrameFile(frame);
  }

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
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
        if (mounted) setState(() {});
      },
      listenOptions: SpeechListenOptions(
        localeId: _speechLocales[L10n.lang],
        partialResults: true,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  /// The first audio format this device can record: AAC on phones and
  /// Safari, Opus/WebM in other browsers.
  Future<(AudioEncoder, String)> _format() async {
    for (final f in const [
      (AudioEncoder.aacLc, 'm4a'),
      (AudioEncoder.opus, 'webm'),
      (AudioEncoder.wav, 'wav'),
    ]) {
      if (await _recorder.isEncoderSupported(f.$1)) return f;
    }
    return (AudioEncoder.aacLc, 'm4a');
  }

  Future<void> _toggleRecording() async {
    if (_recFile != null) {
      final result = await _recorder.stop();
      _recTick?.cancel();
      final ms = DateTime.now().difference(_recStart!).inMilliseconds;
      final file = _recFile!;
      setState(() => _recFile = null);
      // The browser hands back a blob URL; keep the audio in app storage.
      if (kIsWeb && result != null) {
        final bytes = (await http.get(Uri.parse(result))).bodyBytes;
        await Files.write('recordings', file, bytes);
      }
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
    final (encoder, ext) = await _format();
    final file = '${newId()}.$ext';
    await Files.ensure('recordings');
    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        bitRate: 32000,
        sampleRate: kIsWeb ? 48000 : 22050,
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
    if (kIsWeb) {
      final bytes = await Files.read('recordings', r.file);
      if (bytes == null) return;
      final ext = r.file.split('.').last;
      await _player.play(
        BytesSource(
          bytes,
          mimeType: const {
            'm4a': 'audio/mp4',
            'webm': 'audio/webm',
            'wav': 'audio/wav',
          }[ext],
        ),
      );
    } else {
      await _player.play(DeviceFileSource(Files.path('recordings', r.file)));
    }
    setState(() => _playing = r.file);
  }

  /// A card, or the note on its picture when it has a frame.
  Widget _framed(String? frame, Widget child) => frame == null
      ? SectionCard(child: child)
      : FramedCard(frame: frame, child: child);

  /// Picks the background for the note being written.
  Future<void> _pickDraftFrame() async {
    final key = dkey(_day);
    final f = await pickFrame(
      context,
      current: _store.data.journal[key]?.frame,
    );
    if (f == null) return;
    String? old;
    await _store.update((d) {
      final e = d.journal.putIfAbsent(key, JournalEntry.new);
      old = e.frame;
      e.frame = f.isEmpty ? null : f;
      if (e.isEmpty) d.journal.remove(key);
    });
    if (old != f) await _dropFrame(old);
  }

  Future<void> _pickNoteFrame(Note note) async {
    final f = await pickFrame(context, current: note.frame);
    if (f == null) return;
    final old = note.frame;
    await _store.update((_) => note.frame = f.isEmpty ? null : f);
    if (old != f) await _dropFrame(old);
  }

  Future<void> _editNote(Note note) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoteEditor(initial: note.text),
    );
    if (text == null || text.trim().isEmpty) return;
    await _store.update((_) => note.text = text.trim());
  }

  Future<void> _deleteNote(Note note) async {
    if (!await confirm(context, tr('تمسح الكتابة دي؟'), ok: tr('امسحها'))) {
      return;
    }
    final key = dkey(_day);
    await _store.update((d) {
      final e = d.journal[key];
      e?.notes.removeWhere((x) => x.id == note.id);
      if (e != null && e.isEmpty) d.journal.remove(key);
    });
    await _dropFrame(note.frame);
  }

  Future<void> _pickRecordingFrame(Recording r) async {
    final f = await pickFrame(context, current: r.frame);
    if (f == null) return;
    final old = r.frame;
    await _store.update((_) => r.frame = f.isEmpty ? null : f);
    if (old != f) await _dropFrame(old);
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
    await _dropFrame(r.frame);
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
              _framed(
                entry?.frame,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: GoldLabel(tr('اكتب حاجة جديدة'))),
                        IconButton(
                          tooltip: tr('خلفية'),
                          visualDensity: VisualDensity.compact,
                          onPressed: _pickDraftFrame,
                          icon: Icon(Icons.wallpaper, color: p.goldText),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _text,
                      onChanged: (_) => setState(() {}),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      minLines: 4,
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
                    if (_text.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          onPressed: _addNote,
                          icon: const Icon(Icons.check),
                          label: Text(tr('حفظ')),
                        ),
                      ),
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
              if (entry != null && entry.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                GoldLabel(tr('كتابات اليوم ({n})', {'n': entry.notes.length})),
                for (final note in entry.notes) ...[
                  const SizedBox(height: 10),
                  _framed(
                    note.frame,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: note.at == 0
                                  ? const SizedBox.shrink()
                                  : Muted(
                                      fmtTime(
                                        DateTime.fromMillisecondsSinceEpoch(
                                          note.at,
                                        ),
                                      ),
                                      size: 12,
                                    ),
                            ),
                            _SmallIcon(
                              tooltip: tr('خلفية'),
                              icon: Icons.wallpaper,
                              onPressed: () => _pickNoteFrame(note),
                            ),
                            _SmallIcon(
                              tooltip: tr('تعديل'),
                              icon: Icons.edit_outlined,
                              onPressed: () => _editNote(note),
                            ),
                            _SmallIcon(
                              tooltip: tr('امسح'),
                              icon: Icons.delete_outline,
                              onPressed: () => _deleteNote(note),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.text,
                          style: const TextStyle(fontSize: 15, height: 1.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (entry != null && entry.recordings.isNotEmpty) ...[
                const SizedBox(height: 12),
                GoldLabel(tr('ريكوردات اليوم')),
                for (final r in entry.recordings) ...[
                  const SizedBox(height: 8),
                  _framed(
                    r.frame,
                    Row(
                      children: [
                        IconButton.filled(
                          tooltip: _playing == r.file
                              ? tr('إيقاف')
                              : tr('تشغيل'),
                          onPressed: () => _play(r),
                          icon: Icon(
                            _playing == r.file ? Icons.stop : Icons.play_arrow,
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
                          tooltip: tr('خلفية'),
                          onPressed: () => _pickRecordingFrame(r),
                          icon: Icon(Icons.wallpaper, color: p.goldText),
                        ),
                        IconButton(
                          tooltip: tr('امسح'),
                          onPressed: () => _deleteRecording(r),
                          icon: Icon(Icons.delete_outline, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
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
                                    if (e.value.notes.isNotEmpty)
                                      tr('{n} كتابة', {
                                        'n': e.value.notes.length,
                                      }),
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

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    onPressed: onPressed,
    icon: Icon(icon, size: 20, color: context.pal.goldText),
  );
}

/// Bottom sheet to change a saved note; pops the new text, or null.
class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.initial});

  final String initial;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 10,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, _text.text),
            icon: const Icon(Icons.check),
            label: Text(tr('حفظ')),
          ),
        ),
      ],
    ),
  );
}
