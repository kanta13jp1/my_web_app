import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    super.key,
    required this.assetPath,
    required this.title,
    required this.subtitle,
    this.showBackButton = true,
  });

  final String assetPath;
  final String title;
  final String subtitle;
  final bool showBackButton;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late final Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = rootBundle.loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0A0A0A);
    const surface = Color(0xFF111827);
    const orange = Color(0xFFFF6B35);
    const indigo = Color(0xFF3D5AFE);
    const text = Color(0xFFE5E7EB);
    const muted = Color(0xFF9CA3AF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: FutureBuilder<String>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: orange),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${widget.title} could not be loaded.',
                  style: const TextStyle(color: text),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                decoration: const BoxDecoration(
                  color: bg,
                  border: Border(bottom: BorderSide(color: Color(0xFF1F2937))),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: orange,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Markdown(
                      data: snapshot.data!,
                      selectable: true,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                      onTapLink: (_, href, __) {
                        if (href == null) return;
                        unawaited(_openLink(href));
                      },
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: const TextStyle(
                              color: text,
                              fontSize: 15,
                              height: 1.75,
                            ),
                            h1: const TextStyle(
                              color: orange,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                            h2: const TextStyle(
                              color: Color(0xFFFFB199),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                            h3: const TextStyle(
                              color: Color(0xFFB8C3FF),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                            strong: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            a: const TextStyle(
                              color: Color(0xFF8EA2FF),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF8EA2FF),
                            ),
                            listBullet: const TextStyle(color: orange),
                            blockquote: const TextStyle(
                              color: muted,
                              fontStyle: FontStyle.italic,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: surface,
                              border: const Border(
                                left: BorderSide(color: indigo, width: 4),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            code: const TextStyle(
                              color: Color(0xFFFFD6C7),
                              backgroundColor: Color(0xFF1F2937),
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF243044),
                              ),
                            ),
                            tableHead: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            tableBody: const TextStyle(
                              color: text,
                              fontSize: 13,
                              height: 1.45,
                            ),
                            tableBorder: TableBorder.all(
                              color: const Color(0xFF374151),
                            ),
                            tableCellsPadding: const EdgeInsets.all(10),
                            horizontalRuleDecoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFF374151)),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
