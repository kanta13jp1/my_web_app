import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// フォームビルダーページ
/// form-builder Edge Function と連携してフォームの作成・管理を行う
class FormBuilderPage extends StatefulWidget {
  const FormBuilderPage({super.key});

  @override
  State<FormBuilderPage> createState() => _FormBuilderPageState();
}

class _FormBuilderPageState extends State<FormBuilderPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _forms = [];
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchForms();
  }

  Future<void> _showCreateFormDialog() async {
    _titleController.clear();
    _descController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規フォームを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'フォーム名'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '説明 (任意)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'form.create',
          'title': title,
          if (_descController.text.trim().isNotEmpty)
            'description': _descController.text.trim(),
        },
      );
      await _fetchForms();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = 'フォームの作成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchForms() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'form.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['forms'] is List) {
        setState(
          () => _forms = (data['forms'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _forms = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _forms = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'フォーム一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フォームビルダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchForms,
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchForms,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _forms.isEmpty
                  ? const Center(child: Text('フォームがありません'))
                  : ListView.builder(
                      itemCount: _forms.length,
                      itemBuilder: (context, index) {
                        final form = _forms[index];
                        return ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: Text(
                            form['title']?.toString() ?? 'フォーム ${index + 1}',
                          ),
                          subtitle: Text(form['description']?.toString() ?? ''),
                          trailing: Text('${form['field_count'] ?? 0}フィールド'),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _showCreateFormDialog,
        tooltip: '新規フォーム作成',
        child: const Icon(Icons.add),
      ),
    );
  }
}
