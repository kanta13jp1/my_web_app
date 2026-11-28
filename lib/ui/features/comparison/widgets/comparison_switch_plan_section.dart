import 'package:flutter/material.dart';

class ComparisonSwitchPlanStep {
  const ComparisonSwitchPlanStep({
    required this.number,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String number;
  final String title;
  final String body;
  final Color accent;
}

class ComparisonSwitchPlanSection extends StatelessWidget {
  const ComparisonSwitchPlanSection({
    super.key,
    required this.accentColor,
    required this.stepOneTitle,
    required this.stepOneBody,
    required this.primaryButton,
    required this.secondaryButton,
    this.verifiedNote,
  });

  static const sectionKey = Key('comparison-switch-plan-section');

  static const Color _surfacePrimary = Color(0xFF141821);
  static const Color _surfaceSecondary = Color(0xFF1A202C);
  static const Color _borderColor = Color(0xFF283042);
  static const Color _textPrimary = Color(0xFFF5F7FB);
  static const Color _textSecondary = Color(0xFFA8B3C7);
  static const Color _indigo = Color(0xFF3D5AFE);
  static const Color _orange = Color(0xFFFF6B35);

  final Color accentColor;
  final String stepOneTitle;
  final String stepOneBody;
  final Widget primaryButton;
  final Widget secondaryButton;
  final String? verifiedNote;

  @override
  Widget build(BuildContext context) {
    final steps = <ComparisonSwitchPlanStep>[
      ComparisonSwitchPlanStep(
        number: '01',
        title: stepOneTitle,
        body: stepOneBody,
        accent: accentColor,
      ),
      const ComparisonSwitchPlanStep(
        number: '02',
        title: '今日の最重要タスクを AI に任せる',
        body: 'ノート・タスク・習慣・財務を横断して、今やるべき1件を先に見つけられます。',
        accent: _indigo,
      ),
      const ComparisonSwitchPlanStep(
        number: '03',
        title: '必要になった機能だけ横に増やす',
        body: '資産管理・AI大学・部署AIまで、必要になった機能を後から同じアプリ内で広げられます。',
        accent: _orange,
      ),
    ];

    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surfacePrimary,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '乗り換えの進め方',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.72,
                    color: _textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '一気に全部を置き換えなくても大丈夫です。まず入口をひとつにして、そこから必要な機能を足していけます。',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                    height: 1.7,
                  ),
                ),
                if (verifiedNote != null && verifiedNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    verifiedNote!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        children: steps
                            .map(
                              (step) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _StepCard(step: step),
                              ),
                            )
                            .toList(),
                      );
                    }

                    return Row(
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          Expanded(child: _StepCard(step: steps[i])),
                          if (i != steps.length - 1) const SizedBox(width: 12),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    primaryButton,
                    secondaryButton,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final ComparisonSwitchPlanStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ComparisonSwitchPlanSection._surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: step.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: step.accent,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ComparisonSwitchPlanSection._textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: const TextStyle(
              fontSize: 13,
              color: ComparisonSwitchPlanSection._textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
