import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';

class CmoPage extends StatefulWidget {
  final String? initialChannel;
  final bool autoGenerateOnOpen;

  const CmoPage({
    super.key,
    this.initialChannel,
    this.autoGenerateOnOpen = false,
  });

  @override
  State<CmoPage> createState() => _CmoPageState();
}

class _CmoPageState extends State<CmoPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _pressRelease;

  final Color _purple = const Color(0xFF7C3AED);
  final Color _bg = const Color(0xFFF8FAFC);

  String _channelKey() => widget.initialChannel ?? 'x_share';

  String _channelLabel(String? channelKey) {
    switch (channelKey) {
      case 'x_share':
        return 'X投稿';
      case 'line':
        return 'LINE導線';
      case 'facebook':
        return 'Facebook投稿';
      case 'qr_scan':
        return 'QR導線';
      default:
        return 'プレスリリース';
    }
  }

  List<String> _defaultHashtags(String? channelKey) {
    switch (channelKey) {
      case 'x_share':
        return const ['#自分株式会社', '#X投稿', '#集客改善'];
      case 'line':
        return const ['#自分株式会社', '#LINE導線', '#導線改善'];
      case 'facebook':
        return const ['#自分株式会社', '#Facebook投稿', '#集客改善'];
      case 'qr_scan':
        return const ['#自分株式会社', '#QR導線', '#導線改善'];
      default:
        return const ['#自分株式会社', '#広報', '#発信'];
    }
  }

  Map<String, String> _channelPromptSpec(String channelKey) {
    switch (channelKey) {
      case 'x_share':
        return const <String, String>{
          'goal': 'Create a short X post that can be understood in 3 seconds.',
          'titleRule': 'Use a punchy title under 28 Japanese characters.',
          'bodyRule':
              'Write 80-140 Japanese characters. Use one hook, one benefit, and one call to action.',
          'tone': 'sharp, compact, high-contrast',
        };
      case 'facebook':
        return const <String, String>{
          'goal':
              'Create a longer Facebook post that explains context and builds trust.',
          'titleRule':
              'Use a descriptive title around 28-48 Japanese characters.',
          'bodyRule':
              'Write 220-420 Japanese characters across three short paragraphs: problem, concrete value, and call to action.',
          'tone': 'warm, persuasive, slightly detailed',
        };
      case 'line':
        return const <String, String>{
          'goal':
              'Create a short LINE message that drives one immediate action.',
          'titleRule': 'Use a direct title under 24 Japanese characters.',
          'bodyRule':
              'Write 60-120 Japanese characters focused on one action only.',
          'tone': 'personal, direct, frictionless',
        };
      case 'qr_scan':
        return const <String, String>{
          'goal':
              'Create copy for a QR prompt or landing snippet that makes scanning worthwhile.',
          'titleRule':
              'Use a utility-first title around 20-36 Japanese characters.',
          'bodyRule':
              'Write 90-180 Japanese characters explaining the immediate payoff after scanning.',
          'tone': 'practical, clear, low-friction',
        };
      default:
        return const <String, String>{
          'goal': 'Create concise public-facing share copy.',
          'titleRule': 'Use a short, clear title.',
          'bodyRule': 'Write a concise body with one clear call to action.',
          'tone': 'clear and useful',
        };
    }
  }

  String _buildDraftPrompt(String channelKey) {
    final channelLabel = _channelLabel(channelKey);
    final spec = _channelPromptSpec(channelKey);
    final hashtags = _defaultHashtags(channelKey).join(' ');

    return '''
You are the CMO of Me Inc.
Write Japanese copy optimized for $channelLabel.

Channel objective:
- ${spec['goal']}

Output rules:
- Return JSON only.
- Do not include markdown or code fences.
- Use keys: title, body, hashtags.
- title: ${spec['titleRule']}
- body: ${spec['bodyRule']}
- tone: ${spec['tone']}
- hashtags: return exactly 3 short hashtags suitable for $channelLabel.

Output format:
{
  "title": "...",
  "body": "...",
  "hashtags": ["...", "...", "..."]
}

Preferred hashtag direction:
$hashtags
''';
  }

  String? _extractFirstJsonObject(String text) {
    final trimmed = text.trim();
    final start = trimmed.indexOf('{');
    if (start == -1) return null;

    var inString = false;
    var isEscaped = false;
    var depth = 0;

    for (var i = start; i < trimmed.length; i++) {
      final char = trimmed[i];
      if (inString) {
        if (isEscaped) {
          isEscaped = false;
        } else if (char == r'\') {
          isEscaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == '{') {
        depth++;
        continue;
      }
      if (char == '}') {
        depth--;
        if (depth == 0) {
          return trimmed.substring(start, i + 1);
        }
      }
    }

    return trimmed.substring(start);
  }

  Map<String, dynamic> _fallbackPressReleaseFromText(
    String rawText,
    String channelKey,
  ) {
    final channelLabel = _channelLabel(channelKey);
    final normalized = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return <String, dynamic>{
      'title': '$channelLabelの草案',
      'body':
          normalized.isEmpty ? '$channelLabel向けの草案をここから整えてください。' : normalized,
      'hashtags': _defaultHashtags(channelKey).take(3).toList(),
    };
  }

  List<String> _normalizeHashtags(dynamic rawHashtags, String channelKey) {
    final fallback = _defaultHashtags(channelKey).take(3).toList();
    if (rawHashtags is! List) return fallback;

    final normalized = rawHashtags
        .whereType<Object>()
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(3)
        .toList();

    return normalized.isEmpty ? fallback : normalized;
  }

  Map<String, dynamic> _normalizePressReleaseResult(
    dynamic rawResult,
    String channelKey,
  ) {
    if (rawResult is Map) {
      final resultMap = Map<String, dynamic>.from(rawResult);
      final hashtags = _normalizeHashtags(resultMap['hashtags'], channelKey);
      return <String, dynamic>{
        'title': (resultMap['title'] ?? '${_channelLabel(channelKey)}の草案')
            .toString(),
        'body': (resultMap['body'] ?? '').toString(),
        'hashtags': hashtags,
      };
    }

    final resultText = rawResult?.toString().trim() ?? '';
    if (resultText.isEmpty) {
      return _fallbackPressReleaseFromText('', channelKey);
    }

    final jsonCandidate = _extractFirstJsonObject(resultText);
    if (jsonCandidate != null) {
      try {
        final decoded = jsonDecode(jsonCandidate);
        if (decoded is Map) {
          return _normalizePressReleaseResult(decoded, channelKey);
        }
      } on FormatException {
        // Fall through to plain-text fallback.
      }
    }

    return _fallbackPressReleaseFromText(resultText, channelKey);
  }

  Map<String, dynamic> _normalizeInvokePayload(dynamic rawPayload) {
    if (rawPayload is Map) {
      return Map<String, dynamic>.from(rawPayload);
    }

    final payloadText = rawPayload?.toString().trim() ?? '';
    if (payloadText.isEmpty) {
      return const <String, dynamic>{};
    }

    final jsonCandidate = _extractFirstJsonObject(payloadText) ?? payloadText;
    try {
      final decoded = jsonDecode(jsonCandidate);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      // Fall back to wrapping the raw text.
    }

    return <String, dynamic>{
      'success': false,
      'error': 'Invalid AI payload',
      'result': payloadText,
    };
  }

  void _showRecoverableAiError(String errorText) {
    if (!mounted) return;

    final hint = switch (errorText) {
      'Invalid AI payload' =>
        'Edge Function の返却形式が崩れています。JSON文字列か JSON オブジェクトで返すよう確認してください。',
      _ => 'APIキー、ai-assistant 関数、選択モデルを確認してから再生成してください。',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('起案エラー: $errorText\n復旧ヒント: $hint'),
      ),
    );
  }

  String _descriptionText(String channelKey) {
    switch (channelKey) {
      case 'x_share':
        return '3秒で伝わる短文の共有案を起案します。';
      case 'facebook':
        return '文脈まで伝わる長文の共有案を起案します。';
      case 'line':
        return '1アクションに絞った短い導線文を起案します。';
      case 'qr_scan':
        return 'QRで遷移したくなる導線文を起案します。';
      default:
        return 'あなたの実績を外向きの文面に整えます。';
    }
  }

  int _characterCount(String text) =>
      text.replaceAll(RegExp(r'\s+'), '').length;

  List<String> _splitFacebookBody(String body) {
    final paragraphs = body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (paragraphs.length >= 3) {
      return <String>[
        paragraphs.first,
        paragraphs.sublist(1, paragraphs.length - 1).join('\n'),
        paragraphs.last,
      ];
    }

    final rawSentences = body
        .split(RegExp(r'[。！？]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (rawSentences.length >= 3) {
      final intro = '${rawSentences.first}。';
      final middleBody = rawSentences.sublist(1, rawSentences.length - 1);
      final middle = '${middleBody.join('。')}。';
      final close = '${rawSentences.last}。';
      return <String>[intro, middle, close];
    }

    final normalized = body.trim();
    if (normalized.isEmpty) {
      return const <String>['', '', ''];
    }

    final totalLength = normalized.length;
    final firstCut = (totalLength / 3).ceil();
    final secondCut = ((totalLength * 2) / 3).ceil();
    return <String>[
      normalized.substring(0, firstCut).trim(),
      normalized.substring(firstCut, secondCut).trim(),
      normalized.substring(secondCut).trim(),
    ];
  }

  Widget _buildTagRow() {
    final tags = List<String>.from(
      _pressRelease?['hashtags'] as List? ?? const <String>[],
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: _purple,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTemplateLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body.isEmpty ? '未生成' : body,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildXTemplate() {
    final title = (_pressRelease?['title'] ?? '').toString();
    final body = (_pressRelease?['body'] ?? '').toString();
    final previewText =
        [title, body].where((part) => part.trim().isNotEmpty).join('\n');
    final count = _characterCount(previewText);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTemplateLabel('短文テンプレ'),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count文字',
                    style: TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard('見出し', title),
            const SizedBox(height: 12),
            _buildSectionCard('本文', body),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                previewText.isEmpty ? '未生成' : previewText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildTagRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildFacebookTemplate() {
    final title = (_pressRelease?['title'] ?? '').toString();
    final body = (_pressRelease?['body'] ?? '').toString();
    final sections = _splitFacebookBody(body);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplateLabel('長文テンプレ'),
            const SizedBox(height: 16),
            _buildSectionCard('見出し', title),
            const SizedBox(height: 12),
            _buildSectionCard('導入', sections[0]),
            const SizedBox(height: 12),
            _buildSectionCard('本文', sections[1]),
            const SizedBox(height: 12),
            _buildSectionCard('締め / CTA', sections[2]),
            const SizedBox(height: 14),
            _buildTagRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardTemplate() {
    final title = (_pressRelease?['title'] ?? '').toString();
    final body = (_pressRelease?['body'] ?? '').toString();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplateLabel('標準テンプレ'),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 28),
            Text(
              body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            _buildTagRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String channelKey) {
    switch (channelKey) {
      case 'x_share':
        return _buildXTemplate();
      case 'facebook':
        return _buildFacebookTemplate();
      default:
        return _buildStandardTemplate();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoGenerateOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _generatePressRelease();
      });
    }
  }

  Future<void> _generatePressRelease() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final channelKey = _channelKey();
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      final notes = await supabase
          .from('notes')
          .select('title, content')
          .eq('user_id', userId)
          .eq('is_archived', false)
          .limit(3);

      final boardData = <String, dynamic>{
        'userStats': stats,
        'recentNotes': notes,
      };
      final draftPrompt = _buildDraftPrompt(channelKey);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: <String, dynamic>{
          'action': 'improve',
          'content': '$draftPrompt\n\nContext:\n${jsonEncode(boardData)}',
        },
      );

      if (response.status != 200) {
        throw Exception('AI Error: ${response.status}');
      }

      final data = _normalizeInvokePayload(response.data);
      if (data['success'] != true) {
        _showRecoverableAiError(
          data['error'] as String? ?? 'Unknown error from AI function',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _pressRelease =
            _normalizePressReleaseResult(data['result'], channelKey);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('起案エラー: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _sharePressRelease() {
    if (_pressRelease == null) return;
    final title = (_pressRelease!['title'] ?? '').toString();
    final body = (_pressRelease!['body'] ?? '').toString();
    final tags = (_pressRelease!['hashtags'] as List).join(' ');

    SharePlus.instance.share(
      ShareParams(
        text: '$title\n\n$body\n\n$tags',
        subject: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelKey = _channelKey();
    final channelLabel = _channelLabel(channelKey);
    final draftButtonLabel = '$channelLabelの草案を起案する';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('広報室 (CMO)'),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.campaign, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _descriptionText(channelKey),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_pressRelease == null)
              ElevatedButton.icon(
                onPressed: _generatePressRelease,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: Text(draftButtonLabel),
              ),
            if (_pressRelease != null) ...[
              _buildResultCard(channelKey),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _generatePressRelease,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('再生成'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sharePressRelease,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('外部へ共有'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
