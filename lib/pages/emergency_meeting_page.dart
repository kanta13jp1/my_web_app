import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/board_meeting_model.dart';

class EmergencyMeetingPage extends StatefulWidget {
  // テスト用にSupabaseClientを注入できるようにする
  final SupabaseClient? supabaseClient;

  const EmergencyMeetingPage({super.key, this.supabaseClient});

  @override
  State<EmergencyMeetingPage> createState() => _EmergencyMeetingPageState();
}

class _EmergencyMeetingPageState extends State<EmergencyMeetingPage> {
  final ScrollController _scrollController = ScrollController();
  BoardMeetingLog? _currentLog;
  bool _isLoading = false;
  String _loadingStatus = '';

  // テスト時は注入されたクライアントを使い、通常時はシングルトンを使う
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  Future<void> _conveneBoard() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = '各部門からデータを収集中...';
    });

    try {
      // _supabase クライアントを使用
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 修正: 型推論エラーを防ぐため <dynamic> を指定
      final results = await Future.wait<dynamic>([
        // CKO: メモ数 (int)
        _supabase.from('notes').count(CountOption.exact).eq('user_id', userId),
        // CFO: サブスク数 (int)
        _supabase
            .from('subscriptions')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0),
        // CHRO: ポイント、レベル (Map?)
        // 【修正】id -> user_id に変更して型エラー回避
        _supabase
            .from('user_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        // CSO: 断捨離 (int) - 仮置き
        Future.value(0),
      ]);

      final noteCount = results[0] as int;
      final subCount = results[1] as int;
      final userStats = results[2] as Map<String, dynamic>?;
      final danshariCount = results[3] as int;

      final points = userStats?['total_points'] ?? 0;
      final level = userStats?['current_level'] ?? 1;

      final contextPrompt = '''
緊急役員会議を開催します。各CxOは以下の【現状データ】に基づき、厳しく現状を分析し、報告してください。
最後にCSOがこれらを統合し、CEO(ユーザー)が今週末にとるべき具体的な行動プランを3つ提案してください。

【現状データ】
[CEO] ユーザーID: $userId
[CKO/知識] 蓄積メモ数: $noteCount 件
[CFO/財務] 登録サブスク数: $subCount 件
[CHRO/人事] 獲得ポイント: $points pt (Lv.$level)
[CSO/戦略] 断捨離実行数: $danshariCount 件
[CHO/健康] (データ未連携のため「運動不足の可能性」と仮定して報告)
[CMO/市場] (データ未連携のため「アプリ利用頻度」から分析)
[M&A/連携] インポート機能利用: 未確認

【発言ルール】
- 各役員は自分の専門分野のデータのみに言及すること。
- 数字が少ない場合は「怠慢である」と厳しく指摘すること。
- 数字が多い場合は「リソース過多」のリスクを指摘すること。
- 馴れ合いは不要。ビジネスライクかつ辛口に。
''';

      setState(() => _loadingStatus = 'AI役員が分析中...');

      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'hold_board_meeting',
          'topic': contextPrompt,
        },
      );

      dynamic rawData = response.data;

      // レスポンスがStringの場合はJSONパースを試みる
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (e) {
          // パース失敗時はそのまま
        }
      }

      if (rawData is Map<String, dynamic> && rawData['success'] == true) {
        final result = rawData['result'] as Map<String, dynamic>;
        final log = BoardMeetingLog.fromMap(result);

        setState(() {
          _currentLog = log;
        });

        await _saveMeetingToDb(log, contextPrompt);
      } else {
        String errorMessage = 'AI応答エラー';
        if (rawData is Map<String, dynamic>) {
          errorMessage = rawData['error']?.toString() ?? errorMessage;
        } else if (rawData is String) {
          errorMessage = rawData;
        }
        throw Exception(errorMessage);
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

  Future<void> _saveMeetingToDb(BoardMeetingLog log, String prompt) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final meetingRes = await _supabase
        .from('board_meetings')
        .insert({
          'user_id': userId,
          'topic': '定期現状分析報告会',
          'conclusion': log.conclusion,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final meetingId = meetingRes['id'];

    final messagesToInsert = log.messages.map((msg) {
      return {
        'meeting_id': meetingId,
        'speaker_name': msg.speakerName,
        'role': msg.role,
        'content': msg.content,
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    await _supabase.from('board_messages').insert(messagesToInsert);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('緊急役員会議 (経営分析)'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          if (_currentLog == null && !_isLoading)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency_share,
                        size: 80,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '各部門からの報告を受理しますか？',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '「招集」ボタンを押すと、CFO, CKO, CSOなどの全AI役員がデータベース内の最新情報を分析し、CEOであるあなたに現状報告と次の一手を提案します。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _conveneBoard,
                          icon: const Icon(Icons.notifications_active),
                          label: const Text(
                            '緊急招集する',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 24),
                    Text(
                      _loadingStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '各部門のデータを集計しています...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _currentLog!.messages.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: Text(
                          '${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日 臨時取締役会',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  if (index == _currentLog!.messages.length + 1) {
                    return _buildConclusionCard();
                  }
                  final msg = _currentLog!.messages[index - 1];
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
    final isCso = msg.role == 'CSO';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCso ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCso
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      color: isCeo ? Colors.blue[50] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(msg.role),
                  child: Icon(
                    _getRoleIcon(msg.role),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.speakerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      msg.role,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              msg.content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConclusionCard() {
    if (_currentLog?.conclusion == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rocket_launch, color: Colors.yellowAccent),
              SizedBox(width: 12),
              Text(
                'STRATEGIC DECISION',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          Text(
            _currentLog!.conclusion ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CEO':
        return Colors.blue;
      case 'CSO':
        return Colors.orange[800]!;
      case 'CFO':
        return Colors.green[700]!;
      case 'CKO':
        return Colors.purple;
      case 'CMO':
        return Colors.pink;
      case 'CHO':
        return Colors.teal;
      case 'CHRO':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'CEO':
        return Icons.person;
      case 'CSO':
        return Icons.flag;
      case 'CFO':
        return Icons.attach_money;
      case 'CKO':
        return Icons.school;
      case 'CMO':
        return Icons.analytics;
      case 'CHO':
        return Icons.favorite;
      case 'CHRO':
        return Icons.diversity_3;
      default:
        return Icons.smart_toy;
    }
  }
}
