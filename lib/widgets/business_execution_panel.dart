import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../models/business_execution.dart';
import '../services/business_execution_store.dart';
import '../view_models/business_execution_controller.dart';
import 'business_execution_forms.dart';

/// Mounted with an account key so switching accounts also removes unsaved forms.
class BusinessExecutionPanel extends StatefulWidget {
  const BusinessExecutionPanel({
    super.key,
    required this.userId,
    required this.currentUserId,
    this.store = const LocalBusinessExecutionStore(),
    this.now,
  });

  final String userId;
  final String? Function() currentUserId;
  final BusinessExecutionStore store;
  final DateTime Function()? now;

  @override
  State<BusinessExecutionPanel> createState() => _BusinessExecutionPanelState();
}

class _BusinessExecutionPanelState extends State<BusinessExecutionPanel> {
  late final BusinessExecutionController _controller;
  bool _creating = false;
  String? _selectedId;
  bool _showArchived = false;
  int _archivePage = 0;

  @override
  void initState() {
    super.initState();
    _controller = BusinessExecutionController(
      userId: widget.userId,
      currentUserId: widget.currentUserId,
      store: widget.store,
      now: widget.now,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.direction != ScrollDirection.idle) {
      // Close editing before a user scroll removes its semantics input.
      // Caret scrolling and scrolling inside a multiline field stay focused.
      FocusScope.of(context).unfocus();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (widget.currentUserId() != widget.userId) {
          return const Center(child: Text('アカウントを確認しています。'));
        }
        final selected = _controller.plans
            .where((plan) => plan.id == _selectedId)
            .firstOrNull;
        final active =
            _controller.plans.where((plan) => !plan.archived).toList();
        final archived =
            _controller.plans.where((plan) => plan.archived).toList();
        final visible = _showArchived
            ? archived.reversed.skip(_archivePage * 24).take(24)
            : active.reversed;
        return NotificationListener<UserScrollNotification>(
          onNotification: _handleUserScroll,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  Text(
                    '経営の実行記録',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '課題を成果目標（KPI）と毎日の行動（KDI）に分け、'
                    '実績と振り返りを記録します。担当者はメモとして指定します。',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'このアカウントの記録は、このブラウザー・端末内だけに保存されます。'
                    '履歴やサイトデータの削除で失われます。共同編集・他端末との同期・'
                    '担当者への通知・AIによるタスク実行はありません。'
                    '共用端末には機密情報を入力しないでください。保存にはWeb Locksに対応したHTTPSブラウザーが必要です。',
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/life-goals'),
                    child: const Text('長期の目標を整理する'),
                  ),
                  if (_controller.loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_controller.error != null) ...[
                    Text(
                      _controller.error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    TextButton(
                      onPressed: _controller.saving || _controller.refreshing
                          ? null
                          : _controller.load,
                      child: const Text('保存結果を再読み込み'),
                    ),
                  ],
                  if (_controller.ready && !_controller.loading) ...[
                    if (selected != null) ...[
                      TextButton(
                        onPressed: _controller.saving
                            ? null
                            : () => setState(() => _selectedId = null),
                        child: const Text('計画一覧へ（未保存入力は破棄）'),
                      ),
                      BusinessExecutionDetail(
                        key: ValueKey(selected.id),
                        plan: selected,
                        controller: _controller,
                      ),
                    ] else if (_creating) ...[
                      BusinessExecutionPlanForm(
                        key: const ValueKey('business-execution-plan-form'),
                        now: _controller.now(),
                        saving: _controller.saving || _controller.refreshing,
                        onSave: (plan) async {
                          final saved = await _controller.add(plan);
                          if (mounted && saved) {
                            setState(() {
                              _creating = false;
                              _selectedId = plan.id;
                            });
                          }
                        },
                        onCancel: () => setState(() => _creating = false),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed:
                            active.length >= BusinessExecutionCodec.maxPlans
                                ? null
                                : () => setState(() => _creating = true),
                        icon: const Icon(Icons.add),
                        label: const Text('月の実行計画を作る'),
                      ),
                      const Text(
                        '1計画は同じ月の期間・1担当・1行動です。実行中は24計画まで。'
                        '保存後の目標は固定し、実績と振り返りを更新できます。'
                        '終了した計画は履歴を残してアーカイブできます。'
                        '履歴を含む1000件または保存容量の上限では追加保存を停止します。',
                      ),
                      if (_controller.plans.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('まだ計画がありません。解決したい課題から始めましょう。'),
                        ),
                      TextButton(
                        onPressed: () => setState(() {
                          _showArchived = !_showArchived;
                          _archivePage = 0;
                        }),
                        child: Text(_showArchived ? '実行中の計画を表示' : 'アーカイブを表示'),
                      ),
                      if (_showArchived)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _archivePage == 0
                                  ? null
                                  : () => setState(() => _archivePage--),
                              child: const Text('前の24件'),
                            ),
                            TextButton(
                              onPressed:
                                  (_archivePage + 1) * 24 >= archived.length
                                      ? null
                                      : () => setState(() => _archivePage++),
                              child: const Text('次の24件'),
                            ),
                          ],
                        ),
                      for (final plan in visible)
                        Card(
                          child: ListTile(
                            title: Text(plan.outcome),
                            subtitle: Text(
                              '${plan.owner} / ${plan.startDate}〜${plan.dueDate}\n'
                              '今日までの未入力: '
                              '${plan.missingDates(_controller.now()).length}日',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() => _selectedId = plan.id),
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
