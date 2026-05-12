import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AR ナビゲーションページ
/// ar-navigation Edge Function と連携して AR ナビゲーション情報を表示
class ArNavigationPage extends StatefulWidget {
  const ArNavigationPage({super.key});

  @override
  State<ArNavigationPage> createState() => _ArNavigationPageState();
}

class _ArNavigationPageState extends State<ArNavigationPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'navigate.list_routes'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['routes'] is List) {
        setState(
          () => _locations =
              (data['routes'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is Map<String, dynamic> && data['locations'] is List) {
        setState(
          () => _locations =
              (data['locations'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _locations = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _locations = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'データの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR ナビゲーション'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLocations,
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLocations,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _locations.isEmpty
                  ? const Center(child: Text('ナビゲーションデータがありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final loc = _locations[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.navigation),
                            title: Text(loc['name']?.toString() ?? ''),
                            subtitle:
                                Text(loc['description']?.toString() ?? ''),
                          ),
                        );
                      },
                    ),
    );
  }
}
