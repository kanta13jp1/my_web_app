import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ミーティング管理ページ
/// meeting-manager Edge Function と連携してミーティングの一覧・作成を提供
class MeetingManagerPage extends StatefulWidget {
  const MeetingManagerPage({super.key});

  @override
  State<MeetingManagerPage> createState() => _MeetingManagerPageState();
}

class _MeetingManagerPageState extends State<MeetingManagerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _meetings = [];

  @override
  void initState() {
    super.initState();
    _fetchMeetings();
  }

  Future<void> _fetchMeetings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'meeting-manager',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['meetings'] is List) {
        setState(() => _meetings = data['meetings'] as List);
      } else if (data is List) {
        setState(() => _meetings = data);
      } else {
        setState(() => _meetings = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'データ取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ミーティング管理'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchMeetings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchMeetings,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _meetings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'ミーティングはありません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _meetings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _meetings[i] as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.withAlpha(30),
                              child: const Icon(
                                Icons.video_camera_front,
                                color: Colors.teal,
                              ),
                            ),
                            title: Text(
                              item['title']?.toString() ?? '(無題)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              item['description']?.toString() ??
                                  item['date']?.toString() ??
                                  '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              item['status']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
