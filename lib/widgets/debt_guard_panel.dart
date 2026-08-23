import 'package:flutter/material.dart';

import '../domain/models/debt_guard_rule.dart';
import '../view_models/debt_guard_view_model.dart';

class DebtGuardPanel extends StatelessWidget {
  const DebtGuardPanel({
    super.key,
    required this.viewModel,
    required this.isLocked,
    required this.isPaidOff,
  });

  final DebtGuardViewModel viewModel;
  final bool isLocked;
  final bool isPaidOff;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final snapshot = viewModel.snapshot;
        return Card(
          key: const Key('debt-guard-panel'),
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, snapshot),
              if (viewModel.isLoading) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFoundationMindset(context),
                    const SizedBox(height: 12),
                    _buildBugMindset(context),
                    const SizedBox(height: 12),
                    _buildSafetyNotice(context),
                    if (viewModel.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildError(context),
                    ],
                    const SizedBox(height: 14),
                    _buildActions(context),
                    const SizedBox(height: 16),
                    _buildCategoryGrid(context, snapshot),
                    if (viewModel.events.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildRecentEvents(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, DebtGuardDailySnapshot snapshot) {
    final colors = Theme.of(context).colorScheme;
    final statusText = isPaidOff
        ? '完済済み・ロック解除'
        : isLocked
            ? '借金残高が0円になるまでロック中'
            : '借金登録後にモードを有効にすると開始';
    return Container(
      padding: const EdgeInsets.all(18),
      color: isPaidOff
          ? const Color(0xFFE8F5E9)
          : isLocked
              ? colors.errorContainer
              : colors.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaidOff ? Icons.lock_open : Icons.shield_outlined,
                color: isPaidOff ? const Color(0xFF2E7D32) : colors.onSurface,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '完済までの禁止事項',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.4,
                  ),
                ),
              ),
              Text(
                '${snapshot.rules.length}項目',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(statusText, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                key: const Key('debt-guard-kept-count'),
                icon: Icons.check_circle_outline,
                label: '守れている ${snapshot.keptCount}',
                color: const Color(0xFF2E7D32),
              ),
              _SummaryChip(
                key: const Key('debt-guard-violated-count'),
                icon: Icons.warning_amber_rounded,
                label: '違反 ${snapshot.violatedCount}',
                color: colors.error,
              ),
              _SummaryChip(
                icon: Icons.hourglass_empty,
                label: '未記録 ${snapshot.unrecordedCount}',
                color: colors.onSurfaceVariant,
              ),
              _SummaryChip(
                icon: Icons.bug_report_outlined,
                label: 'バグを弱めた ${snapshot.bugWeakenedCount}',
                color: colors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              key: const Key('debt-guard-daily-progress'),
              value: snapshot.complianceProgress,
              minHeight: 8,
              backgroundColor: colors.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundationMindset(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final essentialActions =
        DebtGuardFoundationPolicy.essentialActions.join('・');
    return DecoratedBox(
      key: const Key('debt-guard-foundation-mindset'),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              DebtGuardFoundationPolicy.motto,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              DebtGuardFoundationPolicy.dailyFoundationCopy,
              style: TextStyle(fontSize: 12, height: 1.55),
            ),
            const SizedBox(height: 10),
            const Text(
              '先に守る土台（制限しない）',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(essentialActions, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            const Text(
              '毎日の生活基盤チェック',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            const Text(
              DebtGuardFoundationPolicy.routineCopy,
              style: TextStyle(fontSize: 12, height: 1.55),
            ),
            const SizedBox(height: 8),
            for (final cadence in DebtGuardFoundationCadence.values) ...[
              Text(
                cadence.label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                debtGuardFoundationTasks
                    .where((task) => task.cadence == cadence)
                    .map((task) => task.title)
                    .join('・'),
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 2),
            const Text(
              'その後の一歩（必須でない拡大）',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            const Text(
              DebtGuardFoundationPolicy.expansionCopy,
              style: TextStyle(fontSize: 12, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBugMindset(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('debt-guard-bug-mindset'),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bug_report_outlined, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '脳内の虫（バグ）を弱らせる',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '「やってはいけないことをしたい」「すべきことをできない」を、'
                    'あなた自身ではなく一時的な「脳内の虫（バグ）」の命令に見立てます。'
                    '命令に少し従わない、または逆の小さな行動を始めるたびに、'
                    '虫が弱り、やがて死んで消えるイメージです。'
                    'これは行動を切り替えるための動機づけの比喩であり、'
                    '脳が物理的に変化するという説明ではありません。',
                    style: TextStyle(fontSize: 12, height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyNotice(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                DebtGuardFoundationPolicy.safetyCopy,
                style: TextStyle(fontSize: 12, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(child: Text(viewModel.errorMessage!)),
            TextButton(onPressed: viewModel.load, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (isPaidOff) {
      return const Text(
        '完済が確認されたため、このルールは解除されています。記録は履歴として残ります。',
        style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
      );
    }
    if (!viewModel.isAuthenticated) {
      return const Text('ログインすると日々の遵守・衝動・違反を記録できます。');
    }
    if (!isLocked) {
      return const Text('借金台帳を登録し、刑務所モードを有効にすると記録を開始できます。');
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          key: const Key('debt-guard-start-foundation'),
          onPressed: viewModel.isSaving
              ? null
              : () => _showUrgeDialog(
                    context,
                    initialMode: _BugResponseMode.startRequiredAction,
                  ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('まず生活を1つ整える'),
        ),
        FilledButton.tonalIcon(
          key: const Key('debt-guard-check-in-all'),
          onPressed: viewModel.isSaving ? null : () => _checkInAll(context),
          icon: const Icon(Icons.done_all),
          label: const Text('全項目、ここまで守った'),
        ),
        FilledButton.tonalIcon(
          key: const Key('debt-guard-urge-help'),
          onPressed: viewModel.isSaving ? null : () => _showUrgeDialog(context),
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('脳内バグが出た'),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context,
    DebtGuardDailySnapshot snapshot,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final twoColumns = constraints.maxWidth >= 760;
        final cardWidth = twoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final category in DebtGuardCategory.values)
              SizedBox(
                key: Key('debt-guard-category-${category.name}'),
                width: cardWidth,
                child: _buildCategoryCard(context, category, snapshot),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    DebtGuardCategory category,
    DebtGuardDailySnapshot snapshot,
  ) {
    final rules = snapshot.rules
        .where((rule) => rule.category == category)
        .toList(growable: false);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        initiallyExpanded: true,
        maintainState: true,
        leading: Icon(_categoryIcon(category)),
        title: Text(
          category.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${rules.length}項目'),
        children: [
          for (final rule in rules) _buildRuleTile(context, rule, snapshot),
        ],
      ),
    );
  }

  Widget _buildRuleTile(
    BuildContext context,
    DebtGuardRule rule,
    DebtGuardDailySnapshot snapshot,
  ) {
    final status = snapshot.statusFor(rule.id);
    final statusColor = switch (status) {
      DebtGuardRuleStatus.kept => const Color(0xFF2E7D32),
      DebtGuardRuleStatus.violated => Theme.of(context).colorScheme.error,
      DebtGuardRuleStatus.unrecorded => Theme.of(
          context,
        ).colorScheme.onSurfaceVariant,
    };
    final statusIcon = switch (status) {
      DebtGuardRuleStatus.kept => Icons.check_circle,
      DebtGuardRuleStatus.violated => Icons.error,
      DebtGuardRuleStatus.unrecorded => Icons.radio_button_unchecked,
    };
    final statusLabel = switch (status) {
      DebtGuardRuleStatus.kept => '今日ここまで遵守',
      DebtGuardRuleStatus.violated => '今日は違反あり',
      DebtGuardRuleStatus.unrecorded => '今日の記録なし',
    };
    return ListTile(
      key: Key('debt-guard-rule-${rule.id}'),
      dense: true,
      contentPadding: const EdgeInsets.only(left: 16, right: 6),
      leading: Icon(statusIcon, color: statusColor, size: 21),
      title: Text(
        rule.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        rule.detail == null ? statusLabel : '${rule.detail}\n$statusLabel',
        style: const TextStyle(height: 1.45),
      ),
      isThreeLine: rule.detail != null,
      trailing: isPaidOff
          ? const Icon(Icons.lock_open, size: 20)
          : PopupMenuButton<_RuleAction>(
              tooltip: '${rule.title}を記録',
              enabled:
                  isLocked && viewModel.isAuthenticated && !viewModel.isSaving,
              onSelected: (action) => _handleRuleAction(context, rule, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _RuleAction.checkIn,
                  child: Text('ここまで守った'),
                ),
                PopupMenuItem(
                  value: _RuleAction.urge,
                  child: Text('脳内バグに対処する'),
                ),
                PopupMenuItem(
                  value: _RuleAction.violation,
                  child: Text('違反を記録'),
                ),
              ],
            ),
    );
  }

  Widget _buildRecentEvents(BuildContext context) {
    final recent = viewModel.events.reversed.take(5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日の直近記録',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        for (final event in recent)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_eventIcon(event.type), size: 20),
            title: Text(
              '${_ruleTitle(event.ruleId)} — ${event.type.label}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: event.note?.isNotEmpty == true ? Text(event.note!) : null,
            trailing: Text(
              TimeOfDay.fromDateTime(event.createdAt.toLocal()).format(context),
            ),
          ),
      ],
    );
  }

  Future<void> _handleRuleAction(
    BuildContext context,
    DebtGuardRule rule,
    _RuleAction action,
  ) async {
    switch (action) {
      case _RuleAction.checkIn:
        await _record(
          context,
          ruleId: rule.id,
          type: DebtGuardEventType.checkIn,
        );
      case _RuleAction.urge:
        await _showUrgeDialog(context, rule: rule);
      case _RuleAction.violation:
        await _showViolationDialog(context, rule);
    }
  }

  Future<void> _checkInAll(BuildContext context) async {
    final success = await viewModel.checkInAllUnrecorded();
    if (!context.mounted) return;
    _showResult(context, success, success ? '全項目をここまで守ったと記録しました。' : null);
  }

  Future<void> _showUrgeDialog(
    BuildContext context, {
    DebtGuardRule? rule,
    _BugResponseMode initialMode = _BugResponseMode.resistProhibitedAction,
  }) async {
    final result = await _showActionDialog(
      context,
      fixedRule: rule,
      showPausePlan: true,
      initialBugMode: initialMode,
    );
    if (result == null || !context.mounted) return;
    await _record(
      context,
      ruleId: result.ruleId,
      type: result.type,
      note: result.note,
    );
  }

  Future<void> _showViolationDialog(
    BuildContext context,
    DebtGuardRule rule,
  ) async {
    final result = await _showActionDialog(
      context,
      fixedRule: rule,
      showPausePlan: false,
    );
    if (result == null || !context.mounted) return;
    await _record(
      context,
      ruleId: result.ruleId,
      type: result.type,
      note: result.note,
    );
  }

  Future<_DebtGuardActionResult?> _showActionDialog(
    BuildContext context, {
    required DebtGuardRule? fixedRule,
    required bool showPausePlan,
    _BugResponseMode initialBugMode = _BugResponseMode.resistProhibitedAction,
  }) async {
    var selectedRuleId = fixedRule?.id ?? debtGuardRules.first.id;
    final requiredActionRules = debtGuardRules
        .where((rule) => rule.requiredAction != null)
        .toList(growable: false);
    var requiredActionRuleId = fixedRule?.requiredAction != null
        ? fixedRule!.id
        : requiredActionRules.first.id;
    var bugMode = initialBugMode;
    final noteController = TextEditingController();
    try {
      return await showDialog<_DebtGuardActionResult>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final isRequiredActionMode = showPausePlan &&
                bugMode == _BugResponseMode.startRequiredAction;
            final fixedRuleForMode = fixedRule != null &&
                    (!isRequiredActionMode || fixedRule.requiredAction != null)
                ? fixedRule
                : null;
            final activeRuleId = fixedRuleForMode?.id ??
                (isRequiredActionMode ? requiredActionRuleId : selectedRuleId);
            final activeRule = _ruleFor(activeRuleId);
            final successType = isRequiredActionMode
                ? DebtGuardEventType.requiredActionStarted
                : DebtGuardEventType.urgeResisted;
            final selectableRules =
                isRequiredActionMode ? requiredActionRules : debtGuardRules;
            return AlertDialog(
              title: Text(
                showPausePlan
                    ? isRequiredActionMode
                        ? '生活を1つ整える'
                        : '脳内バグ退治'
                    : '違反を記録',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showPausePlan) ...[
                        const Text(
                          'いまの衝動や抵抗を、あなた自身ではなく一時的な'
                          '「脳内の虫（バグ）」の命令に見立てます。'
                          'これは動機づけの比喩です。'
                          '命令と逆の安全な行動を1回するたびに、虫は弱ります。',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const Key('bug-mode-resist'),
                              selected: !isRequiredActionMode,
                              label: const Text('してはいけないことをしたい'),
                              onSelected: (_) => setDialogState(
                                () => bugMode =
                                    _BugResponseMode.resistProhibitedAction,
                              ),
                            ),
                            ChoiceChip(
                              key: const Key('bug-mode-start'),
                              selected: isRequiredActionMode,
                              label: const Text('すべきことをできない'),
                              onSelected: (_) => setDialogState(
                                () => bugMode =
                                    _BugResponseMode.startRequiredAction,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (fixedRuleForMode == null)
                        DropdownButtonFormField<String>(
                          key: ValueKey(bugMode),
                          initialValue: activeRuleId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                isRequiredActionMode ? 'いま着手すること' : 'いま我慢すること',
                          ),
                          items: [
                            for (final item in selectableRules)
                              DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  item.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              if (isRequiredActionMode) {
                                requiredActionRuleId = value;
                              } else {
                                selectedRuleId = value;
                              }
                            });
                          },
                        )
                      else
                        Text(
                          fixedRuleForMode.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      if (showPausePlan) ...[
                        const SizedBox(height: 14),
                        Text(
                          isRequiredActionMode
                              ? 'バグの「後でやる」を無視して、反対行動を始める'
                              : 'バグの「今すぐやれ」を無視して、少し待つ',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isRequiredActionMode
                              ? '1. 「後でやる」はバグの命令だと声に出す\n'
                                  '2. ${activeRule.requiredAction ?? '安全な最小行動を1つだけ決める'}\n'
                                  '3. 考える前に、安全な範囲で2分だけ無理やり始める\n'
                                  '4. 着手できたら記録する。反対行動のたびに虫は弱る'
                              : '1. 「これはバグの命令」と声に出す\n'
                                  '2. 決済・SNS・動画などの画面を閉じ、その場を離れる\n'
                                  '3. 水を飲み、まず10分待つ。待つほど虫は弱る\n'
                                  '4. 借金残高を見る。必要なら支援者へ連絡する',
                          style: const TextStyle(height: 1.55),
                        ),
                        if (isRequiredActionMode) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '強い痛み・体調不良・危険がある場合は無理に行わず、'
                            '休息・医療・支援を優先してください。',
                            style: TextStyle(fontSize: 12, height: 1.45),
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: noteController,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: showPausePlan
                              ? isRequiredActionMode
                                  ? '始めたこと・次の一歩（任意）'
                                  : 'きっかけ・代わりにする行動（任意）'
                              : '何があったか（任意）',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('キャンセル'),
                ),
                if (showPausePlan)
                  TextButton(
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      _DebtGuardActionResult(
                        ruleId: activeRuleId,
                        type: DebtGuardEventType.violation,
                        note: noteController.text,
                      ),
                    ),
                    child: Text(
                      isRequiredActionMode ? '今日はできなかった' : '違反を記録',
                    ),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _DebtGuardActionResult(
                      ruleId: activeRuleId,
                      type: showPausePlan
                          ? successType
                          : DebtGuardEventType.violation,
                      note: noteController.text,
                    ),
                  ),
                  child: Text(showPausePlan ? 'バグを弱めた' : '記録する'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _record(
    BuildContext context, {
    required String ruleId,
    required DebtGuardEventType type,
    String? note,
  }) async {
    final success = await viewModel.record(
      ruleId: ruleId,
      type: type,
      note: note,
    );
    if (!context.mounted) return;
    _showResult(context, success, success ? type.label : null);
  }

  void _showResult(BuildContext context, bool success, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? message! : viewModel.errorMessage ?? '保存できませんでした。',
        ),
      ),
    );
  }

  static IconData _categoryIcon(DebtGuardCategory category) =>
      switch (category) {
        DebtGuardCategory.debt => Icons.credit_card_off_outlined,
        DebtGuardCategory.food => Icons.no_food_outlined,
        DebtGuardCategory.nightlife => Icons.nightlife_outlined,
        DebtGuardCategory.digital => Icons.phone_android_outlined,
        DebtGuardCategory.gambling => Icons.casino_outlined,
        DebtGuardCategory.homeCare => Icons.home_outlined,
        DebtGuardCategory.substances => Icons.smoke_free_outlined,
        DebtGuardCategory.sexualBehavior => Icons.self_improvement_outlined,
        DebtGuardCategory.impulse => Icons.psychology_outlined,
      };

  static IconData _eventIcon(DebtGuardEventType type) => switch (type) {
        DebtGuardEventType.checkIn => Icons.check_circle_outline,
        DebtGuardEventType.urgeResisted => Icons.shield_outlined,
        DebtGuardEventType.requiredActionStarted => Icons.play_arrow_rounded,
        DebtGuardEventType.violation => Icons.warning_amber_rounded,
      };

  static DebtGuardRule _ruleFor(String ruleId) {
    return debtGuardRules.firstWhere((rule) => rule.id == ruleId);
  }

  static String _ruleTitle(String ruleId) {
    for (final rule in debtGuardRules) {
      if (rule.id == ruleId) return rule.title;
    }
    return '禁止事項';
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RuleAction { checkIn, urge, violation }

enum _BugResponseMode { resistProhibitedAction, startRequiredAction }

class _DebtGuardActionResult {
  const _DebtGuardActionResult({
    required this.ruleId,
    required this.type,
    required this.note,
  });

  final String ruleId;
  final DebtGuardEventType type;
  final String note;
}
