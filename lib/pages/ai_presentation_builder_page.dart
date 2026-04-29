import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AIプレゼンビルダーページ
/// テキスト説明からスライド構成をAIが自動生成。Gamma / Canva / Beautiful.ai 対抗。
class AiPresentationBuilderPage extends StatefulWidget {
  const AiPresentationBuilderPage({super.key});

  @override
  State<AiPresentationBuilderPage> createState() =>
      _AiPresentationBuilderPageState();
}

class _AiPresentationBuilderPageState extends State<AiPresentationBuilderPage> {
  final _supabase = Supabase.instance.client;

  final _topicCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  int _slideCount = 5;
  bool _generating = false;
  String? _result;
  String? _error;
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = false;

  static const _templates = [
    '新規事業のピッチデッキ',
    '競合分析レポート',
    '四半期実績レビュー',
    '製品ロードマップ',
    '技術仕様説明',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _audienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('ai_presentations')
          .select('id, topic, slide_count, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      setState(
        () => _history = (data as List).cast<Map<String, dynamic>>(),
      );
    } catch (_) {
      // テーブル未作成時は無視
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _generate() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loadingHistory = false);
      return;
    }
    if (_topicCtrl.text.trim().isEmpty) return;
    setState(() {
      _generating = true;
      _result = null;
      _error = null;
    });
    try {
      final resp = await _supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'presentation',
          'topic': _topicCtrl.text.trim(),
          'audience': _audienceCtrl.text.trim().isEmpty
              ? '一般ビジネスパーソン'
              : _audienceCtrl.text.trim(),
          'slide_count': _slideCount,
        },
      );
      final data = resp.data;
      String output;
      if (data is Map<String, dynamic>) {
        output = data['content'] as String? ??
            data['result'] as String? ??
            data['slides'] as String? ??
            data.toString();
      } else {
        output = data.toString();
      }
      setState(() => _result = output);

      // 履歴保存
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        try {
          await _supabase.from('ai_presentations').insert({
            'user_id': userId,
            'topic': _topicCtrl.text.trim(),
            'slide_count': _slideCount,
            'content': output,
          });
          await _loadHistory();
        } catch (_) {
          // テーブル未作成時は無視
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'AI生成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIプレゼンビルダー'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(),
            const SizedBox(height: 16),
            if (_result != null) _buildResultCard(),
            if (_error != null)
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3A1010)
                    : const Color(0xFFFFEBEE),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.present_to_all, color: Color(0xFF3D5AFE)),
                SizedBox(width: 8),
                Text(
                  'スライドを自動生成',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('テンプレート'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _templates
                  .map(
                    (t) => ActionChip(
                      label: Text(t),
                      onPressed: () => _topicCtrl.text = t,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                labelText: 'プレゼンのテーマ・目的 *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _audienceCtrl,
              decoration: const InputDecoration(
                labelText: '対象オーディエンス (例: 投資家、社内チーム)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
            ),
            const SizedBox(height: 12),
            Text('スライド枚数: $_slideCount枚'),
            Slider(
              value: _slideCount.toDouble(),
              min: 3,
              max: 15,
              divisions: 12,
              label: '$_slideCount枚',
              onChanged: (v) => setState(() => _slideCount = v.round()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_generating ? 'AI生成中...' : 'AIでスライドを生成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFE8EAF6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.slideshow, color: Color(0xFF3D5AFE)),
                SizedBox(width: 8),
                Text(
                  '生成されたスライド構成',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(_result!),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_loadingHistory || _history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '過去の生成履歴',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ..._history.map(
          (h) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(
                Icons.present_to_all,
                color: Color(0xFF3D5AFE),
              ),
              title: Text(h['topic'] as String? ?? ''),
              trailing: Text('${h['slide_count'] ?? '-'}枚'),
            ),
          ),
        ),
      ],
    );
  }
}
