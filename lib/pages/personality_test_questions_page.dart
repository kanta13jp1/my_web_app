import 'package:flutter/material.dart';
import '../services/personality_test_service.dart';
import '../models/personality_test.dart';
import 'personality_test_result_page.dart';

/// 性格診断の質問ページ
class PersonalityTestQuestionsPage extends StatefulWidget {
  final int testId;

  const PersonalityTestQuestionsPage({
    super.key,
    required this.testId,
  });

  @override
  State<PersonalityTestQuestionsPage> createState() =>
      _PersonalityTestQuestionsPageState();
}

class _PersonalityTestQuestionsPageState
    extends State<PersonalityTestQuestionsPage> {
  final PersonalityTestService _service = PersonalityTestService();
  List<PersonalityQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final Map<int, String> _answers = {}; // questionId -> answer (A or B)

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _service.getQuestions();
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('質問の読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _answerQuestion(String answer) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final question = _questions[_currentQuestionIndex];

      // 回答を保存
      await _service.saveAnswer(
        testId: widget.testId,
        questionId: question.id,
        answer: answer,
      );

      // 回答をローカルに記録
      _answers[question.id] = answer;

      // 次の質問へ進む、または結果ページへ
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _isSubmitting = false;
        });
      } else {
        // 全質問完了 - スコアを計算して結果ページへ
        await _completeTest();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('回答の保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _completeTest() async {
    try {
      // スコアを計算
      final scores = await _service.calculateScores(widget.testId);

      // 性格タイプを判定
      final personalityType = _service.determinePersonalityType(scores);

      // テストを完了
      await _service.completeTest(widget.testId, personalityType);

      // 結果ページへ遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PersonalityTestResultPage(
              testId: widget.testId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('診断の完了に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _goToPreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('性格診断'),
        ),
        body: const Center(
          child: Text('質問が見つかりませんでした'),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('質問 ${_currentQuestionIndex + 1} / ${_questions.length}'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // プログレスバー
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${(progress * 100).toInt()}% 完了',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),

          // 質問と選択肢
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 質問テキスト
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        question.text,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 選択肢A
                  _AnswerButton(
                    label: 'A',
                    text: question.optionA,
                    onPressed: _isSubmitting
                        ? null
                        : () => _answerQuestion('A'),
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),

                  // 選択肢B
                  _AnswerButton(
                    label: 'B',
                    text: question.optionB,
                    onPressed: _isSubmitting
                        ? null
                        : () => _answerQuestion('B'),
                    color: colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),

          // 戻るボタン
          if (_currentQuestionIndex > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : _goToPreviousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text('前の質問に戻る'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 回答ボタン
class _AnswerButton extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback? onPressed;
  final Color color;

  const _AnswerButton({
    required this.label,
    required this.text,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;

    return Card(
      elevation: isEnabled ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled
              ? color.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? color.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isEnabled
                          ? color
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: isEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
