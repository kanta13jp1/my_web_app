import 'package:flutter/material.dart';
import '../main.dart';
import '../services/ai_service.dart';
import '../utils/app_logger.dart';

/// AI秘書ページ
/// ユーザーのメモやタスクに基づいて、AIが今日/今週/今月/今年やるべきことを提案
class AISecretaryPage extends StatefulWidget {
  const AISecretaryPage({super.key});

  @override
  State<AISecretaryPage> createState() => _AISecretaryPageState();
}

class _AISecretaryPageState extends State<AISecretaryPage> {
  final AIService _aiService = AIService();
  TaskRecommendations? _recommendations;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('ユーザーがログインしていません');
      }

      final recommendations = await _aiService.getTaskRecommendations(
        userId: userId,
      );

      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error loading task recommendations',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assistant, size: 24),
            SizedBox(width: 8),
            Text('AI秘書'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadRecommendations,
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AIがあなたのタスクを分析中...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'エラーが発生しました',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadRecommendations,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendations == null) {
      return const Center(
        child: Text('推奨事項が見つかりませんでした'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AIインサイト
            if (_recommendations!.insights.isNotEmpty)
              _buildInsightsCard(),

            const SizedBox(height: 16),

            // 今日やるべきこと
            _buildTaskSection(
              title: '今日やるべきこと',
              icon: Icons.today,
              color: Colors.blue,
              tasks: _recommendations!.daily,
            ),

            const SizedBox(height: 16),

            // 今週やるべきこと
            _buildTaskSection(
              title: '今週やるべきこと',
              icon: Icons.calendar_view_week,
              color: Colors.green,
              tasks: _recommendations!.weekly,
            ),

            const SizedBox(height: 16),

            // 今月やるべきこと
            _buildTaskSection(
              title: '今月やるべきこと',
              icon: Icons.calendar_month,
              color: Colors.orange,
              tasks: _recommendations!.monthly,
            ),

            const SizedBox(height: 16),

            // 今年やるべきこと
            _buildTaskSection(
              title: '今年やるべきこと',
              icon: Icons.calendar_today,
              color: Colors.purple,
              tasks: _recommendations!.yearly,
            ),

            const SizedBox(height: 32),

            // フッター
            Center(
              child: Text(
                'AI秘書はあなたのメモとタスクを分析して推奨事項を提案します',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard() {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'AIからのインサイト',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _recommendations!.insights,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> tasks,
  }) {
    if (tasks.isEmpty) {
      return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'まだ推奨事項はありません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tasks.asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  top: index > 0 ? 8.0 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        task,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
