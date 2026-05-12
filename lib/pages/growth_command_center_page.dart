import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// グロース司令部ページ
/// KPI 指標を入力し AI が戦略ブリーフを生成する
class GrowthCommandCenterPage extends StatefulWidget {
  const GrowthCommandCenterPage({super.key});

  @override
  State<GrowthCommandCenterPage> createState() =>
      _GrowthCommandCenterPageState();
}

class _GrowthCommandCenterPageState extends State<GrowthCommandCenterPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  Future<void> _load() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response = await _supabase.functions
          .invoke('growth-hub', body: {'action': 'command.analyze'});

      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _result = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'コマンドセンター取得に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBriefCard(Map<String, dynamic> brief) {
    final priorityColor = switch (brief['priority']?.toString()) {
      'critical' => const Color(0xFFE53935),
      'high' => const Color(0xFFFF6B35),
      'medium' => const Color(0xFFFFC107),
      _ => const Color(0xFF707070),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    brief['label']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
                Text(
                  brief['owner']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF707070),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              brief['objective']?.toString() ?? '',
              style: const TextStyle(
                color: Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
            if (brief['nextAction'] != null) ...[
              const SizedBox(height: 4),
              Text(
                '→ ${brief['nextAction']}',
                style: const TextStyle(
                  color: Color(0xFF7986CB),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final briefs = _result != null && _result!['departments'] is List
        ? List<Map<String, dynamic>>.from(
            (_result!['departments'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('グロース司令部'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _result == null && !_isLoading
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('コマンドセンターを起動'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_result!['summary'] != null) ...[
                            Text(
                              _result!['summary'].toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (briefs.isNotEmpty) ...[
                            const Text(
                              '部門ブリーフィング',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B35),
                                letterSpacing: 1.2,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...briefs.map(_buildBriefCard),
                          ] else
                            const Text(
                              'データがありません',
                              style: TextStyle(
                                color: Color(0xFF707070),
                                height: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
