import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_feedback_entry.dart';

/// カスタマーフィードバックページ
/// social-commerce-hub Edge Function (feedback.list) と連携してフィードバックを収集・管理
class CustomerFeedbackPage extends StatefulWidget {
  const CustomerFeedbackPage({super.key});

  @override
  State<CustomerFeedbackPage> createState() => _CustomerFeedbackPageState();
}

class _CustomerFeedbackPageState extends State<CustomerFeedbackPage> {
  final _supabase = Supabase.instance.client;
  final _feedbackController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<CustomerFeedbackEntry> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedbacks() async {
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
        'social-commerce-hub',
        body: {'action': 'feedback.list'},
      );
      final feedbacks = parseCustomerFeedback(response.data);
      if (mounted) setState(() => _feedbacks = feedbacks);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'フィードバックの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'feedback.submit', 'comment': text},
      );
      _feedbackController.clear();
      await _fetchFeedbacks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フィードバックを送信しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'フィードバックの送信に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// ISO タイムスタンプの日付部分 (yyyy-MM-dd) を返す。
  String _shortDate(String raw) =>
      raw.length >= 10 ? raw.substring(0, 10) : raw;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カスタマーフィードバック'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFeedbacks,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'フィードバックを入力',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitFeedback,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('送信'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'フィードバック一覧',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _feedbacks.isEmpty
                      ? const Center(child: Text('フィードバックはありません'))
                      : ListView.builder(
                          itemCount: _feedbacks.length,
                          itemBuilder: (context, index) {
                            final item = _feedbacks[index];
                            final meta = [
                              if (item.type.isNotEmpty) item.type,
                              if (item.rating != null) '★${item.rating}',
                              if (item.createdAt.isNotEmpty)
                                _shortDate(item.createdAt),
                            ].join(' · ');
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.feedback_outlined),
                                title: Text(item.displayText),
                                subtitle: meta.isNotEmpty ? Text(meta) : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
