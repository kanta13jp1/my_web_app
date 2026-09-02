import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// AI文章作成支援ページ (Grammarly/Notion AI競合)
/// ai-writing-assistant Edge Function と連携
class AiWritingAssistantPage extends StatefulWidget {
  const AiWritingAssistantPage({super.key});

  @override
  State<AiWritingAssistantPage> createState() => _AiWritingAssistantPageState();
}

class _AiWritingAssistantPageState extends State<AiWritingAssistantPage> {
  final _supabase = Supabase.instance.client;
  final _inputController = TextEditingController();
  final _resultController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String _selectedAction = 'improve';
  String _selectedTone = 'formal';
  String _selectedLang = '英語';

  static const _actions = {
    'improve': ('文章改善', Icons.auto_fix_high, Color(0xFF6366F1)),
    'continue': ('続きを書く', Icons.arrow_forward, Color(0xFF3B82F6)),
    'translate': ('翻訳', Icons.translate, Color(0xFFF59E0B)),
    'tone': ('トーン変換', Icons.tune, Color(0xFFEC4899)),
    'titles': ('タイトル提案', Icons.title, Color(0xFF8B5CF6)),
    'minutes': ('議事録生成', Icons.assignment, Color(0xFF0EA5E9)),
    'thread': ('Xスレッド', Icons.dynamic_feed, Color(0xFF1DA1F2)),
    'blog': ('ブログ記事', Icons.article, Color(0xFFF97316)),
  };

  static const _tones = ['formal', 'casual', 'sns', 'academic', 'sales'];
  static const _toneLabels = {
    'formal': 'フォーマル',
    'casual': 'カジュアル',
    'sns': 'SNS向け',
    'academic': '学術的',
    'sales': '営業向け',
  };

  static const _languages = ['英語', '中国語', '韓国語', 'スペイン語', 'フランス語'];

  @override
  void dispose() {
    _inputController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '文章を入力してください');
      return;
    }
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _resultController.clear();
    });
    try {
      final body = <String, dynamic>{
        'action': _selectedAction,
        'text': text,
      };
      if (_selectedAction == 'tone') body['tone'] = _selectedTone;
      if (_selectedAction == 'translate') {
        body['target_language'] = _selectedLang;
      }

      final res = await _supabase.functions.invoke(
        'ai-writing-assistant',
        body: body,
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        setState(() {
          _resultController.text = data['result'] as String? ?? '';
        });
      } else if (data is Map<String, dynamic>) {
        setState(() => _error = data['error'] as String? ?? '不明なエラー');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'API呼び出し失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI文章アシスタント'),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action selector
            _buildActionSelector(isDark),
            const SizedBox(height: 12),

            // Sub-options
            if (_selectedAction == 'tone') _buildToneSelector(isDark),
            if (_selectedAction == 'translate') _buildLanguageSelector(isDark),

            const SizedBox(height: 12),

            // Input
            _buildInputField(isDark),
            const SizedBox(height: 12),

            // Run button
            FilledButton.icon(
              onPressed: _isLoading ? null : _run,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isLoading ? '処理中...' : 'AI に依頼する'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    _actions[_selectedAction]?.$3 ?? const Color(0xFF6366F1),
                minimumSize: const Size.fromHeight(52),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],

            // Result
            if (_resultController.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildResultField(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '機能を選択',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actions.entries.map((e) {
              final selected = e.key == _selectedAction;
              return GestureDetector(
                onTap: () => setState(() => _selectedAction = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? e.value.$3.withValues(alpha: 0.15)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? e.value.$3 : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        e.value.$2,
                        size: 16,
                        color: selected ? e.value.$3 : null,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        e.value.$1,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? e.value.$3 : null,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToneSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'トーンを選択',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _tones.map((t) {
              return ChoiceChip(
                label: Text(_toneLabels[t] ?? t),
                selected: t == _selectedTone,
                onSelected: (_) => setState(() => _selectedTone = t),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          const Text(
            '翻訳先言語: ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedLang,
            underline: const SizedBox.shrink(),
            items: _languages
                .map(
                  (l) => DropdownMenuItem(value: l, child: Text(l)),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedLang = v ?? '英語'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              '入力テキスト',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
          ),
          TextField(
            controller: _inputController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'ここに文章を入力してください…',
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(14, 4, 14, 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultField(bool isDark) {
    final actionInfo = _actions[_selectedAction];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (actionInfo?.$3 ?? const Color(0xFFB0B0B0))
              .withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Row(
              children: [
                Icon(
                  actionInfo?.$2 ?? Icons.auto_awesome,
                  size: 16,
                  color: actionInfo?.$3,
                ),
                const SizedBox(width: 6),
                Text(
                  '${actionInfo?.$1 ?? '結果'}の結果',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: actionInfo?.$3,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                if (_selectedAction == 'thread')
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: 'Xに投稿',
                    color: const Color(0xFF1DA1F2),
                    onPressed: () async {
                      final encoded = Uri.encodeComponent(
                        _resultController.text.length > 280
                            ? '${_resultController.text.substring(0, 277)}...'
                            : _resultController.text,
                      );
                      final uri = Uri.parse(
                        'https://twitter.com/intent/tweet?text=$encoded',
                      );
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'コピー',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _resultController.text),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('コピーしました')),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: SelectableText(
              _resultController.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.87)
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
