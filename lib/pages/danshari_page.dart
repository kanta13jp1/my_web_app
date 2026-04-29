import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // supabase
import '../models/note.dart';

class DanshariPage extends StatefulWidget {
  const DanshariPage({super.key});

  @override
  State<DanshariPage> createState() => _DanshariPageState();
}

class _DanshariPageState extends State<DanshariPage> {
  List<Note> _staleNotes = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStaleNotes();
    });
  }

  // CSOが30日以上更新のない「陳腐化案件」を抽出する
  Future<void> _fetchStaleNotes() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 30日前の日付
      final threshold =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false) // まだアーカイブされていないもの
          .lt('updated_at', threshold) // 最終更新が30日以上前
          .order('updated_at', ascending: true) // 古い順
          .limit(10); // 1回のクエストは10件まで

      if (!mounted) return;
      setState(() {
        _staleNotes =
            (response as List).map((data) => Note.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('データ取得エラー: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processNote(bool keep) async {
    final note = _staleNotes[_currentIndex];

    // アニメーション等のために少し待つならここにDelayを入れる

    try {
      if (keep) {
        // 維持: updated_at を更新して、当分出てこないようにする
        await supabase.from('notes').update({
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', note.id);
      } else {
        // 断捨離: アーカイブする
        await supabase.from('notes').update({
          'is_archived': true,
          'archived_at': DateTime.now().toIso8601String(),
        }).eq('id', note.id);
      }

      if (!mounted) return;
      setState(() {
        if (_currentIndex < _staleNotes.length - 1) {
          _currentIndex++;
        } else {
          // クエスト完了
          _staleNotes = [];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('処理エラー: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('断捨離クエスト'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staleNotes.isEmpty
              ? _buildCompletionView()
              : _buildQuestView(),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Color(0xFFFF6B35),
          ),
          const SizedBox(height: 16),
          const Text(
            '本日の断捨離完了！',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'CSO: 「素晴らしい意思決定でした、CEO。」',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('コックピットへ戻る'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestView() {
    final note = _staleNotes[_currentIndex];
    final dateStr = DateFormat('yyyy/MM/dd').format(note.updatedAt);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '残り案件: ${_staleNotes.length - _currentIndex}件',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // カード表示
          Expanded(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.history,
                          color: Color(0xFF9CA3AF),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '最終更新: $dateStr',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const Divider(height: 32),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          note.content,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // 意思決定ボタン
          const Text(
            'この案件（メモ）はまだ必要ですか？',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _processNote(false), // Archive
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                    foregroundColor: const Color(0xFFE53935),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('廃棄 (Archive)'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _processNote(true), // Keep
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('維持 (Keep)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
