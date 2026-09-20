import 'package:flutter/material.dart';
import '../services/jev_client.dart';
import '../services/jev_instant_classifier_service.dart';

/// Read-only suggestions: deliberately has no persistence or selection callback.
class ExpenseClassificationReview extends StatefulWidget {
  final String memo;

  /// Optional borrowed client. The caller retains ownership when supplied.
  final JevClient? client;

  const ExpenseClassificationReview({
    super.key,
    required this.memo,
    this.client,
  });

  @override
  State<ExpenseClassificationReview> createState() =>
      _ExpenseClassificationReviewState();
}

class _ExpenseClassificationReviewState
    extends State<ExpenseClassificationReview> {
  late JevClient _client;
  late JevInstantClassifierService _classifier;
  late ExpenseCategoryPrediction _prediction;
  bool _busy = false;
  bool _aiUnavailable = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _configureClient();
    _resetSuggestion();
  }

  void _configureClient() {
    _client = widget.client ?? JevClient();
    _classifier = JevInstantClassifierService(client: _client);
  }

  void _resetSuggestion() {
    _request++;
    _busy = false;
    _aiUnavailable = false;
    _prediction = _classifier.predictLocalFallback(widget.memo);
  }

  @override
  void didUpdateWidget(covariant ExpenseClassificationReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clientChanged = oldWidget.client != widget.client;
    if (clientChanged) {
      if (oldWidget.client == null) {
        _client.dispose();
      }
      _configureClient();
    }
    if (clientChanged || oldWidget.memo != widget.memo) {
      _resetSuggestion();
    }
  }

  Future<void> _askAi() async {
    final request = ++_request;
    final memo = widget.memo.trim();
    setState(() {
      _busy = true;
      _aiUnavailable = false;
    });
    final prediction = await _classifier.predictCategory(memo);
    if (!mounted || request != _request) {
      return;
    }
    setState(() {
      _prediction = prediction;
      _busy = false;
      _aiUnavailable = prediction.isFallback;
    });
  }

  @override
  void dispose() {
    _request++;
    if (widget.client == null) {
      _client.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.memo.trim().isEmpty;
    final ai = _prediction.source == 'jev' && !_prediction.isFallback;
    final hasCandidate = !empty && (ai || _prediction.source == 'local_rule');
    final colors = Theme.of(context).colorScheme;
    final destination = Uri.tryParse(_client.endpoint)?.host ?? '';
    return Container(
      key: const Key('expense_classification_review'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '支出の分類候補',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                avatar: Icon(
                  empty ? Icons.edit_note : Icons.receipt_long,
                  size: 18,
                ),
                label: Text(empty ? '内容を入力' : '内容を確認'),
              ),
              if (!empty)
                Chip(
                  avatar: const Icon(Icons.manage_search, size: 18),
                  label: Text(ai ? 'AI候補' : '端末内ルール'),
                ),
              if (!empty)
                const Chip(
                  avatar: Icon(Icons.fact_check_outlined, size: 18),
                  label: Text('要確認'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            empty
                ? '「内容」に店名や品目を入力すると候補を表示します。'
                : hasCandidate
                    ? '候補：${_prediction.categoryLabel}'
                    : '候補を絞れませんでした',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          if (!empty)
            Text(
              ai
                  ? 'AIの提案です。用途や明細と照らして確認してください。'
                  : hasCandidate
                      ? 'キーワード一致による候補です。店名だけでは用途を確定できません。'
                      : 'ルールに一致しません。品目や用途を追記して確認してください。',
            ),
          if (ai)
            Text(
              'モデルの確信度：${(_prediction.confidence * 100).toStringAsFixed(0)}%'
              '（正答率ではありません）',
            ),
          if (_aiUnavailable) ...[
            const SizedBox(height: 8),
            const Text('AIの候補を取得できなかったため、端末内ルールで表示しています。'),
          ],
          const SizedBox(height: 8),
          const Text('候補は参考表示です。記録・金額・カテゴリを自動で変更しません。'),
          if (_classifier.isAvailable && !empty) ...[
            const SizedBox(height: 8),
            Text(
              'ボタンを押した場合のみ、この内容を'
              '${_client.isLocalMode ? 'ローカルAI' : 'AIサービス'}'
              '（$destination）に送信します。',
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _busy ? null : _askAi,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(_busy ? 'AIに確認中…' : 'AIにも候補を聞く'),
            ),
          ],
        ],
      ),
    );
  }
}
