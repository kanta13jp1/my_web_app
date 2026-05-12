import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// メールテンプレートビルダーページ
/// テンプレートの作成・編集・プレビュー・送信。
/// email-template-builder Edge Function と連携。
class EmailTemplateBuilderPage extends StatefulWidget {
  const EmailTemplateBuilderPage({super.key});

  @override
  State<EmailTemplateBuilderPage> createState() =>
      _EmailTemplateBuilderPageState();
}

class _EmailTemplateBuilderPageState extends State<EmailTemplateBuilderPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  Future<void> _fetchTemplates() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'email_template.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['templates'];
        if (list is List) {
          setState(() {
            _templates = list.map((t) => t as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メールテンプレート'),
        leading: _selected != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selected = null),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTemplates,
          ),
        ],
      ),
      floatingActionButton: _selected == null
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _selected == null
                  ? _buildTemplateList()
                  : _buildTemplateDetail(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchTemplates, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildTemplateList() {
    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email, size: 64, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text(
              'テンプレートがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('テンプレートを作成'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _templates.length,
      itemBuilder: (ctx, i) {
        final t = _templates[i];
        final name = t['name'] as String? ?? 'テンプレート ${i + 1}';
        final subject = t['subject'] as String? ?? '';
        final category = t['category'] as String? ?? '';
        final usedCount = t['usedCount'] as int? ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.email)),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(subject.isNotEmpty ? subject : category),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$usedCount 回',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const Text(
                  '使用',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            onTap: () => setState(() => _selected = t),
          ),
        );
      },
    );
  }

  Widget _buildTemplateDetail() {
    final t = _selected!;
    final name = t['name'] as String? ?? '';
    final subject = t['subject'] as String? ?? '';
    final body = t['body'] as String? ?? '';
    final vars = t['variables'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (subject.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text(
                      '件名: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Expanded(child: Text(subject)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (vars.isNotEmpty) ...[
            const Text(
              '変数:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: vars.map((v) => Chip(label: Text('{{$v}}'))).toList(),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            '本文:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(body),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: body));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('クリップボードにコピーしました')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('コピー'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await _supabase.functions.invoke(
                        'enterprise-hub',
                        body: {
                          'action': 'email_template.use',
                          'templateId': t['id'],
                        },
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('テンプレートを使用しました')),
                        );
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('使用する'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テンプレートを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'テンプレート名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(
                labelText: '件名',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              try {
                await _supabase.functions.invoke(
                  'enterprise-hub',
                  body: {
                    'action': 'email_template.create',
                    'name': name,
                    'subject': subjectCtrl.text.trim(),
                  },
                );
                await _fetchTemplates();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }
}
