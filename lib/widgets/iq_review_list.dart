// テスト結果の「問題ごとの振り返り」。
//
// 仮説検証 H6: 結果画面はスコアしか出しておらず、どの問題をなぜ間違えたかを
// 一切見られなかった。学習を目的にした機能でそれは致命的なので、
// 選んだ選択肢・正解・解説をここで返す。

import 'package:flutter/material.dart';

import '../models/iq_test.dart';
import '../theme/design_tokens.dart';

class IqReviewList extends StatefulWidget {
  final List<IqAnswerRecord> answers;
  final Map<String, IqQuestion> questionsByKey;

  /// 復元した選択肢の並びが受験時と一致しているか。
  /// false のときは「あなたが選んだ選択肢」を出さない
  /// (index の指す先が当時と違うため、誤った選択肢を提示してしまう)。
  final bool optionOrderIsTrustworthy;

  const IqReviewList({
    super.key,
    required this.answers,
    required this.questionsByKey,
    this.optionOrderIsTrustworthy = true,
  });

  @override
  State<IqReviewList> createState() => _IqReviewListState();
}

class _IqReviewListState extends State<IqReviewList> {
  /// 既定は誤答のみ。全問見たい人向けにトグルを出す。
  bool _wrongOnly = true;

  @override
  Widget build(BuildContext context) {
    final known = widget.answers
        .where((a) => widget.questionsByKey.containsKey(a.questionKey))
        .toList();
    final items = known.where((a) => !_wrongOnly || !a.isCorrect).toList();
    final wrongCount = known.where((a) => !a.isCorrect).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _wrongOnly ? '間違えた $wrongCount 問' : '全 ${known.length} 問',
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _wrongOnly = !_wrongOnly),
              child: Text(
                _wrongOnly ? 'すべて表示' : '誤答のみ',
                style: const TextStyle(color: DesignTokens.orange),
              ),
            ),
          ],
        ),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.space16),
            decoration: BoxDecoration(
              color: DesignTokens.surface1,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              border: Border.all(color: DesignTokens.divider),
            ),
            child: Text(
              _wrongOnly ? '全問正解でした。' : '表示できる問題がありません。',
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 13,
              ),
            ),
          )
        else
          ...items.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space12),
              child: _ReviewCard(
                question: widget.questionsByKey[a.questionKey]!,
                answer: a,
                showSelectedOption: widget.optionOrderIsTrustworthy,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final IqQuestion question;
  final IqAnswerRecord answer;
  final bool showSelectedOption;

  const _ReviewCard({
    required this.question,
    required this.answer,
    required this.showSelectedOption,
  });

  @override
  Widget build(BuildContext context) {
    final unanswered = answer.selectedIndex == null;
    final color = answer.isCorrect
        ? DesignTokens.green
        : unanswered
            ? DesignTokens.textTertiary
            : DesignTokens.red;
    final statusLabel = answer.isCorrect
        ? '正解'
        : unanswered
            ? '未回答'
            : '不正解';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                answer.isCorrect
                    ? Icons.check_circle_outline
                    : unanswered
                        ? Icons.remove_circle_outline
                        : Icons.cancel_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: DesignTokens.space8),
              Text(
                statusLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${question.category.labelJa}・難易度${question.difficulty}',
                style: const TextStyle(
                  color: DesignTokens.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          if (question.hasMemoryPhase) ...[
            Text(
              '提示された内容: ${question.memoryStimulus}',
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
          ],
          Text(
            question.prompt,
            semanticsLabel: question.semanticPrompt,
            style: TextStyle(
              color: DesignTokens.textOnDark,
              fontSize: 14,
              height: question.monospacePrompt ? 1.8 : 1.6,
              fontFamily: question.monospacePrompt ? 'monospace' : null,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          _AnswerRow(
            label: '正解',
            text: question.options[question.correctIndex],
            semanticText: question.semanticOption(question.correctIndex),
            color: DesignTokens.green,
            monospace: question.monospacePrompt,
          ),
          if (!answer.isCorrect && !unanswered && showSelectedOption) ...[
            const SizedBox(height: DesignTokens.space4),
            _AnswerRow(
              label: 'あなた',
              text: question.options[answer.selectedIndex!],
              semanticText: question.semanticOption(answer.selectedIndex!),
              color: DesignTokens.red,
              monospace: question.monospacePrompt,
            ),
          ],
          const SizedBox(height: DesignTokens.space12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.space12),
            decoration: BoxDecoration(
              color: DesignTokens.surface2,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: Text(
              question.explanation,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ),
          // H5: 記録だけして使っていなかった応答時間をここで返す。
          if (answer.responseMs > 0) ...[
            const SizedBox(height: DesignTokens.space8),
            Text(
              '解答時間 ${(answer.responseMs / 1000).toStringAsFixed(1)} 秒',
              style: const TextStyle(
                color: DesignTokens.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String text;
  final String semanticText;
  final Color color;
  final bool monospace;

  const _AnswerRow({
    required this.label,
    required this.text,
    required this.semanticText,
    required this.color,
    required this.monospace,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            semanticsLabel: semanticText,
            style: TextStyle(
              color: DesignTokens.textOnDark,
              fontSize: 13,
              height: monospace ? 1.7 : 1.4,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
