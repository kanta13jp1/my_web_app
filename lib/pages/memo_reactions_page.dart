import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// メモリアクション確認ページ
/// 公開メモへのリアクション（絵文字）の集計と投票を表示
class MemoReactionsPage extends StatefulWidget {
  const MemoReactionsPage({super.key});

  @override
  State<MemoReactionsPage> createState() => _MemoReactionsPageState();
}

class _MemoReactionsPageState extends State<MemoReactionsPage> {
  final _supabase = Supabase.instance.client;
  final _memoIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, int>? _reactions;
  List<String> _userReactions = [];

  static const List<String> _allowedReactions = ['👍', '❤️', '🔥', '💡', '🎉'];

  static const Map<String, String> _reactionLabels = {
    '👍': 'いいね',
    '❤️': 'ハート',
    '🔥': '炎',
    '💡': 'ひらめき',
    '🎉': '祝い',
  };

  @override
  void dispose() {
    _memoIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final memoIdText = _memoIdController.text.trim();
    final memoId = int.tryParse(memoIdText);
    if (memoId == null) {
      setState(() => _errorMessage = 'メモIDを入力してください');
      return;
    }

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
        'core-hub',
        body: {'action': 'memo.share_list', 'memo_id': memoId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
        final rawUser = data['userReactions'] as List<dynamic>? ?? [];
        setState(() {
          _reactions =
              rawReactions.map((k, v) => MapEntry(k, (v as num).toInt()));
          _userReactions = rawUser.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'リアクション取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggle(String reaction) async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    final memoId = int.tryParse(_memoIdController.text.trim());
    if (memoId == null) return;

    try {
      await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'memo.share', 'memo_id': memoId, 'reaction': reaction},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'リアクション送信に失敗しました: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモリアクション'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memoIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'メモID',
                      border: OutlineInputBorder(),
                      hintText: '例: 1',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _load,
                  child: const Text('取得'),
                ),
              ],
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
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_reactions != null) ...[
              const Text(
                'リアクション',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _allowedReactions.map((r) {
                  final count = _reactions![r] ?? 0;
                  final isActive = _userReactions.contains(r);
                  return Semantics(
                    label:
                        '${_reactionLabels[r] ?? r} $count件${isActive ? " 選択中" : ""}',
                    button: true,
                    child: GestureDetector(
                      onTap: () => _toggle(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFFFECB3)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFFFFC107)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r,
                              style: const TextStyle(
                                fontSize: 20,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? const Color(0xFFFF8F00)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
