import 'package:flutter/material.dart';

import '../services/landing_trial_prompt_builder.dart';

class LandingTrialGuidedIntake extends StatefulWidget {
  const LandingTrialGuidedIntake({
    super.key,
    required this.concern,
    required this.onSubmit,
    required this.onCancel,
    this.compact = false,
  });

  final String concern;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  final bool compact;

  @override
  State<LandingTrialGuidedIntake> createState() =>
      _LandingTrialGuidedIntakeState();
}

class _LandingTrialGuidedIntakeState extends State<LandingTrialGuidedIntake> {
  late final List<TextEditingController> _answerControllers;
  int _step = 0;

  bool get _isReview => _step == landingTrialDeepDiveQuestions.length;

  @override
  void initState() {
    super.initState();
    _answerControllers = List<TextEditingController>.generate(
      landingTrialDeepDiveQuestions.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _useQuickAnswer() {
    final answer = landingTrialDeepDiveQuestions[_step].quickAnswer;
    _answerControllers[_step]
      ..text = answer
      ..selection = TextSelection.collapsed(offset: answer.length);
    setState(() {});
  }

  void _goBack() {
    if (_step == 0) {
      widget.onCancel();
      return;
    }
    setState(() => _step -= 1);
  }

  void _goNext() {
    if (_answerControllers[_step].text.trim().isEmpty) return;
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: const Key('landing_trial_guided_intake'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1823) : const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF41505C) : const Color(0xFFCBD5E1),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _isReview
            ? _buildReview(context)
            : Column(
                key: ValueKey<int>(_step),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '質問 ${_step + 1} / ${landingTrialDeepDiveQuestions.length}',
                          key: const Key('landing_trial_guided_progress'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('landing_trial_guided_cancel'),
                        onPressed: widget.onCancel,
                        style: widget.compact
                            ? TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(48, 40),
                              )
                            : null,
                        child: const Text('中止'),
                      ),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: (_step + 1) / landingTrialDeepDiveQuestions.length,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  SizedBox(height: widget.compact ? 12 : 16),
                  Text(
                    landingTrialDeepDiveQuestions[_step].question,
                    style: TextStyle(
                      fontSize: widget.compact ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('landing_trial_guided_answer'),
                    controller: _answerControllers[_step],
                    maxLength: 60,
                    minLines: widget.compact ? 1 : 2,
                    maxLines: widget.compact ? 2 : 3,
                    scrollPadding: EdgeInsets.only(
                      bottom: widget.compact ? 280 : 120,
                    ),
                    onChanged: (_) => setState(() {}),
                    textInputAction:
                        _step == landingTrialDeepDiveQuestions.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                    onSubmitted: (_) => _goNext(),
                    decoration: InputDecoration(
                      hintText: landingTrialDeepDiveQuestions[_step].hint,
                      border: const OutlineInputBorder(),
                      isDense: widget.compact,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('landing_trial_guided_quick_answer'),
                      onPressed: _useQuickAnswer,
                      icon: const Icon(Icons.auto_awesome, size: 17),
                      label: Text(
                        widget.compact
                            ? '迷ったら: ${landingTrialDeepDiveQuestions[_step].quickAnswer}'
                            : '迷ったら「${landingTrialDeepDiveQuestions[_step].quickAnswer}」',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('landing_trial_guided_back'),
                          onPressed: _goBack,
                          child: Text(_step == 0 ? '入力に戻る' : '戻る'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const Key('landing_trial_guided_next'),
                          onPressed:
                              _answerControllers[_step].text.trim().isEmpty
                                  ? null
                                  : _goNext,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: Text(
                            _step == landingTrialDeepDiveQuestions.length - 1
                                ? widget.compact
                                    ? '内容を確認'
                                    : '送る内容を確認'
                                : '次の質問へ',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final prompt = LandingTrialPromptBuilder.build(
      concern: widget.concern,
      answers: [for (final controller in _answerControllers) controller.text],
    );

    return Column(
      key: const Key('landing_trial_guided_review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'AIに送る内容を確認',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '5つの回答を、提案に必要な要点へ自動でまとめました。送信は下のボタンを押した時の1回だけです。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        SizedBox(height: widget.compact ? 8 : 12),
        Container(
          padding: EdgeInsets.all(widget.compact ? 10 : 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: SelectableText(
            prompt,
            key: const Key('landing_trial_generated_prompt'),
            style: TextStyle(
              fontSize: widget.compact ? 13 : 12,
              height: widget.compact ? 1.45 : 1.55,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.compact) ...[
          FilledButton.icon(
            key: const Key('landing_trial_guided_submit'),
            onPressed: () => widget.onSubmit(prompt),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AIに提案してもらう'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('landing_trial_guided_review_back'),
            onPressed: _goBack,
            child: const Text('回答を直す'),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('landing_trial_guided_review_back'),
                  onPressed: _goBack,
                  child: const Text('回答を直す'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('landing_trial_guided_submit'),
                  onPressed: () => widget.onSubmit(prompt),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('この内容でAIに提案してもらう'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
