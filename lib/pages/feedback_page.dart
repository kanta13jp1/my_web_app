import 'package:flutter/material.dart';

import '../main.dart';
import '../utils/app_logger.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String _selectedCategory = 'feature';
  bool _isSubmitting = false;

  final Map<String, String> _categories = const <String, String>{
    'feature': '機能改善・追加要望',
    'bug': '不具合・動作不良',
    'other': 'その他',
  };

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        throw Exception('ログインが必要です');
      }

      final response = await supabase.functions.invoke(
        'feature-request-manager',
        headers: <String, String>{
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: <String, dynamic>{
          'action': 'submit_feedback_ticket',
          'category': _selectedCategory,
          'content': _contentController.text.trim(),
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (response.status != 201 || data?['success'] != true) {
        throw Exception(
          data?['error']?.toString() ?? '投稿に失敗しました',
        );
      }

      final thankYouEmailSent = data?['thankYouEmailSent'] == true;
      final githubIssueCreated = data?['githubIssueCreated'] == true;
      final githubIssueNumber = data?['githubIssueNumber']?.toString();
      final warnings = data?['warnings'] is List
          ? List<String>.from(data!['warnings'] as List)
          : const <String>[];

      final lines = <String>[
        'フィードバックを受け付けました。ありがとうございます。',
        if (thankYouEmailSent) '投稿ありがとうメールを送信しました。',
        if (githubIssueCreated && githubIssueNumber != null)
          'GitHub Issue #$githubIssueNumber に登録しました。',
        if (warnings.isNotEmpty) '一部の自動処理はバックグラウンドで再実行されます。',
      ];

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lines.join('\n')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error submitting feedback',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('投稿に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ご意見・ご要望',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '送信後は投稿ありがとうメールをお送りします。あわせて GitHub Issue に登録し、'
                        'Claude Managed Agents と github-issue-fix キューで対応を追跡します。',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'カテゴリ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: _categories.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '内容',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '例: カレンダー画面で画像付きメモを貼れるようにしてほしい、など',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '内容を入力してください';
                  }
                  if (value.trim().length < 5) {
                    return 'もう少し詳しく書いていただけると助かります';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? '送信中...' : '送信する',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
