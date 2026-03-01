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

  // Colors
  final Color _purple = const Color(0xFF7C3AED);
  final Color _bg = const Color(0xFFF8FAFC);

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
        return const ['#自分株式会社', '#X運用', '#個人開発'];
      case 'line':
        return const ['#自分株式会社', '#LINE導線', '#導線改善'];
      case 'facebook':
        return const ['#自分株式会社', '#Facebook投稿', '#導線改善'];
      case 'qr_scan':
        return const ['#自分株式会社', '#QR導線', '#導線改善'];
      default:
        return const ['#自分株式会社', '#広報'];
    }
  }

  String _buildDraftPrompt(String channelKey) {
    final channelLabel = _channelLabel(channelKey);
    final hashtags = _defaultHashtags(channelKey).join(' ');
    return '''
あなたは「自分株式会社」のCMOです。
$channelLabel向けに、そのまま使える発信文の草案を作ってください。

条件:
- 出力は必ずJSONのみ
- title は短い見出し
- body は実際に投稿・共有に使える本文
- hashtags は3〜5個の文字列配列
- $channelLabelに合う文量・テンポにする

出力形式:
{
  "title": "...",
  "body": "...",
  "hashtags": ["$hashtags"]
}
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
      'title': '$channelLabel草案',
      'body':
          normalized.isEmpty ? '$channelLabel向けの発信文をここから整えてください。' : normalized,
      'hashtags': _defaultHashtags(channelKey),
    };
  }

  Map<String, dynamic> _normalizePressReleaseResult(
    dynamic rawResult,
    String channelKey,
  ) {
    if (rawResult is Map) {
      final resultMap = Map<String, dynamic>.from(rawResult);
      final hashtags = (resultMap['hashtags'] is List)
          ? List<String>.from(
              (resultMap['hashtags'] as List)
                  .whereType<Object>()
                  .map((item) => item.toString()),
            )
          : _defaultHashtags(channelKey);
      return <String, dynamic>{
        'title':
            (resultMap['title'] ?? '${_channelLabel(channelKey)}草案').toString(),
        'body': (resultMap['body'] ?? '').toString(),
        'hashtags': hashtags.isEmpty ? _defaultHashtags(channelKey) : hashtags,
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
      final channelKey = widget.initialChannel ?? 'x_share';

      // Fetch recent data to feed the AI
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      final notes = await supabase
          .from('notes')
          .select('title')
          .eq('user_id', userId)
          .eq('is_archived', false)
          .limit(3);

      final boardData = {
        'userStats': stats,
        'recentNotes': notes,
      };
      final draftPrompt = _buildDraftPrompt(channelKey);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'improve',
          'content': '$draftPrompt\n\n参考データ:\n${jsonEncode(boardData)}',
        },
      );

      if (response.status != 200) {
        throw Exception('AI Error: ${response.status}');
      }
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(
          data['error'] as String? ?? 'Unknown error from AI function',
        );
      }

      if (mounted) {
        setState(() {
          _pressRelease =
              _normalizePressReleaseResult(data['result'], channelKey);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('発行エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sharePressRelease() {
    if (_pressRelease == null) return;
    final title = _pressRelease!['title'];
    final body = _pressRelease!['body'];
    final tags = (_pressRelease!['hashtags'] as List).join(' ');

    SharePlus.instance.share(
      ShareParams(
        text: '$title\n\n$body\n\n$tags\n#自分株式会社',
        subject: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelLabel = _channelLabel(widget.initialChannel);
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
              'あなたの実績を世界へ発信しましょう。\nAIが$channelLabel向けの発信文を自動生成します。',
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
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRESS RELEASE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pressRelease!['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 32),
                      Text(
                        _pressRelease!['body'] ?? '',
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        (_pressRelease!['hashtags'] as List).join(' '),
                        style: TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _generatePressRelease, // Retry
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
                      label: const Text('全世界へ配信'),
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
