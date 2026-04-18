import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ホーム画面のクイックタスク入力カード。
///
/// 自然言語でタスクを入力すると、キーワードマッチングで
/// 最適な担当部署に自動ルーティングして agent_tasks テーブルに登録する。
/// X ポストの「会話で勝手にタスクを作ってくれる」を実現。
class QuickTaskInputCard extends StatefulWidget {
  const QuickTaskInputCard({super.key});

  @override
  State<QuickTaskInputCard> createState() => _QuickTaskInputCardState();
}

class _QuickTaskInputCardState extends State<QuickTaskInputCard> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _resultMessage;
  bool _success = false;

  // 部署ルーティングキーワードマップ (agent_org_page と同期)
  static const _deptKeywords = <String, _DeptRoute>{
    'cfo': _DeptRoute('CFO室', '財務・経理', Color(0xFF64748B)),
    'cmo': _DeptRoute('CMO室', 'マーケティング・広告', Color(0xFFEC4899)),
    'cho': _DeptRoute('CHO室', '健康・生活習慣', Color(0xFFEF4444)),
    'chro': _DeptRoute('CHRO室', '人事・習慣制度', Color(0xFF14B8A6)),
    'planning-director': _DeptRoute('企画部', '事業企画・戦略', Color(0xFFF59E0B)),
    'cto': _DeptRoute('開発部', '技術・開発', Color(0xFF10B981)),
    'sales-director': _DeptRoute('営業部', '営業・受注', Color(0xFF8B5CF6)),
    'cs-director': _DeptRoute('CS部', 'カスタマーサポート', Color(0xFF0EA5E9)),
    'legal-director': _DeptRoute('法務部', '法務・契約', Color(0xFF78716C)),
    'pr-director': _DeptRoute('広報部', '広報・ブログ', Color(0xFF06B6D4)),
    'procurement-director': _DeptRoute('調達部', '調達・外注', Color(0xFF84CC16)),
  };

  static const _keywords = <String, List<String>>{
    'cfo': ['費用', 'コスト', '予算', '収入', '節約', '固定費', '支出', 'お金', '資金', '財務', '経理'],
    'cmo': [
      '流入',
      '登録',
      'sns',
      '宣伝',
      'マーケ',
      'lp',
      'ツイート',
      '認知',
      '広告',
      'キャンペーン',
      'x投稿',
    ],
    'cho': ['体調', '睡眠', '運動', '食事', '健康', '休息', '生活', '疲れ'],
    'chro': ['習慣', '評価', '報酬', 'ルール', '制度', '継続', '人事', '採用'],
    'planning-director': ['企画', '新規事業', 'ロードマップ', '市場調査', '戦略', '計画'],
    'cto': ['開発', 'コード', 'バグ', '技術', 'アーキテクチャ', 'デプロイ', 'flutter', '実装', '修正'],
    'sales-director': ['売上', '営業', '受注', '商談', '顧客開拓', 'リード'],
    'cs-director': ['サポート', 'チケット', '問い合わせ', '顧客満足', 'cs', 'カスタマー'],
    'legal-director': ['法務', '契約', '利用規約', 'プライバシー', 'コンプライアンス', '知的財産'],
    'pr-director': ['広報', 'プレスリリース', 'メディア', 'ブランド', '取材', 'ブログ', '記事', '投稿'],
    'procurement-director': ['調達', 'ベンダー', 'ツール選定', '外注', '契約管理'],
  };

  String _routeToSlug(String text) {
    final lower = text.toLowerCase();
    for (final entry in _keywords.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) return entry.key;
      }
    }
    return 'ceo'; // フォールバック: CEO に委任
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() {
      _loading = true;
      _resultMessage = null;
      _success = false;
    });

    try {
      final slug = _routeToSlug(text);
      final dept = _deptKeywords[slug];
      final deptName = dept?.name ?? 'CEO室';

      // 部署長の agent_id を検索 (agents テーブル)
      final agentRows = await supabase
          .from('agents')
          .select('id, display_name')
          .eq('slug', slug)
          .eq('user_id', uid)
          .limit(1);

      // CEO を supervisor として取得
      final ceoRows = await supabase
          .from('agents')
          .select('id')
          .eq('slug', 'ceo')
          .eq('user_id', uid)
          .limit(1);

      String? agentId;
      String agentName = deptName;
      if ((agentRows as List).isNotEmpty) {
        agentId = agentRows.first['id']?.toString();
        agentName = agentRows.first['display_name']?.toString() ?? deptName;
      }
      final ceoId = ((ceoRows as List).isNotEmpty)
          ? ceoRows.first['id']?.toString()
          : null;

      // supervisor と assignee の両方が必要
      if (agentId == null || ceoId == null) {
        if (mounted) {
          setState(() {
            _success = false;
            _resultMessage = 'AI 組織 OS を先に初期化してください（AI組織OSページを開くと自動設定されます）。';
            _loading = false;
          });
        }
        return;
      }

      // タスクを登録
      await supabase.from('agent_tasks').insert(<String, dynamic>{
        'user_id': uid,
        'supervisor_agent_id': ceoId,
        'assignee_agent_id': agentId,
        'title': text.length > 100 ? text.substring(0, 100) : text,
        'description': text,
        'status': 'queued',
        'task_type': 'quick_input',
        'source': 'home_quick_input',
      });

      if (mounted) {
        setState(() {
          _success = true;
          _resultMessage = '→ $agentName ($deptName) に委任しました';
          _loading = false;
        });
        _controller.clear();
        // 3秒後にメッセージをクリア
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _resultMessage = null);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _success = false;
          _resultMessage = 'エラーが発生しました。AI 組織 OS で直接タスクを作成してください。';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1A2233) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Color(0xFF2A3A55) : Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(0xFF4F46E5).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_fix_high,
                  size: 16,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '仮想秘書にタスクを依頼',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Text(
                '→ 自動で部署に振り分け',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '例: 来週のブログを準備する / 広告費の見直し',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Color(0xFF374151)
                            : Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 16),
                ),
              ),
            ],
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _success ? Icons.check_circle : Icons.error_outline,
                  size: 14,
                  color: _success ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _resultMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: _success ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeptRoute {
  final String name;
  final String description;
  final Color color;

  const _DeptRoute(this.name, this.description, this.color);
}
