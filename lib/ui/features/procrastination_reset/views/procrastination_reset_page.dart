import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/procrastination_reset_models.dart';
import '../view_models/procrastination_reset_view_model.dart';

class ProcrastinationResetPage extends StatefulWidget {
  const ProcrastinationResetPage({super.key});

  @override
  State<ProcrastinationResetPage> createState() =>
      _ProcrastinationResetPageState();
}

class _ProcrastinationResetPageState extends State<ProcrastinationResetPage> {
  static const _wideBreakpoint = 900.0;

  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  final _actionController = TextEditingController();
  final _firstMoveController = TextEditingController();
  DistractionBarrier _barrier = DistractionBarrier.anotherRoom;

  @override
  void dispose() {
    _taskController.dispose();
    _actionController.dispose();
    _firstMoveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ProcrastinationResetViewModel>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('先延ばしリセット')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return switch (viewModel.loadStatus) {
              ProcrastinationResetLoadStatus.initial ||
              ProcrastinationResetLoadStatus.loading =>
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ProcrastinationResetLoadStatus.failure => _LoadFailure(
                  message: viewModel.errorMessage,
                  onRetry: viewModel.load,
                ),
              ProcrastinationResetLoadStatus.ready => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        colors.primaryContainer.withValues(alpha: 0.32),
                        colors.surface,
                        colors.tertiaryContainer.withValues(alpha: 0.24),
                      ],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= _wideBreakpoint;
                      final intro = _buildIntro(context, viewModel);
                      final action = viewModel.session == null
                          ? _buildPlanner(context, viewModel)
                          : _buildActiveSession(context, viewModel);
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 32 : 16,
                          vertical: 24,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: wide
                                ? Row(
                                    key:
                                        const Key('procrastination-reset-wide'),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      SizedBox(width: 360, child: intro),
                                      const SizedBox(width: 28),
                                      Expanded(child: action),
                                    ],
                                  )
                                : Column(
                                    key: const Key(
                                      'procrastination-reset-narrow',
                                    ),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      intro,
                                      const SizedBox(height: 20),
                                      action,
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            };
          },
        ),
      ),
    );
  }

  Widget _buildIntro(
    BuildContext context,
    ProcrastinationResetViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '意志力を使わず、着手を軽くする',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '大きなタスクを、\n5分の行動に変える。',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '先延ばしを性格のせいにせず、始める直前の摩擦を3つの構造で小さくします。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        const _PrincipleTile(
          number: '1',
          title: '5分で終わる数字へ',
          description: '「記事を書く」ではなく「タイトル案を3つ書く」まで小さくします。',
          icon: Icons.timer_outlined,
        ),
        const SizedBox(height: 12),
        const _PrincipleTile(
          number: '2',
          title: '最初の一手は一動作',
          description: '「ファイルを開く」のように、迷わず実行できる動詞1つへ固定します。',
          icon: Icons.touch_app_outlined,
        ),
        const SizedBox(height: 12),
        const _PrincipleTile(
          number: '3',
          title: '誘惑は環境から遠ざける',
          description: 'スマホや通知を視界と手の届く範囲から外して、判断回数を減らします。',
          icon: Icons.phonelink_erase_outlined,
        ),
        if (viewModel.completedCount > 0) ...<Widget>[
          const SizedBox(height: 20),
          Card(
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.local_fire_department, color: colors.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'これまで ${viewModel.completedCount} 回、最初の一歩を完了しました。',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlanner(
    BuildContext context,
    ProcrastinationResetViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '今日の5分プラン',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '完璧な計画ではなく、今すぐ始められる大きさを作ります。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('procrastination-task-field'),
                controller: _taskController,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '先延ばししていること',
                  hintText: '例：記事を書く',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('procrastination-action-field'),
                controller: _actionController,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '5分で終わる行動',
                  hintText: '例：タイトル案を3つ書く',
                  prefixIcon: Icon(Icons.timer_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('procrastination-first-move-field'),
                controller: _firstMoveController,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _createPlan(viewModel),
                decoration: const InputDecoration(
                  labelText: '最初の一動作',
                  hintText: '例：メモを開く',
                  prefixIcon: Icon(Icons.play_arrow_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              Text(
                '誘惑を遠ざける方法',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DistractionBarrier.values.map((barrier) {
                  return ChoiceChip(
                    key: Key('barrier-${barrier.name}'),
                    label: Text(_barrierLabel(barrier)),
                    selected: _barrier == barrier,
                    onSelected: (_) => setState(() => _barrier = barrier),
                  );
                }).toList(growable: false),
              ),
              if (viewModel.errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                _ErrorBanner(message: viewModel.errorMessage!),
              ],
              if (viewModel.lastCompletedAction != null) ...<Widget>[
                const SizedBox(height: 16),
                _CompletionBanner(
                  action: viewModel.lastCompletedAction!,
                  onDismiss: viewModel.clearCompletionNotice,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('create-procrastination-plan'),
                onPressed:
                    viewModel.isSaving ? null : () => _createPlan(viewModel),
                icon: const Icon(Icons.bolt),
                label: Text(viewModel.isSaving ? '保存中…' : '実行プランを作る'),
              ),
              const SizedBox(height: 12),
              Text(
                'プランと完了回数はこの端末内だけに保存されます。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSession(
    BuildContext context,
    ProcrastinationResetViewModel viewModel,
  ) {
    final session = viewModel.session!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = 1 -
        (viewModel.remainingSeconds /
            ProcrastinationResetViewModel.sessionDurationSeconds);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'いまやること',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.task,
                        key: const Key('active-procrastination-task'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'プランを作り直す',
                  onPressed:
                      viewModel.isSaving ? null : () => _resetPlan(viewModel),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _ActionStep(
              number: '1',
              label: '最初の一動作',
              value: session.firstMove,
              emphasized: !session.hasStarted,
            ),
            const SizedBox(height: 12),
            _ActionStep(
              number: '2',
              label: '5分だけやる',
              value: session.fiveMinuteAction,
              emphasized: session.hasStarted,
            ),
            const SizedBox(height: 12),
            _ActionStep(
              number: '3',
              label: '環境を先に変える',
              value: _barrierLabel(session.barrier),
              emphasized: false,
            ),
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 176,
                height: 176,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        strokeWidth: 10,
                        value: progress,
                        backgroundColor: colors.surfaceContainerHighest,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _formatDuration(viewModel.remainingSeconds),
                          key: const Key('procrastination-timer'),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        Text(
                          session.hasStarted ? '5分だけ続ける' : '最初の一手から',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!session.hasStarted)
              FilledButton.icon(
                key: const Key('start-procrastination-session'),
                onPressed:
                    viewModel.isSaving ? null : () => viewModel.startSession(),
                icon: const Icon(Icons.play_arrow),
                label: Text('「${session.firstMove}」をやる'),
              )
            else ...<Widget>[
              if (viewModel.isTimerComplete)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '5分経過しました。続けても、ここで終えても大丈夫です。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              FilledButton.icon(
                key: const Key('complete-procrastination-session'),
                onPressed:
                    viewModel.isSaving ? null : () => _completePlan(viewModel),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('できた'),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '一手だけでやめてもOK。始めた事実を成功として記録します。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (viewModel.errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              _ErrorBanner(message: viewModel.errorMessage!),
            ],
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty ? '入力してください' : null;
  }

  Future<void> _createPlan(ProcrastinationResetViewModel viewModel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await viewModel.createPlan(
      task: _taskController.text,
      fiveMinuteAction: _actionController.text,
      firstMove: _firstMoveController.text,
      barrier: _barrier,
    );
  }

  Future<void> _completePlan(ProcrastinationResetViewModel viewModel) async {
    final completed = await viewModel.completeSession();
    if (!mounted || !completed) return;
    _taskController.clear();
    _actionController.clear();
    _firstMoveController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('最初の一歩を完了として記録しました。')));
  }

  Future<void> _resetPlan(ProcrastinationResetViewModel viewModel) async {
    final reset = await viewModel.resetSession();
    if (!mounted || !reset) return;
    _taskController.clear();
    _actionController.clear();
    _firstMoveController.clear();
  }
}

class _PrincipleTile extends StatelessWidget {
  const _PrincipleTile({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$number. $title',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionStep extends StatelessWidget {
  const _ActionStep({
    required this.number,
    required this.label,
    required this.value,
    required this.emphasized,
  });

  final String number;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasized ? colors.primaryContainer : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasized ? colors.primary : colors.outlineVariant,
          width: emphasized ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: emphasized ? colors.primary : colors.surface,
            foregroundColor: emphasized ? colors.onPrimary : colors.onSurface,
            child: Text(number),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.sync_problem, size: 48),
            const SizedBox(height: 16),
            Text(message ?? '読み込めませんでした。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.action, required this.onDismiss});

  final String action;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle, color: colors.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '「$action」を完了。達成感を次の行動につなげましょう。',
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
          ),
          IconButton(
            tooltip: '閉じる',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

String _barrierLabel(DistractionBarrier barrier) {
  return switch (barrier) {
    DistractionBarrier.anotherRoom => 'スマホを別の部屋へ置く',
    DistractionBarrier.outOfSight => 'スマホを引き出しへしまう',
    DistractionBarrier.notificationsOff => '通知と不要なタブを閉じる',
  };
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remaining.toString().padLeft(2, '0')}';
}
