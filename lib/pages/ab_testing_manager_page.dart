import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AbTestingManagerPage extends StatefulWidget {
  const AbTestingManagerPage({super.key});

  @override
  State<AbTestingManagerPage> createState() => _AbTestingManagerPageState();
}

class _AbTestingManagerPageState extends State<AbTestingManagerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _tests = [];

  final _nameController = TextEditingController();
  final _variantAController = TextEditingController();
  final _variantBController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _variantAController.dispose();
    _variantBController.dispose();
    super.dispose();
  }

  Future<void> _fetchTests() async {
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
        'enterprise-hub',
        body: {'action': 'ab.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['tests'];
        setState(() {
          _tests = items is List ? items.cast<Map<String, dynamic>>() : [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'A/Bテストの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTest() async {
    final name = _nameController.text.trim();
    final variantA = _variantAController.text.trim();
    final variantB = _variantBController.text.trim();
    if (name.isEmpty || variantA.isEmpty || variantB.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'ab.create',
          'name': name,
          'variant_a': variantA,
          'variant_b': variantB,
        },
      );
      _nameController.clear();
      _variantAController.clear();
      _variantBController.clear();
      await _fetchTests();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = 'テスト作成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A/Bテスト管理'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _tests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '新規 A/Bテスト作成',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'テスト名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _variantAController,
                            decoration: const InputDecoration(
                              labelText: 'バリアント A',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _variantBController,
                            decoration: const InputDecoration(
                              labelText: 'バリアント B',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _createTest,
                              icon: const Icon(Icons.add),
                              label: const Text('テスト作成'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A/Bテスト一覧',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_tests.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'A/Bテストがありません',
                          style: TextStyle(
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tests.length,
                      itemBuilder: (context, index) {
                        final test = _tests[index];
                        final status = test['status'] as String? ?? 'draft';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: status == 'running'
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                              child: const Icon(
                                Icons.science,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            title: Text(test['name'] as String? ?? ''),
                            subtitle: Text(
                              'A: ${test['variant_a'] ?? ''} / B: ${test['variant_b'] ?? ''}',
                            ),
                            trailing: Chip(
                              label: Text(status),
                              backgroundColor: status == 'running'
                                  ? const Color(0xFF4CAF50).withAlpha(30)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
