import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// マイAIエージェント — タスク自動化フロー定義 UI
/// Notion Custom AI Agents 対抗: ユーザー定義タスク自動化フロー
/// Web版: my-ai-agent EF と連携 (実装後に接続)
class AiAgentPage extends StatefulWidget {
  const AiAgentPage({super.key});

  @override
  State<AiAgentPage> createState() => _AiAgentPageState();
}

class _AiAgentPageState extends State<AiAgentPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _flows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFlows();
  }

  Future<void> _loadFlows() async {
    setState(() {
      _loading = true;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _flows = [];
          _loading = false;
        });
        return;
      }
      final data = await _supabase
          .from('ai_agent_flows')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      setState(() {
        _flows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _flows = [];
        _loading = false;
      });
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final triggerCtrl = TextEditingController();
    final actionCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しいAIエージェント'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'エージェント名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: triggerCtrl,
              decoration: const InputDecoration(
                labelText: 'トリガー (例: 毎朝9時)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: actionCtrl,
              decoration: const InputDecoration(
                labelText: 'アクション (例: 今日のタスクをまとめてSlackに投稿)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _createFlow(
                name: nameCtrl.text.trim(),
                trigger: triggerCtrl.text.trim(),
                action: actionCtrl.text.trim(),
              );
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFlow({
    required String name,
    required String trigger,
    required String action,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('ai_agent_flows').insert({
        'user_id': userId,
        'name': name,
        'trigger': trigger,
        'action': action,
        'is_active': true,
      });
      await _loadFlows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlow(String id, bool current) async {
    try {
      await _supabase
          .from('ai_agent_flows')
          .update({'is_active': !current}).eq('id', id);
      await _loadFlows();
    } catch (_) {}
  }

  Future<void> _deleteFlow(String id) async {
    try {
      await _supabase.from('ai_agent_flows').delete().eq('id', id).select();
      await _loadFlows();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイAIエージェント'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlows,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('新規作成'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _flows.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            size: 64,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          const Text(
            'AIエージェントがまだいません',
            style:
                TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 8),
          const Text(
            'タスク自動化フローを作成して\n繰り返し作業をAIに任せましょう',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('最初のエージェントを作成'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _flows.length,
      itemBuilder: (ctx, i) {
        final flow = _flows[i];
        final isActive = flow['is_active'] as bool? ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              Icons.smart_toy,
              color:
                  isActive ? const Color(0xFF3D5AFE) : const Color(0xFF9CA3AF),
            ),
            title: Text(
              flow['name'] as String? ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((flow['trigger'] as String?)?.isNotEmpty == true)
                  Text('🕐 ${flow['trigger']}'),
                if ((flow['action'] as String?)?.isNotEmpty == true)
                  Text(
                    '⚡ ${flow['action']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  onChanged: (_) => _toggleFlow(
                    flow['id'] as String,
                    isActive,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFE53935),
                  ),
                  onPressed: () => _deleteFlow(flow['id'] as String),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
