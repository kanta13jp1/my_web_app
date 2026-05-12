import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 集客シグナル記録ページ
/// 取得チャネルごとのシグナルを記録・確認する
class GrowthAcquisitionSignalPage extends StatefulWidget {
  const GrowthAcquisitionSignalPage({super.key});

  @override
  State<GrowthAcquisitionSignalPage> createState() =>
      _GrowthAcquisitionSignalPageState();
}

class _GrowthAcquisitionSignalPageState
    extends State<GrowthAcquisitionSignalPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _selectedSignal;

  static const List<String> _signals = [
    'touch_landing',
    'touch_import',
    'touch_public_memo',
    'touch_referral',
    'touch_comparison',
    'import_preview_notion',
    'import_preview_evernote',
    'import_preview_markdown',
    'import_signup_cta',
    'public_memo_signup_cta',
    'signup_submit_landing',
    'signup_submit_import',
    'signup_submit_public_memo',
    'signup_submit_referral',
    'signup_submit_comparison',
  ];

  static const Map<String, String> _signalLabels = {
    'touch_landing': 'ランディング到達',
    'touch_import': 'インポート到達',
    'touch_public_memo': '公開メモ到達',
    'touch_referral': '紹介経由到達',
    'touch_comparison': '比較ページ到達',
    'import_preview_notion': 'Notionプレビュー',
    'import_preview_evernote': 'Evernoteプレビュー',
    'import_preview_markdown': 'Markdownプレビュー',
    'import_signup_cta': 'インポートCTA',
    'public_memo_signup_cta': '公開メモCTA',
    'signup_submit_landing': 'LP登録送信',
    'signup_submit_import': 'インポート登録送信',
    'signup_submit_public_memo': '公開メモ登録送信',
    'signup_submit_referral': '紹介登録送信',
    'signup_submit_comparison': '比較ページ登録送信',
  };

  Future<void> _record() async {
    final signal = _selectedSignal;
    if (signal == null) {
      setState(() => _errorMessage = 'シグナルを選択してください');
      return;
    }

    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'acquisition.track',
          'channel': signal,
          'event': 'signal',
          'value': 1,
        },
      );

      if (mounted) {
        setState(() {
          _successMessage = '「${_signalLabels[signal] ?? signal}」のシグナルを記録しました';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'シグナル記録に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('集客シグナル記録'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '記録するシグナル',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _signals.length,
                itemBuilder: (context, index) {
                  final signal = _signals[index];
                  final label = _signalLabels[signal] ?? signal;
                  final selected = _selectedSignal == signal;
                  return InkWell(
                    onTap: () => setState(() => _selectedSignal = signal),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFB0B0B0),
                                width: 2,
                              ),
                            ),
                            child: selected
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF4CAF50),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    height: 1.5,
                                  ),
                                ),
                                Text(
                                  signal,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB0B0B0),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _successMessage!,
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _record,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('シグナルを記録'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
