import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 動画広告生成ページ
/// video-ad-generator Edge Function と連携して動画広告スクリプトを管理
class VideoAdGeneratorPage extends StatefulWidget {
  const VideoAdGeneratorPage({super.key});

  @override
  State<VideoAdGeneratorPage> createState() => _VideoAdGeneratorPageState();
}

class _VideoAdGeneratorPageState extends State<VideoAdGeneratorPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'video-ad-generator',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['ads'] is List) {
        setState(
          () => _ads = (data['ads'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _ads = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _ads = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '広告一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('動画広告ジェネレーター'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAds),
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
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAds,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _ads.isEmpty
                  ? const Center(child: Text('動画広告はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ads.length,
                      itemBuilder: (context, index) {
                        final ad = _ads[index];
                        final title =
                            ad['title']?.toString() ?? '広告 ${index + 1}';
                        final platform = ad['platform']?.toString() ?? '-';
                        final status = ad['status']?.toString() ?? 'draft';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.video_collection,
                              color: Color(0xFFFF6B35),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(platform),
                            trailing: Chip(
                              label: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              backgroundColor: status == 'ready'
                                  ? Colors.green.shade100
                                  : const Color(0xFFFFE0B2),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('新しい動画広告を生成します')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('生成'),
      ),
    );
  }
}
