import 'package:flutter/material.dart';

import '../services/task_clarity_service.dart';

Future<Map<String, String>?> showTaskClarityDialog({
  required BuildContext context,
  required TaskClarityEvaluation evaluation,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TaskClarityDialog(evaluation: evaluation),
  );
}

class TaskClarityDialog extends StatefulWidget {
  final TaskClarityEvaluation evaluation;

  const TaskClarityDialog({super.key, required this.evaluation});

  @override
  State<TaskClarityDialog> createState() => _TaskClarityDialogState();
}

class _TaskClarityDialogState extends State<TaskClarityDialog> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.evaluation.questions.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit =>
      _controllers.every((controller) => controller.text.trim().isNotEmpty);

  void _submit() {
    Navigator.of(context).pop(<String, String>{
      for (var index = 0; index < widget.evaluation.questions.length; index++)
        widget.evaluation.questions[index]: _controllers[index].text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タスクの曖昧さを確認'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('明確さ ${widget.evaluation.score}/10。実行前に不足情報を補ってください。'),
            const SizedBox(height: 16),
            for (var index = 0;
                index < widget.evaluation.questions.length;
                index++) ...[
              TextField(
                key: Key('task_clarity_answer_$index'),
                controller: _controllers[index],
                onChanged: (_) => setState(() {}),
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.evaluation.questions[index],
                  border: const OutlineInputBorder(),
                ),
              ),
              if (index < widget.evaluation.questions.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('task_clarity_cancel_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('あとで確認'),
        ),
        FilledButton(
          key: const Key('task_clarity_submit_button'),
          onPressed: _canSubmit ? _submit : null,
          child: const Text('明確化して保存'),
        ),
      ],
    );
  }
}
