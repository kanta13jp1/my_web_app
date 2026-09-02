import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/design_tokens.dart';

typedef MusubiUrlOpener = Future<bool> Function(Uri uri);

/// Renders post text and turns plain web URLs into safe, tappable links.
class MusubiPostContent extends StatefulWidget {
  const MusubiPostContent({
    super.key,
    required this.text,
    this.urlOpener,
  });

  final String text;
  final MusubiUrlOpener? urlOpener;

  @override
  State<MusubiPostContent> createState() => _MusubiPostContentState();
}

class _MusubiPostContentState extends State<MusubiPostContent> {
  static final RegExp _webUrlPattern = RegExp(
    r'https?://[^\s<>]+',
    caseSensitive: false,
  );
  static const String _trailingPunctuation = '.,!?;:)]}、。！？；：）］｝」』】';
  static const TextStyle _bodyStyle = TextStyle(
    color: DesignTokens.textOnDark,
    fontSize: 14,
    height: 1.75,
  );
  static final TextStyle _linkStyle = _bodyStyle.copyWith(
    color: DesignTokens.orangeLight,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
    decorationColor: DesignTokens.orangeLight,
  );

  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _buildSpans();
  }

  @override
  void didUpdateWidget(MusubiPostContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _spans = _buildSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  static Future<bool> _launchExternalUrl(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openLink(String? href) async {
    if (href == null) return;

    final uri = Uri.tryParse(href);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null ||
        (scheme != 'http' && scheme != 'https') ||
        uri.host.isEmpty) {
      return;
    }

    await (widget.urlOpener ?? _launchExternalUrl)(uri);
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _webUrlPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }

      final matchedText = match.group(0)!;
      final url = _withoutTrailingPunctuation(matchedText);
      final punctuation = matchedText.substring(url.length);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => unawaited(_openLink(url));
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: url,
          style: _linkStyle,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        ),
      );
      if (punctuation.isNotEmpty) {
        spans.add(TextSpan(text: punctuation));
      }
      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return spans;
  }

  String _withoutTrailingPunctuation(String value) {
    var end = value.length;
    while (end > 0 && _trailingPunctuation.contains(value[end - 1])) {
      end--;
    }
    return value.substring(0, end);
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans),
      style: _bodyStyle,
    );
  }
}
