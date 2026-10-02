import 'dart:async';

import 'package:flutter/material.dart';

import '../services/philosophy_funnel_analytics.dart';

class PhilosophyQuickInventory extends StatefulWidget {
  const PhilosophyQuickInventory({
    super.key,
    required this.analytics,
    this.trackViewOnMount = false,
  });

  final PhilosophyFunnelAnalytics analytics;
  final bool trackViewOnMount;

  @override
  State<PhilosophyQuickInventory> createState() =>
      _PhilosophyQuickInventoryState();
}

class _PhilosophyQuickInventoryState extends State<PhilosophyQuickInventory> {
  String? _departmentId;
  String? _actionId;
  String? _feedbackValue;
  String? _unresolvedArea;
  bool _completed = false;
  bool _feedbackSubmitted = false;

  @override
  void initState() {
    super.initState();
    if (widget.trackViewOnMount) {
      unawaited(
        widget.analytics.capture(
          const PhilosophyFunnelEvent(
            stage: PhilosophyFunnelStage.quickInventoryView,
            properties: <String, Object>{
              'path': '/philosophy',
              'entry_mode': 'direct_route',
            },
          ),
        ),
      );
    }
  }

  void _complete() {
    final departmentId = _departmentId;
    final actionId = _actionId;
    if (departmentId == null || actionId == null) return;

    setState(() => _completed = true);
    unawaited(
      widget.analytics.capture(
        PhilosophyFunnelEvent(
          stage: PhilosophyFunnelStage.firstActionComplete,
          properties: <String, Object>{
            'path': '/philosophy',
            'department_id': departmentId,
            'action_id': actionId,
          },
        ),
      ),
    );
  }

  void _submitFeedback() {
    final feedbackValue = _feedbackValue;
    if (feedbackValue == null) return;

    setState(() => _feedbackSubmitted = true);
    unawaited(
      widget.analytics.capture(
        PhilosophyFunnelEvent(
          stage: PhilosophyFunnelStage.feedback,
          properties: <String, Object>{
            'path': '/philosophy',
            'feedback_value': feedbackValue,
            if (_unresolvedArea != null) 'unresolved_area': _unresolvedArea!,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('philosophy_quick_inventory'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4DB6AC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3分棚卸しを始める',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFAFAFA),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '今いちばん整えたい部署と、最初に実行する1件を選びます。入力内容は保存せず、計測には選択肢のIDだけを匿名で送ります。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFCBD5E1),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '1. 今いちばん整えたい部署',
            style: TextStyle(
              color: Color(0xFFFAFAFA),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _departments
                .map(
                  (choice) => ChoiceChip(
                    key: Key('philosophy_department_${choice.id}'),
                    label: Text(choice.label),
                    selected: _departmentId == choice.id,
                    onSelected: (_) => setState(() {
                      _departmentId = choice.id;
                      _completed = false;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            '2. 最初に実行する1件',
            style: TextStyle(
              color: Color(0xFFFAFAFA),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actions
                .map(
                  (choice) => ChoiceChip(
                    key: Key('philosophy_action_${choice.id}'),
                    label: Text(choice.label),
                    selected: _actionId == choice.id,
                    onSelected: (_) => setState(() {
                      _actionId = choice.id;
                      _completed = false;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('philosophy_complete_first_action'),
              onPressed:
                  _departmentId != null && _actionId != null ? _complete : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('この1件で始める'),
            ),
          ),
          if (_completed) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('philosophy_first_action_completed'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x1A4DB6AC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x664DB6AC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '最初の1件が決まりました',
                    style: TextStyle(
                      color: Color(0xFF80CBC4),
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_labelFor(_departments, _departmentId!)}で「${_labelFor(_actions, _actionId!)}」を実行します。',
                    style: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/life-goals'),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('目標として記録する'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '任意フィードバック',
              style: TextStyle(
                color: Color(0xFFFAFAFA),
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _feedbackChoices
                  .map(
                    (choice) => ChoiceChip(
                      key: Key('philosophy_feedback_${choice.id}'),
                      label: Text(choice.label),
                      selected: _feedbackValue == choice.id,
                      onSelected: (_) => setState(() {
                        _feedbackValue = choice.id;
                        _feedbackSubmitted = false;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('philosophy_unresolved_area'),
              initialValue: _unresolvedArea,
              decoration: const InputDecoration(
                labelText: 'まだ迷う点（任意）',
                border: OutlineInputBorder(),
              ),
              items: _unresolvedAreas
                  .map(
                    (choice) => DropdownMenuItem<String>(
                      value: choice.id,
                      child: Text(choice.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _unresolvedArea = value;
                _feedbackSubmitted = false;
              }),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('philosophy_submit_feedback'),
              onPressed: _feedbackValue == null || _feedbackSubmitted
                  ? null
                  : _submitFeedback,
              child: Text(_feedbackSubmitted ? '送信済み' : '匿名で送信'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InventoryChoice {
  const _InventoryChoice(this.id, this.label);

  final String id;
  final String label;
}

String _labelFor(List<_InventoryChoice> choices, String id) =>
    choices.firstWhere((choice) => choice.id == id).label;

const List<_InventoryChoice> _departments = <_InventoryChoice>[
  _InventoryChoice('headquarters', '本社・方針'),
  _InventoryChoice('people', '人事・健康'),
  _InventoryChoice('research', 'R&D・学習'),
  _InventoryChoice('finance', '財務・お金'),
  _InventoryChoice('growth', 'マーケ営業・発信'),
  _InventoryChoice('cross_functional', '横断・生活基盤'),
];

const List<_InventoryChoice> _actions = <_InventoryChoice>[
  _InventoryChoice('stop_one', '今月やめる1件を決める'),
  _InventoryChoice('start_one', '今週始める1件を決める'),
  _InventoryChoice('check_today', '今日確認する1件を決める'),
];

const List<_InventoryChoice> _feedbackChoices = <_InventoryChoice>[
  _InventoryChoice('helpful', '判断に役立った'),
  _InventoryChoice('partly_helpful', '一部役立った'),
  _InventoryChoice('still_unclear', 'まだ迷う'),
];

const List<_InventoryChoice> _unresolvedAreas = <_InventoryChoice>[
  _InventoryChoice('priority', '優先順位'),
  _InventoryChoice('action_size', '行動の小ささ'),
  _InventoryChoice('continuation', '続け方'),
  _InventoryChoice('other', 'その他'),
];
