import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:highlight/highlight.dart' as highlight;
import '../services/attachment_service.dart';
import '../services/markdown_block_service.dart';
import '../services/note_wiki_link_service.dart';

class MarkdownPreview extends StatefulWidget {
  final String data;
  final bool selectable;
  final ValueChanged<String>? onWikiLinkTap;

  const MarkdownPreview({
    super.key,
    required this.data,
    this.selectable = true,
    this.onWikiLinkTap,
  });

  @override
  State<MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<MarkdownPreview> {
  late String _resolvedData;
  bool _isResolvingAttachments = false;

  @override
  void initState() {
    super.initState();
    _resolvedData = widget.data;
    _resolveAttachmentUrls();
  }

  @override
  void didUpdateWidget(covariant MarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _resolvedData = widget.data;
      _resolveAttachmentUrls();
    }
  }

  Future<void> _resolveAttachmentUrls() async {
    if (!AttachmentService.containsAttachmentReference(widget.data)) {
      if (mounted) {
        setState(() {
          _resolvedData = widget.data;
          _isResolvingAttachments = false;
        });
      }
      return;
    }

    setState(() {
      _isResolvingAttachments = true;
    });

    try {
      final resolved =
          await AttachmentService.resolveMarkdownAttachmentUrls(widget.data);
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedData = resolved;
        _isResolvingAttachments = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedData = widget.data;
        _isResolvingAttachments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolvingAttachments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<PreviewSegment> segments =
        MarkdownBlockService.splitPreviewSegments(_resolvedData);
    if (segments.isEmpty) {
      return _buildMarkdownWidget(context, '');
    }
    if (segments.length == 1 &&
        segments.first.kind == PreviewSegmentKind.markdown) {
      return _buildMarkdownWidget(context, segments.first.body);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: segments.map((PreviewSegment segment) {
        switch (segment.kind) {
          case PreviewSegmentKind.toggle:
            return _buildToggleBlock(context, segment);
          case PreviewSegmentKind.callout:
            return _buildCalloutBlock(context, segment);
          case PreviewSegmentKind.markdown:
            return _buildMarkdownWidget(context, segment.body);
        }
      }).toList(growable: false),
    );
  }

  Widget _buildToggleBlock(BuildContext context, PreviewSegment segment) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text(
          segment.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          if (segment.body.isNotEmpty)
            _buildMarkdownWidget(context, segment.body),
        ],
      ),
    );
  }

  Widget _buildCalloutBlock(BuildContext context, PreviewSegment segment) {
    final Color accent;
    final IconData icon;
    switch (segment.title) {
      case 'WARNING':
      case 'CAUTION':
        accent = const Color(0xFFD97706);
        icon = Icons.warning_amber_rounded;
        break;
      case 'IMPORTANT':
        accent = const Color(0xFF7C3AED);
        icon = Icons.priority_high_rounded;
        break;
      case 'TIP':
        accent = const Color(0xFF059669);
        icon = Icons.lightbulb_outline_rounded;
        break;
      default:
        accent = const Color(0xFF2563EB);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: Border(
          left: BorderSide(color: accent, width: 4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                segment.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          if (segment.body.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _buildMarkdownWidget(context, segment.body),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkdownWidget(BuildContext context, String rawMarkdown) {
    final String processed =
        NoteWikiLinkService.replaceWikiLinksWithMarkdownLinks(rawMarkdown);
    return Markdown(
      data: processed,
      selectable: widget.selectable,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      styleSheet: MarkdownStyleSheet(
        // 見出しスタイル
        h1: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
        h2: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h3: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h4: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        h5: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        h6: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        // 段落スタイル
        p: const TextStyle(
          fontSize: 16,
          height: 1.6,
        ),
        // リストスタイル
        listBullet: const TextStyle(
          fontSize: 16,
          height: 1.6,
        ),
        // コードブロックスタイル
        code: TextStyle(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          fontFamily: 'monospace',
          fontSize: 14,
          color: Colors.red[700],
          height: 1.5,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        // 引用スタイル
        blockquote: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          border: const Border(
            left: BorderSide(
              color: Color(0xFF64B5F6),
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        blockquotePadding: const EdgeInsets.all(12),
        // 水平線
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              width: 2,
            ),
          ),
        ),
        // テーブルスタイル
        tableBorder: TableBorder.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: 1,
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          height: 1.5,
        ),
        tableBody: const TextStyle(
          fontSize: 14,
          height: 1.5,
        ),
        tableColumnWidth: const FlexColumnWidth(),
        // リンクスタイル
        a: const TextStyle(
          color: Color(0xFF3D5AFE),
          decoration: TextDecoration.underline,
          height: 1.5,
        ),
        // チェックボックス
        checkbox: const TextStyle(fontSize: 16, height: 1.5),
      ),
      onTapLink: (text, href, title) {
        if (href == null) return;
        if (href.startsWith(NoteWikiLinkService.wikiLinkScheme)) {
          final String target = Uri.decodeComponent(
            href.substring(NoteWikiLinkService.wikiLinkScheme.length),
          );
          widget.onWikiLinkTap?.call(target);
          return;
        }
        launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
      },
      builders: {
        'code': CodeElementBuilder(),
      },
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
    );
  }
}

// コードブロック用カスタムビルダー
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String code = element.textContent;
    final String? language =
        element.attributes['class']?.replaceFirst('language-', '');

    if (language != null && language.isNotEmpty) {
      // シンタックスハイライトを適用
      try {
        final result = highlight.highlight.parse(code, language: language);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 言語ラベル + コピーボタン
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF3C3C3C),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForLanguage(language),
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      language,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    _CopyCodeButton(code: code),
                  ],
                ),
              ),
              // コード
              Container(
                padding: const EdgeInsets.all(16),
                child: SelectableText.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: _buildHighlightedCode(result.nodes),
                  ),
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        // シンタックスハイライトに失敗した場合は通常表示
        return _buildPlainCodeBlock(code, language);
      }
    }

    // 言語指定がない場合は通常のコードブロック
    return _buildPlainCodeBlock(code, null);
  }

  Widget _buildPlainCodeBlock(String code, String? language) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF3C3C3C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                if (language != null)
                  Text(
                    language,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                const Spacer(),
                _CopyCodeButton(code: code),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return Icons.code;
      case 'javascript':
      case 'js':
        return Icons.javascript;
      case 'python':
      case 'py':
        return Icons.code;
      case 'java':
        return Icons.coffee;
      case 'sql':
        return Icons.storage;
      case 'json':
        return Icons.data_object;
      case 'html':
      case 'xml':
        return Icons.html;
      default:
        return Icons.code;
    }
  }

  List<TextSpan> _buildHighlightedCode(List<highlight.Node>? nodes) {
    if (nodes == null) return [];

    final List<TextSpan> spans = [];

    for (final node in nodes) {
      if (node.value != null) {
        spans.add(
          TextSpan(
            text: node.value,
            style: TextStyle(
              color: _getColorForClassName(node.className),
              height: 1.5,
            ),
          ),
        );
      }
      if (node.children != null) {
        spans.addAll(_buildHighlightedCode(node.children));
      }
    }

    return spans;
  }

  // _CopyCodeButton is defined below as a standalone widget

  Color _getColorForClassName(String? className) {
    switch (className) {
      case 'keyword':
        return const Color(0xFFCC7832); // オレンジ
      case 'built_in':
        return const Color(0xFF9876AA); // 紫
      case 'string':
        return const Color(0xFF6A8759); // 緑
      case 'number':
        return const Color(0xFF6897BB); // 青
      case 'comment':
        return const Color(0xFF808080); // グレー
      case 'function':
        return const Color(0xFFFFC66D); // 黄色
      case 'class':
      case 'title':
        return const Color(0xFFFFB86C); // オレンジ黄色
      case 'variable':
      case 'params':
        return const Color(0xFFA9B7C6); // 明るいグレー
      case 'meta':
        return const Color(0xFFBBB529); // 黄土色
      case 'tag':
        return const Color(0xFFE8BF6A); // 黄土色
      case 'attr':
      case 'attribute':
        return const Color(0xFFBBB529); // 黄土色
      case 'literal':
      case 'constant':
        return const Color(0xFF9876AA); // 紫
      default:
        return Colors.white; // デフォルトは白
    }
  }
}

/// コードブロックのコピーボタン
class _CopyCodeButton extends StatefulWidget {
  final String code;

  const _CopyCodeButton({required this.code});

  @override
  State<_CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<_CopyCodeButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check : Icons.copy,
              size: 14,
              color: _copied ? const Color(0xFF10B981) : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              _copied ? 'Copied!' : 'Copy',
              style: TextStyle(
                fontSize: 11,
                color: _copied ? const Color(0xFF10B981) : Colors.white54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
