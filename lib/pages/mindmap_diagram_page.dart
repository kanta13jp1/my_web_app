import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// マインドマップ・ダイアグラムページ
/// tools-hub:mindmap.* actions でマインドマップを管理
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
        'tools-hub',
        body: {'action': 'mindmap.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['maps'] is List) {
        setState(
          () => _diagrams = (data['maps'] as List).cast<Map<String, dynamic>>(),
        );
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
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
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
                            color: Color(0xFFB0B0B0),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'マインドマップがありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFB0B0B0),
                              height: 1.5,
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
                            diagram['created_at']?.toString() ??
                            '';
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
