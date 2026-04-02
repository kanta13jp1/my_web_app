import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// マインドマップ・ダイアグラムページ
/// mindmap-diagram Edge Function と連携してマインドマップを管理
class MindmapDiagramPage extends StatefulWidget {
  const MindmapDiagramPage({super.key});

  @override
  State<MindmapDiagramPage> createState() => _MindmapDiagramPageState();
}

class _MindmapDiagramPageState extends State<MindmapDiagramPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _diagrams = [];

  @override
  void initState() {
    super.initState();
    _fetchDiagrams();
  }

  Future<void> _fetchDiagrams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'mindmap-diagram',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['diagrams'] is List) {
        setState(() => _diagrams = (data['diagrams'] as List).cast<Map<String, dynamic>>());
      } else if (data is List) {
        setState(() => _diagrams = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _diagrams = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'マインドマップの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マインドマップ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDiagrams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchDiagrams,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _diagrams.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_tree,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'マインドマップがありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _diagrams.length,
                      itemBuilder: (context, index) {
                        final diagram = _diagrams[index];
                        final title = diagram['title']?.toString() ??
                            diagram['name']?.toString() ??
                            'マインドマップ $index';
                        final updatedAt = diagram['updated_at']?.toString() ??
                            diagram['created_at']?.toString() ?? '';
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.account_tree,
                              color: Color(0xFF6366F1),
                            ),
                            title: Text(title),
                            subtitle: updatedAt.isNotEmpty
                                ? Text('更新: $updatedAt')
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
    );
  }
}
