// lib/pages/admin/feedback_list_page.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../main.dart';
import '../../utils/app_logger.dart';

class FeedbackListPage extends StatefulWidget {
  const FeedbackListPage({super.key});

  @override
  State<FeedbackListPage> createState() => _FeedbackListPageState();
}

class _FeedbackListPageState extends State<FeedbackListPage> {
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    try {
      setState(() => _isLoading = true);

      // 管理者ポリシーにより、全件取得が可能になっているはず
      // user_profilesのリレーション設定が複雑な場合を考慮し、まずはuser_idのみ取得
      // もしuser_profilesとの外部キー制約が設定されていれば、.select('*, user_profiles(display_name)') などが可能
      final data = await supabase
          .from('app_feedback')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _feedbacks = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error loading feedbacks',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    try {
      await supabase
          .from('app_feedback')
          .update({'status': newStatus}).eq('id', id);

      // ローカルのリストも更新
      setState(() {
        final index = _feedbacks.indexWhere((f) => f['id'] == id);
        if (index != -1) {
          _feedbacks[index]['status'] = newStatus;
        }
      });

      // 「対応完了」に変更した場合、投稿者にリリース通知メールを送る
      if (newStatus == 'implemented') {
        try {
          final session = supabase.auth.currentSession;
          final payload = <String, dynamic>{
            'appFeedbackId': id,
            'status': 'done',
            'markAsResolved': true,
            'resolutionSummary': '管理画面から対応完了として反映しました。最新のリリース内容をご確認ください。',
          };

          if (session == null) {
            await supabase.functions.invoke(
              'notify-feature-request',
              body: payload,
            );
          } else {
            await supabase.functions.invoke(
              'notify-feature-request',
              headers: <String, String>{
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: payload,
            );
          }
        } catch (notifyErr) {
          AppLogger.error(
            'Failed to send release notification',
            error: notifyErr,
          );
          // 通知失敗はステータス変更の成功には影響させない
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'implemented'
                  ? 'ステータスを対応完了に更新し、投稿者に通知しました ✅'
                  : 'ステータスを $newStatus に更新しました',
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error updating status', error: e);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.red;
      case 'reviewed':
        return const Color(0xFFFF6B35);
      case 'implemented':
        return Colors.green;
      default:
        return const Color(0xFFB0B0B0);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'feature':
        return Icons.lightbulb;
      case 'bug':
        return Icons.bug_report;
      default:
        return Icons.chat_bubble;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('【管理】フィードバック一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFeedbacks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedbacks.isEmpty
              ? const Center(child: Text('フィードバックはまだありません'))
              : ListView.builder(
                  itemCount: _feedbacks.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final fb = _feedbacks[index];
                    final date = DateTime.parse(fb['created_at']).toLocal();
                    final status = fb['status'] ?? 'new';
                    final userId = fb['user_id'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getStatusColor(status).withValues(alpha: 0.2),
                          child: Icon(
                            _getCategoryIcon(fb['category']),
                            color: _getStatusColor(status),
                          ),
                        ),
                        title: Text(
                          fb['content'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${timeago.format(date, locale: 'ja')} • $userId',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  '詳細内容:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(fb['content']),
                                if (fb['github_issue_url'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'GitHub Issue: ${fb['github_issue_url']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5C6BC0),
                                    ),
                                  ),
                                ],
                                if (fb['user_email'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '投稿者メール: ${fb['user_email']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Text(
                                  'ステータス変更:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatusButton(
                                      fb['id'],
                                      'new',
                                      '未対応',
                                      status,
                                    ),
                                    _buildStatusButton(
                                      fb['id'],
                                      'reviewed',
                                      '確認済',
                                      status,
                                    ),
                                    _buildStatusButton(
                                      fb['id'],
                                      'implemented',
                                      '対応完',
                                      status,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusButton(
    int id,
    String statusKey,
    String label,
    String currentStatus,
  ) {
    final isSelected = statusKey == currentStatus;
    return ElevatedButton(
      onPressed: isSelected ? null : () => _updateStatus(id, statusKey),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? _getStatusColor(statusKey) : null,
        foregroundColor: isSelected ? Colors.white : null,
      ),
      child: Text(label),
    );
  }
}
