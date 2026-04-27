import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 成長獲得レポートページ
/// タッチポイント別の獲得・登録状況を表示
class GrowthAcquisitionReportPage extends StatefulWidget {
  const GrowthAcquisitionReportPage({super.key});

  @override
  State<GrowthAcquisitionReportPage> createState() =>
      _GrowthAcquisitionReportPageState();
}

class _GrowthAcquisitionReportPageState
    extends State<GrowthAcquisitionReportPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions
          .invoke('growth-hub', body: {'action': 'acquisition.report'});

      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _data = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'レポート取得に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTouchpointRow(Map<String, dynamic> tp) {
    final touches = (tp['touches'] as num? ?? 0).toDouble();
    final signups = (tp['signupSubmits'] as num? ?? 0).toDouble();
    final rate =
        touches > 0 ? ((signups / touches) * 100).toStringAsFixed(1) : '0.0';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                tp['label']?.toString() ?? tp['id']?.toString() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$touches',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF3D5AFE),
                      height: 1.5,
                    ),
                  ),
                  const Text(
                    'タッチ',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$signups',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF4CAF50),
                      height: 1.5,
                    ),
                  ),
                  const Text(
                    '登録',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$rate%',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFFFF6B35),
                      height: 1.5,
                    ),
                  ),
                  const Text(
                    'CVR',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final touchpoints = d != null && d['touchpoints'] is List
        ? List<Map<String, dynamic>>.from(
            (d['touchpoints'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('獲得レポート'),
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
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
                      const Text(
                        'タッチポイント別 獲得・CVR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (touchpoints.isEmpty)
                        const Text(
                          'データがありません',
                          style: TextStyle(
                            color: Color(0xFFB0B0B0),
                            height: 1.5,
                          ),
                        )
                      else
                        ...touchpoints.map(_buildTouchpointRow),
                    ],
                  ),
                ),
    );
  }
}
