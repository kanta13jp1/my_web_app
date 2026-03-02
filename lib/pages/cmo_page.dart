import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
        return '共有文';
    }
  }

  String _descriptionText(String channelKey) {
    switch (channelKey) {
      case 'x_share':
        return 'Xで流入を作るための短文投稿を自動生成します。';
      case 'line':
        return '1アクションに絞った短い導線文を生成します。';
      case 'facebook':
        return '背景説明を含む長文の投稿文を生成します。';
      case 'qr_scan':
        return 'QRスキャン後の行動につながる導線文を生成します。';
      default:
        return '外部共有に使える短い告知文を生成します。';
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
          'goal': 'X向けに3秒で伝わる短文を作る',
          'titleRule': '見出しは28文字以内で強いフックを入れる',
          'bodyRule': '本文は80-140文字。問題提起、便益、CTAを1つずつ入れる',
          'tone': 'sharp, compact, high-contrast',
        };
      case 'facebook':
        return const <String, String>{
          'goal': 'Facebook向けに文脈説明つきの長文を作る',
          'titleRule': '見出しは28-48文字で内容が分かるようにする',
          'bodyRule': '本文は220-420文字。課題、価値、CTAの3段落で書く',
          'tone': 'warm, persuasive, slightly detailed',
        };
      case 'line':
        return const <String, String>{
          'goal': 'LINE向けに1アクションだけ促す短文を作る',
          'titleRule': '見出しは24文字以内で直接的に書く',
          'bodyRule': '本文は60-120文字。余計な説明を削って1行動に絞る',
          'tone': 'personal, direct, frictionless',
        };
      case 'qr_scan':
        return const <String, String>{
          'goal': 'QRスキャンの価値がすぐ伝わる短文を作る',
          'titleRule': '見出しは20-36文字で実利を優先して書く',
          'bodyRule': '本文は90-180文字。スキャン後の利得を具体化する',
          'tone': 'practical, clear, low-friction',
        };
      default:
        return const <String, String>{
          'goal': '共有用の短い告知文を作る',
          'titleRule': '見出しは短く明確にする',
          'bodyRule': '本文は簡潔に書き、CTAは1つに絞る',
          'tone': 'clear and useful',
        };
    }
  }

  String _buildDraftPrompt(String channelKey) {
    final channelLabel = _channelLabel(channelKey);
    final spec = _channelPromptSpec(channelKey);
    final hashtags = _defaultHashtags(channelKey).join(' ');

    return '''
あなたは自分株式会社のCMOです。
$channelLabel 向けの日本語コピーを作成してください。

目的:
- ${spec['goal']}

出力条件:
- JSONのみを返す
- Markdownやコードフェンスは禁止
- keys は title, body, hashtags
- title: ${spec['titleRule']}
- body: ${spec['bodyRule']}
- tone: ${spec['tone']}
- hashtags: $channelLabel に適した短いハッシュタグを3件

出力形式:
{
  "title": "...",
  "body": "...",
  "hashtags": ["...", "...", "..."]
}

推奨ハッシュタグ:
$hashtags
''';
  }

  String? _extractFirstJsonObject(String text) {
    final trimmed = text.trim();
    final start = trimmed.indexOf('{');
    if (start == -1) return null;

    var inString = false;
    var escaped = false;
    var depth = 0;

    for (var i = start; i < trimmed.length; i++) {
      final char = trimmed[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return trimmed.substring(start, i + 1);
        }
      }
    }

    return trimmed.substring(start);
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
      // Fall back below.
    }

    return <String, dynamic>{
      'success': false,
      'error': payloadText,
    };
  }

  List<String> _normalizeHashtags(dynamic rawHashtags, String channelKey) {
    final fallback = _defaultHashtags(channelKey);
    if (rawHashtags is! List) return fallback;

    final normalized = rawHashtags
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(3)
        .toList();

    return normalized.isEmpty ? fallback : normalized;
  }

  Map<String, dynamic> _fallbackPressReleaseFromText(
    String rawText,
    String channelKey,
  ) {
    final channelLabel = _channelLabel(channelKey);
    final normalized = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

    return <String, dynamic>{
      'title': '$channelLabel の下書き',
      'body': normalized.isEmpty ? '$channelLabel の下書きを生成しました。' : normalized,
      'hashtags': _defaultHashtags(channelKey),
    };
  }

  Map<String, dynamic> _normalizePressReleaseResult(
    dynamic rawResult,
    String channelKey,
  ) {
    if (rawResult is Map) {
      final resultMap = Map<String, dynamic>.from(rawResult);
      return <String, dynamic>{
        'title': (resultMap['title'] ?? '${_channelLabel(channelKey)}の下書き')
            .toString(),
        'body': (resultMap['body'] ?? '').toString(),
        'hashtags': _normalizeHashtags(resultMap['hashtags'], channelKey),
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
        // Fall through to text fallback.
      }
    }

    return _fallbackPressReleaseFromText(resultText, channelKey);
  }

  void _showRecoverableAiError(String details) {
    final lower = details.toLowerCase();
    final hint = lower.contains('404') || lower.contains('not found')
        ? 'AI関数の設定を確認してください。'
        : lower.contains('api key')
            ? 'APIキー設定を確認してください。'
            : '再実行するか、モデル設定を確認してください。';

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('生成に失敗しました。$hint')),
    );
  }

  Future<void> _generatePressRelease() async {
    final channelKey = _channelKey();

    setState(() => _isLoading = true);
    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: <String, dynamic>{
          'action': 'improve',
          'text': _buildDraftPrompt(channelKey),
        },
      );

      if (response.status != 200) {
        throw Exception('AI Error: ${response.status}');
      }

      final data = _normalizeInvokePayload(response.data);
      if (data['success'] != true) {
        _showRecoverableAiError((data['error'] ?? 'Unknown error').toString());
        return;
      }

      if (!mounted) return;
      setState(() {
        _pressRelease =
            _normalizePressReleaseResult(data['result'], channelKey);
      });
    } catch (error) {
      _showRecoverableAiError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _buildShareText() {
    if (_pressRelease == null) return '';

    final title = (_pressRelease!['title'] ?? '').toString().trim();
    final body = (_pressRelease!['body'] ?? '').toString().trim();
    final hashtags = _normalizeHashtags(
      _pressRelease!['hashtags'],
      _channelKey(),
    ).join(' ');

    return <String>[title, body, hashtags]
        .where((part) => part.isNotEmpty)
        .join('\n\n');
  }

  Future<void> _sharePressRelease() async {
    if (_pressRelease == null) return;

    final title = (_pressRelease!['title'] ?? '').toString();
    await SharePlus.instance.share(
      ShareParams(
        text: _buildShareText(),
        subject: title,
      ),
    );
  }

  Future<void> _shareToXDirectly() async {
    if (_pressRelease == null) return;

    final shareText = _buildShareText();
    if (shareText.isEmpty) {
      await _sharePressRelease();
      return;
    }

    final uri = Uri.https(
      'twitter.com',
      '/intent/tweet',
      <String, String>{'text': shareText},
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (launched) return;
    } catch (_) {
      // Fall through to the generic share sheet.
    }

    await _sharePressRelease();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('X を直接開けなかったため、共有シートを表示しました。'),
      ),
    );
  }

  Widget _buildResultCard(String channelKey) {
    final release = _pressRelease;
    if (release == null) return const SizedBox.shrink();

    final title = (release['title'] ?? '').toString();
    final body = (release['body'] ?? '').toString();
    final hashtags = _normalizeHashtags(release['hashtags'], channelKey);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_channelLabel(channelKey)} の生成結果',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionLabel('見出し'),
            const SizedBox(height: 6),
            SelectableText(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionLabel('本文'),
            const SizedBox(height: 6),
            SelectableText(
              body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionLabel('ハッシュタグ'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hashtags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: SelectableText(
                _buildShareText(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelKey = _channelKey();
    final channelLabel = _channelLabel(channelKey);
    final draftButtonLabel = '$channelLabel の草案を起案する';
    final primaryShareLabel = channelKey == 'x_share' ? 'Xへ直接投稿' : '外部へ共有';

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
                      onPressed: channelKey == 'x_share'
                          ? _shareToXDirectly
                          : _sharePressRelease,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.share),
                      label: Text(primaryShareLabel),
                    ),
                  ),
                ],
              ),
              if (channelKey == 'x_share') ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _sharePressRelease,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('共有シートを開く'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
