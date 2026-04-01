import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 顧客フィードバック・NPSページ
/// customer-feedback Edge Function と連携してフィードバック管理を提供
class CustomerFeedbackPage extends StatefulWidget {
  const CustomerFeedbackPage({super.key});

  @override
  State<CustomerFeedbackPage> createState() => _CustomerFeedbackPageState();
}

class _CustomerFeedbackPageState extends State<CustomerFeedbackPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _feedbacks = [];
  Map<String, dynamic>? _nps;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final npsRes = await _supabase.functions.invoke(
        'customer-feedback',
        queryParameters: {'view': 'nps'},
      );
      if (npsRes.data is Map<String, dynamic>) {
        final d = npsRes.data as Map<String, dynamic>;
        if (d['nps'] is Map<String, dynamic>) {
          setState(() => _nps = d['nps'] as Map<String, dynamic>);
        }
      }
      final listRes = await _supabase.functions.invoke(
        'customer-feedback',
        queryParameters: {'view': 'list'},
      );
      final data = listRes.data;
      if (data is Map<String, dynamic> && data['feedbacks'] is List) {
        setState(() => _feedbacks = data['feedbacks'] as List);
      } else if (data is List) {
        setState(() => _feedbacks = data);
      } else {
        setState(() => _feedbacks = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _sentimentColor(String? sentiment) {
    switch (sentiment) {
      case 'very_positive':
        return Colors.green;
      case 'positive':
        return Colors.lightGreen;
      case 'neutral':
        return Colors.grey;
      case 'negative':
        return Colors.orange;
      case 'very_negative':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _sentimentIcon(String? sentiment) {
    switch (sentiment) {
      case 'very_positive':
        return Icons.sentiment_very_satisfied;
      case 'positive':
        return Icons.sentiment_satisfied;
      case 'neutral':
        return Icons.sentiment_neutral;
      case 'negative':
        return Icons.sentiment_dissatisfied;
      case 'very_negative':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.feedback_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('顧客フィードバック'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetch,
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
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_nps != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Colors.deepPurple.withAlpha(15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _npsMetric('NPS スコア', '${_nps!['score'] ?? 0}'),
                            _npsMetric('回答数', '${_nps!['totalResponses'] ?? 0}'),
                            _npsMetric('推薦者', '${_nps!['promoters'] ?? 0}'),
                            _npsMetric('批判者', '${_nps!['detractors'] ?? 0}'),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _feedbacks.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.feedback_outlined, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'フィードバックはありません',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _feedbacks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final item = _feedbacks[i] as Map<String, dynamic>;
                                final sentiment = item['sentiment']?.toString();
                                final category = item['category']?.toString();
                                final content = item['content']?.toString() ?? item['message']?.toString() ?? '';
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _sentimentColor(sentiment).withAlpha(30),
                                      child: Icon(
                                        _sentimentIcon(sentiment),
                                        color: _sentimentColor(sentiment),
                                      ),
                                    ),
                                    title: Text(
                                      content.length > 80 ? '${content.substring(0, 80)}...' : content,
                                    ),
                                    subtitle: category != null ? Text(category) : null,
                                    trailing: sentiment != null
                                        ? Icon(
                                            _sentimentIcon(sentiment),
                                            color: _sentimentColor(sentiment),
                                            size: 18,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _npsMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
