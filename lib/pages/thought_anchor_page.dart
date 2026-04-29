import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/thought_anchor_service.dart';

class ThoughtAnchorPage extends StatefulWidget {
  const ThoughtAnchorPage({
    super.key,
    this.service = const ThoughtAnchorService(),
  });

  final ThoughtAnchorService service;

  @override
  State<ThoughtAnchorPage> createState() => _ThoughtAnchorPageState();
}

class _ThoughtAnchorPageState extends State<ThoughtAnchorPage> {
  final TextEditingController _anchorController = TextEditingController();
  final TextEditingController _whyNowController = TextEditingController();
  final TextEditingController _returnPhraseController = TextEditingController(
    text: '今はこれに戻る',
  );

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSessionActive = false;
  int _selectedDuration = ThoughtAnchorService.builtinDurations[2];
  Duration _remaining = Duration.zero;
  Timer? _timer;
  DateTime? _sessionStartedAt;
  final List<String> _distractionNotes = <String>[];
  List<ThoughtAnchorRecord> _records = const <ThoughtAnchorRecord>[];
  ThoughtAnchorStats _stats = ThoughtAnchorStats.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anchorController.dispose();
    _whyNowController.dispose();
    _returnPhraseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final records = await widget.service.loadRecords();
    final stats = await widget.service.loadStats();
    if (!mounted) {
      return;
    }
    setState(() {
      _records = records;
      _stats = stats;
      _isLoading = false;
    });
  }

  void _startSession() {
    final anchor = _anchorController.text.trim();
    final returnPhrase = _returnPhraseController.text.trim();
    if (anchor.isEmpty || returnPhrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('考える対象と戻る言葉を入力してください')),
      );
      return;
    }

    _timer?.cancel();
    setState(() {
      _isSessionActive = true;
      _remaining = Duration(minutes: _selectedDuration);
      _sessionStartedAt = DateTime.now();
      _distractionNotes.clear();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        await _completeSession(autoCompleted: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
      });
    });
  }

  Future<void> _completeSession({bool autoCompleted = false}) async {
    if (!_isSessionActive || _isSaving) {
      return;
    }
    _timer?.cancel();

    final anchor = _anchorController.text.trim();
    final returnPhrase = _returnPhraseController.text.trim();
    if (anchor.isEmpty || returnPhrase.isEmpty) {
      setState(() {
        _isSessionActive = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await widget.service.completeSession(
        anchorText: anchor,
        whyNow: _whyNowController.text,
        returnPhrase: returnPhrase,
        durationMinutes: _selectedDuration,
        distractionNotes: List<String>.from(_distractionNotes),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _records = result.records;
        _stats = result.stats;
        _isSessionActive = false;
        _remaining = Duration.zero;
        _sessionStartedAt = null;
        _distractionNotes.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autoCompleted ? '思考アンカーを完了しました' : 'セッションを保存しました',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _captureDistraction() async {
    if (!_isSessionActive) {
      return;
    }

    final controller = TextEditingController();
    try {
      final note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('別件を退避'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '今浮かんだ別の考え',
              hintText: 'あとで考えればよい内容だけを短く置いておく',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('退避する'),
            ),
          ],
        ),
      );

      if (note == null || note.trim().isEmpty || !mounted) {
        return;
      }
      setState(() {
        _distractionNotes.add(note.trim());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('別件を退避して、元の考えへ戻ります')),
      );
    } finally {
      controller.dispose();
    }
  }

  String _formatRemaining(Duration value) {
    final totalSeconds = value.inSeconds.clamp(0, 60 * 60 * 24);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思考アンカー'),
        actions: [
          IconButton(
            onPressed: _isSessionActive || _isSaving ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIntroCard(),
                const SizedBox(height: 12),
                _buildStatsCard(),
                const SizedBox(height: 12),
                _buildComposerCard(),
                const SizedBox(height: 12),
                _buildActiveSessionCard(),
                const SizedBox(height: 12),
                _buildRecentSessionsCard(),
              ],
            ),
    );
  }

  Widget _buildIntroCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ひとつの考えを保持する',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '考える対象を短く固定し、逸れた思考は退避メモに置いてから戻るための機能です。頭の中で保持し続けようとせず、書いて戻ることを習慣化します。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildStatChip(
          label: '今日の完了',
          value: '${_stats.sessionsCompletedToday}回',
          color: const Color(0xFF3D5AFE),
        ),
        _buildStatChip(
          label: '連続日数',
          value: '${_stats.currentStreak}日',
          color: const Color(0xFF3D5AFE),
        ),
        _buildStatChip(
          label: '今日の退避',
          value: '${_stats.distractionNotesToday}件',
          color: const Color(0xFFFF6B35),
        ),
      ],
    );
  }

  Widget _buildComposerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'いま保持したい考え',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _anchorController,
              enabled: !_isSessionActive,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '考える対象',
                hintText: '例: 今日の打ち合わせで伝える論点を3つ整理する',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _whyNowController,
              enabled: !_isSessionActive,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'いま考える理由',
                hintText: '例: これを先に固めないと他の作業がぼやける',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _returnPhraseController,
              enabled: !_isSessionActive,
              decoration: const InputDecoration(
                labelText: '戻る言葉',
                hintText: '例: 今はこれに戻る',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ThoughtAnchorService.builtinDurations
                  .map(
                    (minutes) => ChoiceChip(
                      label: Text('$minutes分'),
                      selected: _selectedDuration == minutes,
                      onSelected: _isSessionActive
                          ? null
                          : (_) {
                              setState(() {
                                _selectedDuration = minutes;
                              });
                            },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSessionActive || _isSaving ? null : _startSession,
                icon: const Icon(Icons.play_arrow),
                label: const Text('アンカー開始'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    if (!_isSessionActive) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'セッションを始めると、ここに残り時間と戻る言葉、退避メモが表示されます。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    final progress = _selectedDuration == 0
        ? 0.0
        : 1 -
            (_remaining.inSeconds /
                Duration(minutes: _selectedDuration).inSeconds);

    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFE8EAF6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.center_focus_strong,
                  color: Color(0xFF3D5AFE),
                ),
                const SizedBox(width: 8),
                Text(
                  '進行中 ${_formatRemaining(_remaining)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 12),
            _buildSessionBlock('考える対象', _anchorController.text.trim()),
            _buildSessionBlock('いま考える理由', _whyNowController.text.trim()),
            _buildSessionBlock('戻る言葉', _returnPhraseController.text.trim()),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _captureDistraction,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: Text('別件を退避 (${_distractionNotes.length})'),
                ),
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _completeSession(),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('保存して終了'),
                ),
              ],
            ),
            if (_sessionStartedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '開始: ${DateFormat('HH:mm').format(_sessionStartedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ],
            if (_distractionNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '退避した別件',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ..._distractionNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('・$note'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近のアンカー',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_records.isEmpty)
              const Text('まだ完了したアンカーはありません。')
            else
              ..._records.take(10).map(_buildRecordTile),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(ThoughtAnchorRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.anchorText,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('yyyy/MM/dd HH:mm').format(record.completedAt)} / ${record.durationMinutes}分 / 退避 ${record.distractionCount}件',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          if (record.whyNow.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('理由: ${record.whyNow}'),
          ],
          const SizedBox(height: 6),
          Text('戻る言葉: ${record.returnPhrase}'),
          if (record.distractionNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...record.distractionNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('・$note'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionBlock(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    final initial = label.isEmpty ? '?' : label.substring(0, 1);
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
      label: Text('$label  $value'),
    );
  }
}
