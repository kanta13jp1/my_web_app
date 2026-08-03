import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/donation_project.dart';

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
  List<DonationProject> _projects = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
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
        'lifestyle-hub',
        body: {'action': 'donation.list'},
      );
      setState(
        () => _projects = DonationProject.listFromResponse(response.data),
      );
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
        backgroundColor: const Color(0xFFFF6B35),
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchProjects,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _projects.isEmpty
                  ? const Center(child: Text('プロジェクトがありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        final goal = project.goalAmount.toDouble();
                        final raised = project.raisedAmount.toDouble();
                        final progress = project.progress;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.title.isNotEmpty
                                      ? project.title
                                      : 'タイトル不明',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(project.description),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF6B35),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '¥${raised.toStringAsFixed(0)} / ¥${goal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B35),
                                    height: 1.5,
                                  ),
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
