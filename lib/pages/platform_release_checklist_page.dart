import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/models/platform_release_checklist.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlatformReleaseChecklistPage extends StatefulWidget {
  const PlatformReleaseChecklistPage({super.key});

  static const routeName = '/platform-release-checklist';

  @override
  State<PlatformReleaseChecklistPage> createState() =>
      _PlatformReleaseChecklistPageState();
}

class _PlatformReleaseChecklistPageState
    extends State<PlatformReleaseChecklistPage> {
  static const _storageKey = 'platform_release_checklist_v1';
  late final TextEditingController _scopeController;
  late final Map<String, TextEditingController> _noteControllers;
  PlatformReleaseChecklist _checklist = const PlatformReleaseChecklist();
  PlatformReleaseChecklist? _clearedDraft;
  String? _storageError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scopeController = TextEditingController();
    _noteControllers = <String, TextEditingController>{
      for (final platform in PlatformReleaseChecklist.platforms)
        platform: TextEditingController(),
    };
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (!mounted) return;
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('checklist must be an object');
          }
          _setChecklist(
            PlatformReleaseChecklist.fromJson(decoded.cast<String, Object?>()),
            persist: false,
          );
        } on FormatException {
          _storageError = '保存済みの確認内容を読み取れませんでした。画面の入力は新しく始められます。';
          await preferences.remove(_storageKey);
        }
      }
    } catch (_) {
      if (mounted) {
        _storageError = 'この端末では確認内容を保存できません。画面を閉じると入力は失われます。';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _setChecklist(
    PlatformReleaseChecklist checklist, {
    bool persist = true,
  }) {
    _checklist = checklist;
    _scopeController.text = checklist.sharedScope;
    for (final platform in PlatformReleaseChecklist.platforms) {
      _noteControllers[platform]!.text = checklist.notes[platform] ?? '';
    }
    if (persist) unawaited(_persist());
    if (mounted) setState(() {});
  }

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _storageKey,
        jsonEncode(_checklist.toJson()),
      );
      if (!saved) throw StateError('shared preferences rejected the write');
      if (mounted && _storageError != null) {
        setState(() => _storageError = null);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _storageError = 'この端末では確認内容を保存できません。画面を閉じると入力は失われます。';
        });
      }
    }
  }

  void _update({
    String? sharedScope,
    String? platform,
    PlatformCheckStatus? status,
    String? note,
  }) {
    final statuses = Map<String, PlatformCheckStatus>.of(_checklist.statuses);
    final notes = Map<String, String>.of(_checklist.notes);
    if (platform != null && status != null) statuses[platform] = status;
    if (platform != null && note != null) notes[platform] = note;
    _checklist = _checklist.copyWith(
      sharedScope: sharedScope,
      notes: notes,
      statuses: statuses,
    );
    unawaited(_persist());
    setState(() {});
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _checklist.toShareText()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('確認内容をクリップボードにコピーしました')),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クリップボードへコピーできませんでした')),
      );
    }
  }

  Future<void> _clear() async {
    _clearedDraft = _checklist;
    _setChecklist(const PlatformReleaseChecklist());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('画面の入力を空にしました'),
          action: SnackBarAction(label: '元に戻す', onPressed: _restore),
        ),
      );
    }
  }

  void _restore() {
    final draft = _clearedDraft;
    if (draft == null) return;
    _setChecklist(draft);
    _clearedDraft = null;
  }

  @override
  void dispose() {
    _scopeController.dispose();
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('プラットフォーム別リリース確認'),
        actions: <Widget>[
          IconButton(
            tooltip: 'コピー',
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: '確認内容を空にする',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            '共通コードがあっても、各プラットフォームの確認は別に残ります。初期状態はすべて「未確認」です。',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          if (_storageError != null) ...<Widget>[
            Semantics(
              liveRegion: true,
              child: Text(
                _storageError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _scopeController,
            onChanged: (value) => _update(sharedScope: value),
            decoration: const InputDecoration(
              labelText: '共通の確認範囲',
              hintText: '例: 保存前の入力を閉じようとしたときの確認画面',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          for (final platform in PlatformReleaseChecklist.platforms)
            _PlatformCard(
              platform: platform,
              status: _checklist.statusFor(platform),
              noteController: _noteControllers[platform]!,
              onStatusChanged: (status) => _update(
                platform: platform,
                status: status,
              ),
              onNoteChanged: (note) => _update(platform: platform, note: note),
            ),
          const SizedBox(height: 8),
          const Text(
            'この一覧は端末内にだけ保存されます。コピーは、この画面で選んだときだけ行われます。',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.platform,
    required this.status,
    required this.noteController,
    required this.onStatusChanged,
    required this.onNoteChanged,
  });

  final String platform;
  final PlatformCheckStatus status;
  final TextEditingController noteController;
  final ValueChanged<PlatformCheckStatus> onStatusChanged;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(platform, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<PlatformCheckStatus>(
                key: ValueKey<String>('$platform-${status.name}'),
                initialValue: status,
                decoration: const InputDecoration(labelText: '確認状態'),
                items: PlatformCheckStatus.values
                    .map(
                      (candidate) => DropdownMenuItem(
                        value: candidate,
                        child: Text(candidate.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onStatusChanged(value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                onChanged: onNoteChanged,
                decoration: InputDecoration(
                  labelText: '$platform の確認メモ',
                  hintText: '端末、OS、ストア審査、未確認事項など',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('実機・OS・ストア審査が未確認なら、その理由と次の確認をメモに残します。'),
              ),
            ],
          ),
        ),
      );
}
