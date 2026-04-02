import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// フィーチャーフラグ管理ページ
/// feature-flags Edge Function と連携して機能フラグを管理
class FeatureFlagsPage extends StatefulWidget {
  const FeatureFlagsPage({super.key});

  @override
  State<FeatureFlagsPage> createState() => _FeatureFlagsPageState();
}

class _FeatureFlagsPageState extends State<FeatureFlagsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _flags = [];

  @override
  void initState() {
    super.initState();
    _fetchFlags();
  }

  Future<void> _fetchFlags() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'feature-flags',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['flags'] is List) {
        setState(() => _flags = data['flags'] as List);
      } else if (data is List) {
        setState(() => _flags = data);
      } else {
        setState(() => _flags = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'フィーチャーフラグの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フィーチャーフラグ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFlags,
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
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red,),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchFlags,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _flags.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.toggle_off_outlined,
                              size: 64, color: Colors.grey,),
                          SizedBox(height: 16),
                          Text('フィーチャーフラグがありません',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey,),),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _flags.length,
                      itemBuilder: (context, index) {
                        final item = _flags[index] as Map<String, dynamic>;
                        final name = item['name']?.toString() ??
                            item['key']?.toString() ??
                            'フラグ ${index + 1}';
                        final enabled = item['enabled'] == true ||
                            item['value'] == true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              enabled
                                  ? Icons.toggle_on
                                  : Icons.toggle_off,
                              color: enabled
                                  ? const Color(0xFF6366F1)
                                  : Colors.grey,
                              size: 32,
                            ),
                            title: Text(name),
                            subtitle: Text(enabled ? '有効' : '無効'),
                          ),
                        );
                      },
                    ),
    );
  }
}
