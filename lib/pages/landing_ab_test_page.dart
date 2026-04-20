import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LP A/Bテストページ
/// growth-hub:landing.list_variants と連携してCTA/コピー最適化を管理
class LandingAbTestPage extends StatefulWidget {
  const LandingAbTestPage({super.key});

  @override
  State<LandingAbTestPage> createState() => _LandingAbTestPageState();
}

class _LandingAbTestPageState extends State<LandingAbTestPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _variants = [];

  @override
  void initState() {
    super.initState();
    _fetchVariants();
  }

  Future<void> _fetchVariants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'growth-hub',
        body: {'action': 'landing.list_variants'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['variants'] is List) {
        setState(
          () => _variants =
              (data['variants'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _variants = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _variants = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'バリアントの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LP A/Bテスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVariants,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchVariants,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _variants.isEmpty
                  ? const Center(child: Text('A/Bテストバリアントはありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _variants.length,
                      itemBuilder: (context, index) {
                        final variant = _variants[index];
                        final id = variant['id']?.toString() ?? 'v${index + 1}';
                        final text = variant['text']?.toString() ?? 'バリアント $id';
                        final conv =
                            variant['conversion_rate']?.toString() ?? '-';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFBBDEFB),
                              child: Text(
                                id.toUpperCase().substring(0, 1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            title: Text(
                              text,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            trailing: Text(
                              'CVR: $conv%',
                              style: const TextStyle(
                                color: Color(0xFF3D5AFE),
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
