import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 現実分析ページ
/// テキストを入力すると AI が現実の状況を分析する
class AnalyzeRealityPage extends StatefulWidget {
  const AnalyzeRealityPage({super.key});

  @override
  State<AnalyzeRealityPage> createState() => _AnalyzeRealityPageState();
}

class _AnalyzeRealityPageState extends State<AnalyzeRealityPage> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'analyze.reality', 'situation': text},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _result = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '分析に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildResultCard(String key, dynamic value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B35),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(value?.toString() ?? ''),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('現実分析'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '現状や課題を入力すると AI が分析します',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '現在の状況、悩み、課題を入力してください...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyze,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('現実を分析する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            if (_result != null)
              ..._result!.entries.map((e) => _buildResultCard(e.key, e.value)),
          ],
        ),
      ),
    );
  }
}
