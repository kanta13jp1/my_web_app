import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI ゴール分解カード。
///
/// ユーザーがゴールを入力すると、12部署に対応するサブタスクに
/// 自動分解して AI エージェントに配布する。
/// X ポストの「1つのゴールに対して部署毎に内容が被らない」を実現。
class GoalDecomposerCard extends StatefulWidget {
  const GoalDecomposerCard({super.key});

  @override
  State<GoalDecomposerCard> createState() => _GoalDecomposerCardState();
}

class _GoalDecomposerCardState extends State<GoalDecomposerCard> {
  final _goalController = TextEditingController();
  bool _expanded = false;
  bool _loading = false;
  List<_DeptTask> _preview = [];
  bool _assigned = false;

  // 12 部署と担当サブタスクのテンプレートマップ
  static const _deptTemplates = <_DeptDef>[
    _DeptDef(
      'CEO室',
      'ceo',
      Icons.business_center,
      Color(0xFF4F46E5),
      '全体方針策定・ゴール承認・優先度決定',
    ),
    _DeptDef(
      '企画部',
      'planning-director',
      Icons.lightbulb,
      Color(0xFFF59E0B),
      '施策アイデア立案・ロードマップ策定',
    ),
    _DeptDef(
      '開発部',
      'cto',
      Icons.code,
      Color(0xFF10B981),
      '技術実装・アーキテクチャ設計・デプロイ',
    ),
    _DeptDef(
      'CMO室',
      'cmo',
      Icons.campaign,
      Color(0xFFEC4899),
      'マーケティング戦略・SNS・広告クリエイティブ',
    ),
    _DeptDef(
      '広報部',
      'pr-director',
      Icons.newspaper,
      Color(0xFF06B6D4),
      'プレスリリース・ブログ投稿・Build in Public',
    ),
    _DeptDef(
      '営業部',
      'sales-director',
      Icons.handshake,
      Color(0xFF8B5CF6),
      'リード獲得・デモ・クロージング',
    ),
    _DeptDef(
      'CS部',
      'cs-director',
      Icons.support_agent,
      Color(0xFF0EA5E9),
      'ユーザーサポート・フィードバック収集・FAQ整備',
    ),
    _DeptDef(
      'CFO室',
      'cfo',
      Icons.account_balance,
      Color(0xFF64748B),
      '予算確保・コスト試算・財務インパクト評価',
    ),
    _DeptDef(
      'CHRO室',
      'chro',
      Icons.people,
      Color(0xFF14B8A6),
      '採用計画・スキルアップ・チームカルチャー',
    ),
    _DeptDef(
      'CHO室',
      'cho',
      Icons.favorite,
      Color(0xFFEF4444),
      'メンバー健康管理・モチベーション維持',
    ),
    _DeptDef(
      '法務部',
      'legal-director',
      Icons.gavel,
      Color(0xFF78716C),
      'リスク審査・利用規約・コンプライアンス確認',
    ),
    _DeptDef(
      '調達部',
      'procurement-director',
      Icons.inventory,
      Color(0xFF84CC16),
      'ツール・リソース調達・外部委託',
    ),
  ];

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _generatePreview() {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) return;

    setState(() {
      _assigned = false;
      _preview = _deptTemplates.map((dept) {
        return _DeptTask(dept: dept, task: '${dept.defaultTask} — 目標: $goal');
      }).toList();
    });
  }

  Future<void> _assignTasks() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty || _preview.isEmpty) return;

    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      // CEO を supervisor として取得 (agents テーブル)
      final ceoRows = await supabase
          .from('agents')
          .select('id')
          .eq('slug', 'ceo')
          .eq('user_id', uid)
          .limit(1);
      final ceoId = ((ceoRows as List).isNotEmpty)
          ? ceoRows.first['id']?.toString()
          : null;
      if (ceoId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // agent_tasks テーブルに各部署長へのタスクを登録
      for (final item in _preview) {
        // 部署長の agent_id をスラッグで検索
        final agentRows = await supabase
            .from('agents')
            .select('id')
            .eq('slug', item.dept.managerSlug)
            .eq('user_id', uid)
            .limit(1);

        if ((agentRows as List).isEmpty) continue;
        final agentId = agentRows.first['id']?.toString();
        if (agentId == null) continue;

        await supabase.from('agent_tasks').insert(<String, dynamic>{
          'user_id': uid,
          'supervisor_agent_id': ceoId,
          'assignee_agent_id': agentId,
          'title':
              '[ゴール] ${item.task.length > 60 ? item.task.substring(0, 60) : item.task}',
          'description': '## ゴール\n$goal\n\n## 担当タスク\n${item.task}',
          'status': 'queued',
          'task_type': 'goal_subtask',
          'source': 'goal_decomposer',
        });
      }

      if (mounted) {
        setState(() {
          _assigned = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // ヘッダー
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      size: 20,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI ゴール分解 (12部署へ配布)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ゴールを入力 → 部署別サブタスクに自動分解',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: isDark
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF757575),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ゴール入力
                  TextField(
                    controller: _goalController,
                    decoration: InputDecoration(
                      hintText: '例: ユーザー数を100人にする / 技術ブログを毎日投稿する',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFFBDBDBD),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('12部署のサブタスクをプレビュー'),
                      onPressed: _generatePreview,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),

                  // プレビュー表示
                  if (_preview.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '部署別タスク分解プレビュー',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._preview.map((item) => _DeptTaskRow(item: item)),
                    const SizedBox(height: 12),
                    if (_assigned)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '12部署にタスクを配布しました！ AI 組織 OS で進捗を確認できます。',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: _loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, size: 16),
                          label: Text(
                            _loading ? '配布中...' : '12部署にタスクを配布する',
                          ),
                          onPressed: _loading ? null : _assignTasks,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeptTaskRow extends StatelessWidget {
  const _DeptTaskRow({required this.item});
  final _DeptTask item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: item.dept.color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item.dept.icon, size: 14, color: item.dept.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.dept.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: item.dept.color,
                  ),
                ),
                Text(
                  item.task,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptDef {
  final String name;
  final String managerSlug;
  final IconData icon;
  final Color color;
  final String defaultTask;

  const _DeptDef(
    this.name,
    this.managerSlug,
    this.icon,
    this.color,
    this.defaultTask,
  );
}

class _DeptTask {
  final _DeptDef dept;
  final String task;

  const _DeptTask({required this.dept, required this.task});
}
