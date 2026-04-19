import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ワークフローテンプレートページ
/// workflow-templates Edge Function と連携してテンプレートギャラリーを提供
class WorkflowTemplatesPage extends StatefulWidget {
  const WorkflowTemplatesPage({super.key});

  @override
  State<WorkflowTemplatesPage> createState() => _WorkflowTemplatesPageState();
}

class _WorkflowTemplatesPageState extends State<WorkflowTemplatesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _templates = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'workflow-templates',
        queryParameters: {'view': 'gallery'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['templates'] is List) {
        setState(() => _templates = data['templates'] as List);
      } else if (data is Map<String, dynamic> &&
          data['builtinTemplates'] is List) {
        setState(() => _templates = data['builtinTemplates'] as List);
      } else if (data is List) {
        setState(() => _templates = data);
      } else {
        setState(() => _templates = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'finance':
        return Colors.green;
      case 'hr':
        return const Color(0xFF3D5AFE);
      case 'engineering':
        return const Color(0xFFFF6B35);
      case 'marketing':
        return const Color(0xFFFF6B35);
      case 'sales':
        return const Color(0xFF3D5AFE);
      case 'support':
        return const Color(0xFF009688);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ワークフローテンプレート'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _templates.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 48,
                            color: Color(0xFF9CA3AF),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'テンプレートはありません',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _templates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _templates[i] as Map<String, dynamic>;
                        final category = item['category']?.toString();
                        final steps = item['steps'];
                        final stepCount = steps is List ? steps.length : 0;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _categoryColor(category).withAlpha(30),
                              child: Icon(
                                Icons.account_tree,
                                color: _categoryColor(category),
                              ),
                            ),
                            title: Text(
                              item['name']?.toString() ??
                                  item['id']?.toString() ??
                                  'テンプレート',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              '$stepCount ステップ${category != null ? ' · $category' : ''}',
                            ),
                            trailing: category != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _categoryColor(category)
                                          .withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _categoryColor(category),
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
