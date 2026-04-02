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

  @override
  void initState() {
    super.initState();
    _fetchForms();
  }

  Future<void> _fetchForms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'form-builder',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['forms'] is List) {
        setState(() => _forms = (data['forms'] as List).cast<Map<String, dynamic>>());
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
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchForms, child: const Text('再試行')),
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
                          title: Text(form['title']?.toString() ?? 'フォーム ${index + 1}'),
                          subtitle: Text(form['description']?.toString() ?? ''),
                          trailing: Text('${form['field_count'] ?? 0}フィールド'),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: '新規フォーム作成',
        child: const Icon(Icons.add),
      ),
    );
  }
}
