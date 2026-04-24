import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// オーディオエフェクトプロセッサーページ
/// audio-effects-processor Edge Function と連携してエフェクトカタログを取得
class AudioEffectsProcessorPage extends StatefulWidget {
  const AudioEffectsProcessorPage({super.key});

  @override
  State<AudioEffectsProcessorPage> createState() =>
      _AudioEffectsProcessorPageState();
}

class _AudioEffectsProcessorPageState extends State<AudioEffectsProcessorPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _effects = [];

  @override
  void initState() {
    super.initState();
    _fetchEffects();
  }

  Future<void> _fetchEffects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'audio.catalog'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['effects'] is List) {
        setState(
          () =>
              _effects = (data['effects'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _effects = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _effects = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'エフェクト一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('オーディオエフェクト'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEffects,
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
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchEffects,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _effects.isEmpty
                  ? const Center(child: Text('エフェクトがありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _effects.length,
                      itemBuilder: (context, index) {
                        final effect = _effects[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.graphic_eq),
                            title: Text(
                              effect['name']?.toString() ?? '-',
                            ),
                            subtitle: Text(
                              effect['description']?.toString() ?? '',
                            ),
                            trailing: Chip(
                              label: Text(
                                effect['category']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
