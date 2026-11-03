import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../services/ai_university_fuyu_lab_analytics.dart';

typedef AiUniversityFuyuLabStart = Future<bool> Function();
typedef AiUniversityFuyuLabSubmit = Future<bool> Function(
  AiUniversityFuyuLabCompletion completion,
);

class AiUniversityFuyuLabTaskCard extends StatefulWidget {
  const AiUniversityFuyuLabTaskCard({
    super.key,
    required this.onStart,
    required this.onSubmit,
  });

  final AiUniversityFuyuLabStart onStart;
  final AiUniversityFuyuLabSubmit onSubmit;

  @override
  State<AiUniversityFuyuLabTaskCard> createState() =>
      _AiUniversityFuyuLabTaskCardState();
}

class _AiUniversityFuyuLabTaskCardState
    extends State<AiUniversityFuyuLabTaskCard> {
  static const _outcomes = <(String, String)>[
    ('first_try_success', '推論: 初回成功'),
    ('success_after_error', '推論: エラー後に自己回復'),
    ('success_after_difference', '推論: 出力差分後に自己回復'),
    ('unresolved_error', '推論: エラー未解決'),
    ('unresolved_difference', '推論: 出力差分未解決'),
    ('reading_completed', '読解専用フォールバック完了'),
  ];

  static const _rubricLabels = <String>[
    'model ID・revision・画像URL・確認日を固定した',
    '推論1回または読解専用フォールバックの理由を記録した',
    '期待値との比較またはエラーを省略せず記録した',
    'ライセンス・研究用途・API境界を説明した',
  ];

  final _rubricChecks = List<bool>.filled(4, false);
  DateTime? _startedAt;
  String? _attemptOutcome;
  bool _submitting = false;
  bool _submitted = false;

  bool get _canSubmit =>
      _startedAt != null &&
      _attemptOutcome != null &&
      !_submitting &&
      !_submitted;

  void _start() {
    if (_startedAt != null) return;
    setState(() => _startedAt = DateTime.now());
    widget.onStart().ignore();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final elapsed = max(1, DateTime.now().difference(_startedAt!).inSeconds);
    setState(() => _submitting = true);
    final accepted = await widget.onSubmit(
      AiUniversityFuyuLabCompletion(
        attemptOutcome: _attemptOutcome!,
        completionSeconds: elapsed,
        rubricScore: _rubricChecks.where((checked) => checked).length,
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = accepted;
    });
    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('匿名結果を送信できませんでした。時間をおいて再試行してください。'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF0F1929),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fuyu-8B 固定モデルカード課題'),
              const SizedBox(height: 8),
              const Text(
                '開始・有限選択の結果・完了秒数・rubric得点だけを送信します。'
                '入力文、生成文、エラー本文、個人情報は送信しません。',
              ),
              const SizedBox(height: 12),
              if (_startedAt == null)
                FilledButton.icon(
                  key: const Key('fuyu-lab-start'),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('課題計測を開始'),
                )
              else ...[
                const Text('実行結果を1つ選択'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (value, label) in _outcomes)
                      ChoiceChip(
                        key: Key('fuyu-lab-outcome-$value'),
                        label: Text(label),
                        selected: _attemptOutcome == value,
                        onSelected: _submitted
                            ? null
                            : (_) => setState(() => _attemptOutcome = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('4項目rubric'),
                for (var index = 0; index < _rubricLabels.length; index++)
                  CheckboxListTile(
                    key: Key('fuyu-lab-rubric-$index'),
                    contentPadding: EdgeInsets.zero,
                    value: _rubricChecks[index],
                    onChanged: _submitted
                        ? null
                        : (value) => setState(
                              () => _rubricChecks[index] = value ?? false,
                            ),
                    title: Text(_rubricLabels[index]),
                  ),
                const SizedBox(height: 12),
                if (_submitted)
                  const Text(
                    '匿名結果を送信しました',
                    key: Key('fuyu-lab-submitted'),
                  )
                else if (_submitting)
                  const LinearProgressIndicator()
                else
                  FilledButton.icon(
                    key: const Key('fuyu-lab-submit'),
                    onPressed: _canSubmit ? _submit : null,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('匿名結果を送信'),
                  ),
              ],
            ],
          ),
        ),
      );
}
