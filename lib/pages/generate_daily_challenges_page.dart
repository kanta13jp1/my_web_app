import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GenerateDailyChallengesPage extends StatefulWidget {
  const GenerateDailyChallengesPage({super.key});

  @override
  State<GenerateDailyChallengesPage> createState() =>
      _GenerateDailyChallengesPageState();
}

class _GenerateDailyChallengesPageState
    extends State<GenerateDailyChallengesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
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
      _quoteText = null;
    });

    try {
      final response =
          await _supabase.functions.invoke('generate-daily-challenges');
      final raw = response.data;
      String svgStr;
      if (raw is List<int>) {
        svgStr = utf8.decode(raw);
      } else if (raw is String) {
        svgStr = raw;
      } else {
        throw Exception('予期しない応答形式です');
      }
      setState(() {
        _quoteText = _extractQuoteText(svgStr);
      });
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
        title: const Text('デイリーチャレンジ'),
        backgroundColor: Colors.orange,
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
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 16),
                    Text('今日のチャレンジを生成中...'),
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
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events,
                              size: 64, color: Colors.orange),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '今日のチャレンジ',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                        const SizedBox(height: 16),
                        if (_quoteText != null)
                          Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _quoteText!,
                                style: const TextStyle(
                                    fontSize: 18, height: 1.6),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          const Text('チャレンジを取得できませんでした'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _generate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('新しいチャレンジ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
