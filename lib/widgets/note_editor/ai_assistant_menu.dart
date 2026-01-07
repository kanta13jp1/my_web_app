import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_service.dart';
import '../../main.dart'; // ★ ここを追加（supabase変数を利用するため）
import 'board_meeting_dialog.dart';
import 'note_analysis_dialog.dart';

class AIAssistantMenu extends StatefulWidget {
  final String content;
  final Function(String) onUpdateContent;

  const AIAssistantMenu({
    super.key,
    required this.content,
    required this.onUpdateContent,
  });

  @override
  State<AIAssistantMenu> createState() => _AIAssistantMenuState();
}

class _AIAssistantMenuState extends State<AIAssistantMenu> {
  final AIService _aiService = AIService();
  bool _isLoading = false;

  void _handleAction(String action, String label) async {
    Navigator.pop(context); // メニューを閉じる
    setState(() => _isLoading = true);

    // 処理中ダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (action == 'hold_board_meeting') {
        // 取締役会
        final result = await _aiService.invokeFunction(
          'ai-assistant',
          {'action': 'hold_board_meeting', 'content': widget.content},
        );
        if (!mounted) return;
        Navigator.pop(context); // ローディング消去
        _showBoardMeetingResult(result['result']);
      } else if (action == 'analyze_note_text') {
        // 分析
        final result = await _aiService.invokeFunction(
          'ai-assistant',
          {'action': 'analyze_note_text', 'content': widget.content},
        );
        if (!mounted) return;
        Navigator.pop(context); // ローディング消去
        _showAnalysisResult(result['result']);
      } else {
        // テキスト加工系 (improve, summarize, etc)
        final result = await _aiService.invokeFunction(
          'ai-assistant',
          {'action': action, 'content': widget.content},
        );
        if (!mounted) return;
        Navigator.pop(context); // ローディング消去
        _showTextResult(label, result['result'] as String);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ローディング消去
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // テキスト結果の表示
  void _showTextResult(String title, String resultText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title結果'),
        content: SingleChildScrollView(child: Text(resultText)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: resultText));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('コピーしました')));
            },
            child: const Text('コピー'),
          ),
          FilledButton(
            onPressed: () {
              widget.onUpdateContent(resultText); // 内容を置換または追記するロジックへ
              Navigator.pop(ctx);
            },
            child: const Text('反映する'),
          ),
        ],
      ),
    );
  }

  // 取締役会結果の表示
  void _showBoardMeetingResult(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => BoardMeetingDialog(data: data),
    );
  }

  // 分析結果の表示
  void _showAnalysisResult(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => NoteAnalysisDialog(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'AIアシスタント',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                Icons.psychology,
                '分析',
                'analyze_note_text',
                Colors.purple,
              ),
              _buildActionButton(
                Icons.people,
                '取締役会',
                'hold_board_meeting',
                Colors.indigo,
              ),
              _buildActionButton(
                Icons.auto_fix_high,
                '校正',
                'improve',
                Colors.blue,
              ),
              _buildActionButton(
                Icons.summarize,
                '要約',
                'summarize',
                Colors.orange,
              ),
              _buildActionButton(
                Icons.translate,
                '翻訳',
                'translate',
                Colors.green,
              ),
              _buildActionButton(
                Icons.title,
                'タイトル案',
                'suggest_title',
                Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    String action,
    Color color,
  ) {
    return InkWell(
      onTap: () => _handleAction(action, label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 補足: AIServiceにinvokeFunctionが無い場合のための拡張
extension AIServiceExt on AIService {
  Future<Map<String, dynamic>> invokeFunction(
    String name,
    Map<String, dynamic> body,
  ) async {
    // main.dartからインポートしたグローバル変数 supabase を使用
    final res = await supabase.functions.invoke(name, body: body);
    return res.data;
  }
}
