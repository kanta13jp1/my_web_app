import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// パフォーマンスレビューページ
/// performance-review Edge Function と連携して評価・フィードバックを管理
class PerformanceReviewPage extends StatefulWidget {
  const PerformanceReviewPage({super.key});

  @override
  State<PerformanceReviewPage> createState() => _PerformanceReviewPageState();
}

class _PerformanceReviewPageState extends State<PerformanceReviewPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['new', 'history'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _reviews = [];
  late final TabController _tabController;

  final _goalCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  double _selfScore = 3.0;
  String _reviewPeriod = '2026 Q1';

  static const _periods = ['2026 Q1', '2026 Q2', '2026 Q3', '2026 Q4'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _goalCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReviews() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('enterprise-hub', body: {'action': 'review.list'});
      final data = response.data;
      if (data is Map<String, dynamic> && data['reviews'] is List) {
        setState(
          () =>
              _reviews = (data['reviews'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _reviews = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'レビュー一覧の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_goalCtrl.text.isEmpty || _feedbackCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目標と振り返りを入力してください')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'review.create',
          'period': _reviewPeriod,
          'goals': _goalCtrl.text,
          'self_feedback': _feedbackCtrl.text,
          'self_score': _selfScore.toInt(),
        },
      );
      _goalCtrl.clear();
      _feedbackCtrl.clear();
      await _fetchReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レビューを提出しました')),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '提出に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _scoreColor(int score) {
    if (score >= 4) return const Color(0xFF4CAF50);
    if (score >= 3) return const Color(0xFF6366F1);
    return const Color(0xFFFF6B35);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パフォーマンスレビュー'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit, size: 18), text: '新規レビュー'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: '履歴'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReviews,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 新規レビュータブ
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _reviewPeriod,
                  decoration: const InputDecoration(
                    labelText: '評価期間',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _periods
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _reviewPeriod = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _goalCtrl,
                  decoration: const InputDecoration(
                    labelText: '目標・達成事項',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: '例: 新機能Xをリリース、チームの生産性20%向上',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _feedbackCtrl,
                  decoration: const InputDecoration(
                    labelText: '自己振り返り',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: '例: 技術的負債の解消が遅れた、コミュニケーションを改善できた',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                Text(
                  '自己評価: ${_selfScore.toInt()} / 5',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                Slider(
                  value: _selfScore,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _selfScore.toInt().toString(),
                  onChanged: (v) => setState(() => _selfScore = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send, size: 16),
                    label: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('提出する'),
                    onPressed: _isLoading ? null : _submitReview,
                  ),
                ),
              ],
            ),
          ),
          // 履歴タブ
          _isLoading && _reviews.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _reviews.isEmpty
                  ? const Center(child: Text('レビュー履歴はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _reviews.length,
                      itemBuilder: (context, i) {
                        final r = _reviews[i];
                        final score = r['self_score'] as int? ?? 0;
                        return Card(
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: _scoreColor(score).withAlpha(30),
                              child: Text(
                                score.toString(),
                                style: TextStyle(
                                  color: _scoreColor(score),
                                  fontWeight: FontWeight.bold,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            title: Text(
                              r['period'] as String? ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              r['goals'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '目標・達成事項:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                    Text(
                                      r['goals'] as String? ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '自己振り返り:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                    Text(
                                      r['self_feedback'] as String? ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
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
        ],
      ),
    );
  }
}
