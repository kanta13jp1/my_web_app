import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiWorkflowAutomationPage extends StatefulWidget {
  const AiWorkflowAutomationPage({super.key});

  @override
  State<AiWorkflowAutomationPage> createState() =>
      _AiWorkflowAutomationPageState();
}

class _AiWorkflowAutomationPageState extends State<AiWorkflowAutomationPage> {
  bool _loading = false;
  List<dynamic> _workflows = [];
  String? _error;

  Future<void> _fetch() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'enterprise-hub',
        body: {'action': 'ai_workflow.list'},
      );
      final data = res.data;
      if (!mounted) return;
      setState(() {
        if (data is Map && data['workflows'] is List) {
          _workflows = data['workflows'] as List;
        } else if (data is List) {
          _workflows = data;
        } else {
          _workflows = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI ワークフロー自動化'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'エラー: $_error',
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _workflows.isEmpty
                  ? const Center(child: Text('ワークフローはまだありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _workflows.length,
                      itemBuilder: (context, i) {
                        final wf = _workflows[i] as Map<String, dynamic>;
                        final isActive = wf['is_active'] as bool? ?? false;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.auto_awesome,
                              color: isActive
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                            ),
                            title: Text(
                              wf['name'] as String? ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              wf['description'] as String? ?? '',
                            ),
                            trailing: Chip(
                              label: Text(
                                isActive ? '有効' : '無効',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isActive
                                      ? const Color(0xFF4CAF50)
                                      : Colors.grey,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
