import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/models/board_meeting_model.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:provider/provider.dart';

class EmergencyMeetingPage extends StatefulWidget {
  const EmergencyMeetingPage({super.key});

  @override
  State<EmergencyMeetingPage> createState() => _EmergencyMeetingPageState();
}

class _EmergencyMeetingPageState extends State<EmergencyMeetingPage> {
  final TextEditingController _topicController = TextEditingController();
  bool _isLoading = false;
  BoardMeetingLog? _currentLog;
  final ScrollController _scrollController = ScrollController();

  // 役員ごとのアイコン色定義
  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'CEO':
        return const Color(0xFF0F172A); // Navy
      case 'CSO':
        return ThemeService.roleCso;
      case 'CFO':
        return ThemeService.roleCfo;
      case 'CKO':
        return ThemeService.roleCko;
      case 'CMO':
        return ThemeService.roleCmo;
      case 'CTO':
        return Colors.orange.shade800; // CTO (Tech)
      default:
        return Colors.grey;
    }
  }

  Future<void> _startMeeting() async {
    if (_topicController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentLog = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final topic = _topicController.text.trim();

      // 1. Edge Function 呼び出し
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'hold_board_meeting',
          'topic': topic,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        final result = data['result'];
        final log = BoardMeetingLog.fromJson(result);

        setState(() {
          _currentLog = log;
        });

        // 2. DBへの保存 (永続化)
        await _saveToDatabase(topic, log);
      } else {
        throw Exception('Meeting failed: ${data?['error']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToDatabase(String topic, BoardMeetingLog log) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Meetings テーブルへ保存
      final meetingRes = await supabase
          .from('board_meetings')
          .insert({
            'user_id': user.id,
            'topic': topic,
            'conclusion': log.conclusion,
          })
          .select()
          .single();

      final meetingId = meetingRes['id'];

      // Messages テーブルへ保存
      final messagesData = log.messages.map((msg) {
        return {
          'meeting_id': meetingId,
          'speaker_name': msg.name,
          'role': msg.role,
          'content': msg.text,
        };
      }).toList();

      await supabase.from('board_messages').insert(messagesData);
    } catch (e) {
      debugPrint('DB保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('緊急役員会議 (Emergency Board)'),
        backgroundColor: Colors.red.shade900, // 緊急事態感
      ),
      body: Column(
        children: [
          // 上部: 議題入力エリア
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? Colors.black26 : Colors.red.shade50,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      labelText: '議題を入力 (例: 新規事業の方向性について)',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startMeeting,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.groups),
                  label: const Text('招集'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
          ),

          // 中央: 会議ログ表示エリア
          Expanded(
            child: _currentLog == null
                ? Center(
                    child: _isLoading
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              CircularProgressIndicator(),
                              SizedBox(height: 20),
                              Text('役員を招集し、議論を行っています...'),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.meeting_room_outlined,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                '議題を入力して「招集」ボタンを押してください',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _currentLog!.messages.length + 1, // +1 for conclusion
                    itemBuilder: (context, index) {
                      if (index == _currentLog!.messages.length) {
                        // 結論カード
                        return Card(
                          margin: const EdgeInsets.only(top: 24, bottom: 24),
                          color: isDark
                              ? Colors.green[900]!.withOpacity(0.3)
                              : Colors.green[50],
                          shape: RoundedRectangleBorder(
                              side: BorderSide(color: Colors.green.shade800),
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text('BOARD DECISION',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                            letterSpacing: 1.2)),
                                  ],
                                ),
                                const Divider(),
                                Text(
                                  _currentLog!.conclusion ?? '結論なし',
                                  style: const TextStyle(
                                      fontSize: 16, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final msg = _currentLog!.messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: _getRoleColor(msg.role),
                              child: Text(
                                msg.name.substring(0, 1),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        msg.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(msg.role)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: _getRoleColor(msg.role),
                                              width: 0.5),
                                        ),
                                        child: Text(
                                          msg.role,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _getRoleColor(msg.role),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      msg.text,
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
