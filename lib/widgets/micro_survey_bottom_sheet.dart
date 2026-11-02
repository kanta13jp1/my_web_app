import 'package:flutter/material.dart';
import 'package:my_web_app/models/micro_survey.dart';
import 'package:my_web_app/services/micro_survey_controller.dart';
import 'package:my_web_app/services/micro_survey_repository.dart';

Future<void> presentMicroSurveyIfEligible({
  required BuildContext context,
  required MicroSurveyRepository repository,
  required MicroSurveyContext surveyContext,
}) async {
  final controller = MicroSurveyController(repository: repository);
  try {
    final shouldPresent = await controller.shouldPresent(surveyContext);
    if (!shouldPresent || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MicroSurveyBottomSheet(
        controller: controller,
        surveyContext: surveyContext,
      ),
    );
  } finally {
    controller.dispose();
  }
}

class MicroSurveyBottomSheet extends StatefulWidget {
  const MicroSurveyBottomSheet({
    required this.controller,
    required this.surveyContext,
    super.key,
  });

  final MicroSurveyController controller;
  final MicroSurveyContext surveyContext;

  @override
  State<MicroSurveyBottomSheet> createState() => _MicroSurveyBottomSheetState();
}

class _MicroSurveyBottomSheetState extends State<MicroSurveyBottomSheet> {
  final _commentController = TextEditingController();
  int? _rating;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rating = _rating;
    if (rating == null) return;
    final saved = await widget.controller.submit(
      widget.surveyContext,
      MicroSurveyAnswer(
        rating: rating,
        comment: _commentController.text,
      ),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _optOut() async {
    final saved = await widget.controller.optOut();
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'かんたんフィードバック',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '操作直後の感想を、2問だけお聞かせください。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '1. この操作はスムーズでしたか？',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(5, (index) {
                        final value = index + 1;
                        return Semantics(
                          label: '評価$value、5段階中',
                          selected: _rating == value,
                          child: ChoiceChip(
                            key: Key('microSurveyRating$value'),
                            label: Text('$value'),
                            selected: _rating == value,
                            onSelected: controller.isSubmitting
                                ? null
                                : (_) => setState(() => _rating = value),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      key: const Key('microSurveyComment'),
                      controller: _commentController,
                      enabled: !controller.isSubmitting,
                      maxLength: 280,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '2. よろしければ理由を教えてください（任意）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        controller.errorMessage!,
                        key: const Key('microSurveyError'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('microSurveySubmit'),
                      onPressed: _rating == null || controller.isSubmitting
                          ? null
                          : _submit,
                      child: controller.isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('送信'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: controller.isSubmitting ? null : _optOut,
                          child: const Text('今後表示しない'),
                        ),
                        TextButton(
                          onPressed: controller.isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('あとで'),
                        ),
                      ],
                    ),
                    Text(
                      '操作の種類と画面だけを回答に紐付けます。名前・入力内容・IDは収集しません。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
