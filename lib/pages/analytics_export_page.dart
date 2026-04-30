import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 分析データエクスポートページ
/// analytics-export Edge Function と連携してレポート生成・エクスポートを提供
class AnalyticsExportPage extends StatefulWidget {
  const AnalyticsExportPage({super.key});

  @override
  State<AnalyticsExportPage> createState() => _AnalyticsExportPageState();
}

class _AnalyticsExportPageState extends State<AnalyticsExportPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _reportTypes = [];
  List<String> _exportFormats = [];
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final optRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'analytics.export_options'},
      );
      final histRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'analytics.export_history'},
      );
      final optData = optRes.data;
      final histData = histRes.data;
      setState(() {
        if (optData is Map<String, dynamic>) {
          final types = optData['reportTypes'];
          _reportTypes =
              types is List ? types.map((e) => e.toString()).toList() : [];
          final formats = optData['exportFormats'];
          _exportFormats =
              formats is List ? formats.map((e) => e.toString()).toList() : [];
        }
        final exports =
            histData is Map<String, dynamic> ? histData['exports'] : null;
        _history = exports is List ? exports : [];
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析データエクスポート'),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_reportTypes.isNotEmpty) ...[
                      const Text(
                        'レポートタイプ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _reportTypes
                            .map(
                              (t) => Chip(
                                label: Text(t),
                                backgroundColor: isDark
                                    ? const Color(0xFF0D2E2A)
                                    : const Color(0xFFE0F2F1),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_exportFormats.isNotEmpty) ...[
                      const Text(
                        'エクスポート形式',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _exportFormats
                            .map(
                              (f) => Chip(
                                label: Text(f.toUpperCase()),
                                backgroundColor: isDark
                                    ? const Color(0xFF0B2422)
                                    : const Color(0xFFB2DFDB),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'エクスポート履歴',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_history.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'エクスポート履歴はありません',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_history.length, (i) {
                        final item = _history[i] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1A009688),
                              child: Icon(
                                Icons.download,
                                color: Color(0xFF009688),
                              ),
                            ),
                            title: Text(
                              item['type']?.toString() ??
                                  item['report_type']?.toString() ??
                                  'レポート',
                            ),
                            subtitle: Text(
                              item['format']?.toString().toUpperCase() ?? '',
                            ),
                            trailing: Text(
                              item['createdAt']?.toString().substring(0, 10) ??
                                  '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                                height: 1.5,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
