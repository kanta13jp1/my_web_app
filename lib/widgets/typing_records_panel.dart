import 'dart:async';

import 'package:flutter/material.dart';

import '../services/typing_score_service.dart';

/// Opt-in controls. No network request occurs before an explicit button press.
class TypingRecordsPanel extends StatefulWidget {
  const TypingRecordsPanel({
    super.key,
    required this.store,
    required this.report,
    required this.english,
  });
  final TypingScoreStore store;
  final TypingRunReport? report;
  final bool english;

  @override
  State<TypingRecordsPanel> createState() => _TypingRecordsPanelState();
}

class _TypingRecordsPanelState extends State<TypingRecordsPanel> {
  bool _busy = false;
  String _message = '';
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _ranking = [];
  String? _owner;
  StreamSubscription<String?>? _auth;
  String _t(String ja, String en) => widget.english ? en : ja;

  void _listen() {
    _auth = widget.store.accountChanges.listen((_) {
      if (mounted) {
        setState(() {
          _history = [];
          _ranking = [];
          _message = '';
          _owner = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TypingRecordsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store || _owner != widget.store.accountId) {
      _history = [];
      _ranking = [];
      _message = '';
    }
    if (oldWidget.store != widget.store) {
      _auth?.cancel();
      _listen();
    }
  }

  Future<void> _act(Future<void> Function() operation) async {
    if (_busy) return;
    final owner = widget.store.accountId;
    if (owner == null) {
      setState(() {
        _history = [];
        _ranking = [];
        _message = _t('ログインしてから利用してください。', 'Please sign in first.');
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
      if (_owner != owner) {
        _history = [];
        _ranking = [];
      }
      _owner = owner;
    });
    try {
      await operation();
      if (!mounted) return;
      if (widget.store.accountId != owner) {
        _history = [];
        _ranking = [];
        _message = _t('ログイン状態が変わりました。', 'Your account changed.');
      } else {
        _message = _t('更新しました。', 'Updated.');
      }
    } catch (_) {
      if (!mounted) return;
      _history = [];
      _ranking = [];
      _message = _t(
        '保存・読込できませんでした。ログインや通信、機能の提供状況を確認し、同じ記録で再試行できます。',
        'Could not save or load. Check your sign-in, connection and feature availability. You can retry the same record.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(String id) async {
    final owner = widget.store.accountId;
    var draftAlias = '';
    final alias = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('この記録を公開', 'Publish this record')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t(
                  '専用名とスコア・正確さ・語数が参加者に公開されます。実名やメールを使わないでください。自己申告の成績です。ランキング表示はプレイから90日で終了しますが、期限だけではデータを削除しません。後で公開を取り消せます。',
                  'Your alias, score, accuracy and word count will be visible to participants. Avoid your real name or email. Scores are self-reported. Leaderboard visibility ends 90 days after play without deleting stored data. You can withdraw later.',
                ),
              ),
              TextField(
                onChanged: (value) => draftAlias = value,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: _t(
                    '専用名（英数字・空白・_・-、3〜24文字）',
                    'Alias (3–24 letters, digits, spaces, _ or -)',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draftAlias.trim()),
            child: Text(_t('公開する', 'Publish')),
          ),
        ],
      ),
    );
    if (!mounted || alias == null || widget.store.accountId != owner) return;
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _-]{2,23}$').hasMatch(alias)) {
      setState(
        () => _message = _t('専用名の形式を確認してください。', 'Check the alias format.'),
      );
      return;
    }
    await _act(() async {
      await widget.store.publish(id, alias);
      _history = await widget.store.mine();
    });
  }

  Future<void> _remove(Map<String, dynamic> row, {required bool history}) async {
    final owner = widget.store.accountId;
    if (owner == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          history
              ? _t('この記録を削除しますか？', 'Delete this record?')
              : _t('この公開を取り消しますか？', 'Withdraw this publication?'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row['mode']} • ${row['score']} • ${row['created_at'] ?? ''}',
              ),
              Text(
                history
                  ? _t(
                      '選択した1件の非公開履歴と、それに対応する公開エントリーを完全に削除します。他の記録は削除しません。アプリ内で元に戻すことはできず、バックアップからの個別復元も保証できません。',
                      'Permanently delete this one private record and its associated public entry. Other records stay. There is no undo here, and individual recovery from backups is not guaranteed.',
                    )
                  : _t(
                      'この記録の公開エントリーだけを削除し、非公開履歴は残します。公開取消を元に戻す操作はありませんが、プレイから90日以内なら改めて公開できます。',
                      'Remove only this public entry. Your private record stays. Withdrawal has no undo action, but an eligible run can be published again within 90 days of play.',
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              history
                  ? _t('完全に削除', 'Delete permanently')
                  : _t('公開取消を確定', 'Confirm withdrawal'),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || widget.store.accountId != owner) return;
    await _act(() async {
      final id = row['id'] as String;
      if (history) {
        await widget.store.delete(id);
      } else {
        await widget.store.withdraw(id);
      }
      _ranking = [];
      _history = await widget.store.mine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.store.accountId;
    final visibleHistory =
        signedIn == _owner ? _history : <Map<String, dynamic>>[];
    final visibleRanking =
        signedIn == _owner ? _ranking : <Map<String, dynamic>>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('成績とオンラインランキング', 'Records and online leaderboard'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              _t(
                '保存は非公開。ランキングへの公開は別操作です。自己申告の成績で、不正を検証した順位ではありません。',
                'Saving is private. Publication is a separate choice. Scores are self-reported, not verified competitive results.',
              ),
            ),
            Text(
              _t(
                'ランキング表示はプレイから90日間です。期限が来てもデータは削除せず、公開設定と非公開履歴を保持します。履歴は最大100件で、満杯なら新しい保存を停止します。ご自身の削除操作やアカウント削除で消した記録は復元できません。',
                'Leaderboard visibility ends 90 days after the run. Expiry hides entries without erasing them or private history. Up to 100 records are kept; saving stops when full. Records you delete, or remove by deleting your account, cannot be restored here.',
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.report != null)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _act(() async {
                              await widget.store.save(widget.report!);
                              _history = await widget.store.mine();
                            }),
                    child:
                        Text(_t('この成績を非公開で保存', 'Save this result privately')),
                  ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _act(() async {
                            _history = await widget.store.mine();
                          }),
                  child: Text(_t('自分の履歴を読む', 'Load my history')),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _act(() async {
                            _ranking = await widget.store.ranking();
                          }),
                  child: Text(_t('ランキングを見る', 'View leaderboard')),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message.isNotEmpty)
              Semantics(liveRegion: true, child: Text(_message)),
            for (final row in visibleHistory)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${row['mode']} • ${row['score']} ${_t('点', 'points')}'),
                  if (row['can_publish'] == true)
                    TextButton(
                      onPressed:
                          _busy ? null : () => _publish(row['id'] as String),
                      child: Text(_t('公開を選ぶ', 'Choose publication')),
                    ),
                  if (row['alias'] != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _remove(row, history: false),
                      child: Text(_t('公開取消', 'Withdraw')),
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _remove(row, history: true),
                    child: Text(_t('記録を削除', 'Delete record')),
                  ),
                ],
              ),
            for (var i = 0; i < visibleRanking.length; i++)
              Text(
                '${i + 1}. ${visibleRanking[i]['alias']} • ${visibleRanking[i]['score']} ${_t('点', 'points')} • ${visibleRanking[i]['accuracy']}%',
              ),
          ],
        ),
      ),
    );
  }
}
