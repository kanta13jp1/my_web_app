import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/board_meeting_model.dart';

class EmergencyMeetingPage extends StatefulWidget {
  const EmergencyMeetingPage({super.key});

  @override
  State<EmergencyMeetingPage> createState() => _EmergencyMeetingPageState();
}

class _EmergencyMeetingPageState extends State<EmergencyMeetingPage> {
  final TextEditingController _topicController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  BoardMeetingLog? _currentLog;
  bool _isLoading = false;

  Future<void> _startMeeting() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'hold_board_meeting',
          'topic': topic,
        },
      );

      // 修正: レスポンスデータの型を安全にキャスト
      final dynamic rawData = response.data;

      if (rawData is Map<String, dynamic>) {
        if (rawData['success'] == true) {
          final result = rawData['result'] as Map<String, dynamic>;
          final log = BoardMeetingLog.fromMap(result);

          setState(() {
            _currentLog = log;
          });

          await _saveMeetingToDb(log);
        } else {
          throw Exception(rawData['error'] ?? 'Unknown API error');
        }
      } else {
        // マップ型でない場合（エラー文字列などが返ってきた場合）
        throw Exception('Unexpected response format: $rawData');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('会議エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMeetingToDb(BoardMeetingLog log) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 1. 会議本体の保存
    final meetingRes = await supabase
        .from('board_meetings')
        .insert({
          'user_id': userId,
          'topic': log.topic,
          'conclusion': log.conclusion,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final meetingId = meetingRes['id'];

    // 2. 発言ログの保存
    final messagesToInsert = log.messages.map((msg) {
      return {
        'meeting_id': meetingId,
        'speaker_name': msg.speakerName,
        'role': msg.role,
        'content': msg.content,
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    await supabase.from('board_messages').insert(messagesToInsert);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('緊急役員会議')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: '議題 (Topic)',
                      hintText: '例: 売上が伸び悩んでいる...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _startMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white))
                      : const Text('招集'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _currentLog == null
                ? const Center(
                    child: Text('議題を入力して「招集」ボタンを押してください。\nAI役員たちが議論を開始します。',
                        textAlign: TextAlign.center))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentLog!.messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _currentLog!.messages.length) {
                        return _buildConclusionCard();
                      }
                      final msg = _currentLog!.messages[index];
                      return _buildMessageCard(msg);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(BoardMessage msg) {
    final isCeo = msg.role == 'CEO';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCeo ? Colors.blue[50] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(msg.role),
                  child: Text(
                    msg.speakerName.isNotEmpty
                        ? msg.speakerName.substring(0, 1)
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.speakerName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(msg.role,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(msg.content),
          ],
        ),
      ),
    );
  }

  Widget _buildConclusionCard() {
    if (_currentLog?.conclusion == null) return const SizedBox.shrink();
    return Card(
      color: Colors.red[50],
      margin: const EdgeInsets.only(top: 16, bottom: 32),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: Colors.red),
                SizedBox(width: 8),
                Text('結論 (Conclusion)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.red)),
              ],
            ),
            const Divider(color: Colors.redAccent),
            Text(_currentLog!.conclusion ?? '結論なし',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CEO':
        return Colors.blue;
      case 'CSO':
        return Colors.orange;
      case 'CFO':
        return Colors.green;
      case 'CKO':
        return Colors.purple;
      case 'CMO':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
