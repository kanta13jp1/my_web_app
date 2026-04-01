import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 寄付・クラウドファンディングページ
/// donation-crowdfunding Edge Function と連携して寄付プロジェクトを管理
class DonationCrowdfundingPage extends StatefulWidget {
  const DonationCrowdfundingPage({super.key});

  @override
  State<DonationCrowdfundingPage> createState() =>
      _DonationCrowdfundingPageState();
}

class _DonationCrowdfundingPageState extends State<DonationCrowdfundingPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'donation-crowdfunding',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['projects'] is List) {
        setState(() => _projects = data['projects'] as List);
      } else if (data is List) {
        setState(() => _projects = data);
      } else {
        setState(() => _projects = []);
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
        title: const Text('寄付・クラウドファンディング'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _fetchProjects,
                          child: const Text('再試行')),
                    ],
                  ),
                )
              : _projects.isEmpty
                  ? const Center(child: Text('プロジェクトがありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project =
                            _projects[index] as Map<String, dynamic>;
                        final goal =
                            (project['goal_amount'] as num?)?.toDouble() ?? 0;
                        final raised =
                            (project['raised_amount'] as num?)?.toDouble() ?? 0;
                        final progress = goal > 0 ? raised / goal : 0.0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project['title']?.toString() ?? 'タイトル不明',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(project['description']?.toString() ?? ''),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey[200],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.pink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '¥${raised.toStringAsFixed(0)} / ¥${goal.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.pink),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
