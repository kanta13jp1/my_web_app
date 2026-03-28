import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiSuggestTagsPage extends StatefulWidget {
  const AiSuggestTagsPage({super.key});

  @override
  State<AiSuggestTagsPage> createState() => _AiSuggestTagsPageState();
}

class _AiSuggestTagsPageState extends State<AiSuggestTagsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _svgContent;
  String? _quoteText;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _svgContent = null;
      _quoteText = null;
    });

    try {
      final response = await _supabase.functions.invoke('ai-suggest-tags');
      final raw = response.data;
      if (raw is List<int>) {
        final svgStr = utf8.decode(raw);
        setState(() {
          _svgContent = svgStr;
          _quoteText = _extractQuoteText(svgStr);
        });
      } else if (raw is String) {
        setState(() {
          _svgContent = raw;
          _quoteText = _extractQuoteText(raw);
        });
      } else {
        throw Exception('予期しない応答形式です');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _extractQuoteText(String svg) {
    final matches = RegExp(r'<text[^>]*>([^<]+)</text>').allMatches(svg);
    if (matches.isEmpty) return null;
    return matches.map((m) => m.group(1) ?? '').join('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI タグ提案 / 名言生成'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _generate,
            tooltip: '再生成',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('生成中...'),
                  ],
                )
              : _errorMessage != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generate,
                          child: const Text('再試行'),
                        ),
                      ],
                    )
                  : _quoteText != null
                      ? Card(
                          elevation: 8,
                          color: Colors.teal.shade700,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.format_quote,
                                    color: Colors.white70, size: 40),
                                const SizedBox(height: 16),
                                Text(
                                  _quoteText!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _generate,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('次の名言'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Text('名言を取得できませんでした'),
        ),
      ),
    );
  }
}
