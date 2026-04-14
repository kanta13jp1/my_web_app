import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// プロジェクト管理 (ガントチャート) ページ
/// スプリント計画・マイルストーン・依存関係管理。Asana/Jira/GitHub Projects 対抗。
class ProjectGanttPage extends StatefulWidget {
  const ProjectGanttPage({super.key});

  @override
  State<ProjectGanttPage> createState() => _ProjectGanttPageState();
}

class _ProjectGanttPageState extends State<ProjectGanttPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  List<Map<String, dynamic>> _projects = [];

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = '進行中';
  bool _saving = false;

  static const _statuses = ['計画中', '進行中', '完了', '保留'];

  static const _statusColors = {
    '計画中': Color(0xFF3D5AFE),
    '進行中': Color(0xFFFF6B35),
    '完了': Color(0xFF4CAF50),
    '保留': Color(0xFFFFC107),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('projects')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() => _projects = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('projects').insert({
        'user_id': user.id,
        'name': name,
        'description': _descCtrl.text.trim(),
        'status': _status,
      });
      _nameCtrl.clear();
      _descCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    await _supabase.from('projects').update({'status': newStatus}).eq('id', id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('プロジェクト管理', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 新規プロジェクト作成
            Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('新規プロジェクト',
                        style: TextStyle(color: Colors.white70, fontSize: 12),),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('プロジェクト名'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('説明 (任意)'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFF333333)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _status,
                              dropdownColor: const Color(0xFF1E1E1E),
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox.shrink(),
                              isExpanded: true,
                              items: _statuses
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s),),)
                                  .toList(),
                              onChanged: (v) => setState(() => _status = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white,),)
                              : const Text('作成'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // プロジェクト一覧
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF6B35)),)
                  : _projects.isEmpty
                      ? const Center(
                          child: Text('プロジェクトはまだありません',
                              style: TextStyle(color: Colors.white38),),
                        )
                      : ListView.builder(
                          itemCount: _projects.length,
                          itemBuilder: (_, i) {
                            final p = _projects[i];
                            final status = p['status'] as String? ?? '進行中';
                            final color = _statusColors[status] ??
                                const Color(0xFFFF6B35);
                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.2),
                                  child: Icon(Icons.folder_outlined,
                                      color: color, size: 20,),
                                ),
                                title: Text(
                                  p['name'] as String? ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  p['description'] as String? ?? '',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12,),
                                ),
                                trailing: PopupMenuButton<String>(
                                  color: const Color(0xFF1E1E1E),
                                  icon: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4,),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(status,
                                        style: TextStyle(
                                            color: color, fontSize: 12,),),
                                  ),
                                  itemBuilder: (_) => _statuses
                                      .map((s) => PopupMenuItem(
                                          value: s,
                                          child: Text(s,
                                              style: const TextStyle(
                                                  color: Colors.white,),),),)
                                      .toList(),
                                  onSelected: (s) =>
                                      _updateStatus(p['id'].toString(), s),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
        ),
      );
}
