import 'package:flutter/material.dart';
import '../main.dart';

/// マイスキル管理ページ — Slack ワークフロー対抗
/// ai-assistant EF の save_skill / list_skills / run_skill / delete_skill を利用
class MySkillsPage extends StatefulWidget {
  const MySkillsPage({super.key});

  @override
  State<MySkillsPage> createState() => _MySkillsPageState();
}

class _MySkillsPageState extends State<MySkillsPage> {
  List<Map<String, dynamic>> _skills = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  // ── EF 呼び出し ──────────────────────────────────────────────────────────

  Future<void> _loadSkills() async {
    if (supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'list_skills'},
      );
      final data = res.data as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _skills = List<Map<String, dynamic>>.from(
          (data?['skills'] as List?) ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSkill({
    required String name,
    required String description,
    required String promptTemplate,
    String? model,
    List<String> tags = const [],
  }) async {
    await supabase.functions.invoke(
      'ai-assistant',
      body: {
        'action': 'save_skill',
        'skillName': name,
        'skillDescription': description,
        'promptTemplate': promptTemplate,
        'skillModel': model,
        'skillTags': tags,
      },
    );
    await _loadSkills();
  }

  Future<String?> _runSkill(String skillId, String content) async {
    final res = await supabase.functions.invoke(
      'ai-assistant',
      body: {
        'action': 'run_skill',
        'skillId': skillId,
        'content': content,
      },
    );
    final data = res.data as Map<String, dynamic>?;
    final result = data?['result'];
    if (result is Map) {
      return result['text']?.toString() ??
          result['content']?.toString() ??
          result.toString();
    }
    return result?.toString();
  }

  Future<void> _deleteSkill(String skillId) async {
    await supabase.functions.invoke(
      'ai-assistant',
      body: {'action': 'delete_skill', 'skillId': skillId},
    );
    await _loadSkills();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        title: const Text('マイスキル'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSkills,
            tooltip: '更新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSkillDialog,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新規スキル'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            const Text(
              'エラーが発生しました',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSkills,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      );
    }
    if (_skills.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.psychology_outlined,
              color: Color(0xFF6366F1),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'スキルがまだありません',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'よく使うプロンプトをスキルとして登録して\n1タップで再利用できます。',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateSkillDialog,
              icon: const Icon(Icons.add),
              label: const Text('最初のスキルを作成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _skills.length,
      itemBuilder: (context, i) => _buildSkillCard(_skills[i]),
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> skill) {
    final id = skill['id'] as String? ?? '';
    final name = skill['name'] as String? ?? '';
    final description = skill['description'] as String? ?? '';
    final tags = List<String>.from((skill['tags'] as List?) ?? []);
    final useCount = (skill['use_count'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showRunSkillDialog(id, name),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$useCount回使用',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRunSkillDialog(id, name),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('実行'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmDeleteSkill(id, name),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFF64748B),
                    ),
                    tooltip: '削除',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ダイアログ ─────────────────────────────────────────────────────────

  void _showCreateSkillDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          '新規スキルを作成',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _inputField(nameCtrl, 'スキル名 *', maxLines: 1),
              const SizedBox(height: 12),
              _inputField(descCtrl, '説明 (任意)'),
              const SizedBox(height: 12),
              _inputField(
                promptCtrl,
                'プロンプトテンプレート *\n（例: 以下の内容を3行で要約してください:）',
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              _inputField(
                tagsCtrl,
                'タグ (カンマ区切り、例: 要約,翻訳)',
                maxLines: 1,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'キャンセル',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  promptCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              final tags = tagsCtrl.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              await _saveSkill(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                promptTemplate: promptCtrl.text.trim(),
                tags: tags,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showRunSkillDialog(String skillId, String skillName) {
    final contentCtrl = TextEditingController();
    String? resultText;
    bool isRunning = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setInner) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            skillName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _inputField(
                    contentCtrl,
                    '入力テキスト (任意)\nスキルのプロンプトに追記されます',
                    maxLines: 4,
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                  if (resultText != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'AI の回答:',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        resultText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text(
                '閉じる',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isRunning
                  ? null
                  : () async {
                      setInner(() => isRunning = true);
                      try {
                        final result = await _runSkill(
                          skillId,
                          contentCtrl.text,
                        );
                        setInner(() {
                          resultText = result ?? '(結果なし)';
                          isRunning = false;
                        });
                      } catch (e) {
                        setInner(() {
                          resultText = 'エラー: $e';
                          isRunning = false;
                        });
                      }
                    },
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('実行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSkill(String skillId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'スキルを削除',
          style: TextStyle(
            color: Colors.white,
            height: 1.5,
          ),
        ),
        content: Text(
          '「$name」を削除しますか？この操作は取り消せません。',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'キャンセル',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteSkill(skillId);
    }
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 3,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          height: 1.5,
        ),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6366F1)),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
