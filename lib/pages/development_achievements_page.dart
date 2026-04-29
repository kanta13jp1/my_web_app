import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DevelopmentAchievementsPage extends StatefulWidget {
  const DevelopmentAchievementsPage({super.key});

  @override
  State<DevelopmentAchievementsPage> createState() =>
      _DevelopmentAchievementsPageState();
}

class _DevelopmentAchievementsPageState
    extends State<DevelopmentAchievementsPage> {
  bool _loading = false;
  List<dynamic> _items = [];
  String? _error;

  Future<void> _fetch() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'core-hub',
        body: {'action': 'achievements.list'},
      );
      final data = res.data;
      if (!mounted) return;
      setState(() {
        if (data is Map && data['achievements'] is List) {
          _items = data['achievements'] as List;
        } else if (data is List) {
          _items = data;
        } else {
          _items = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('開発実績'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'エラー: $_error',
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('実績なし'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final item = _items[i] as Map<String, dynamic>? ?? {};
                        return ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF4CAF50),
                          ),
                          title: Text(
                            item['title']?.toString() ?? '(タイトルなし)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                          subtitle: Text(
                            item['description']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            item['completed_at']?.toString().substring(0, 10) ??
                                '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB0B0B0),
                              height: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
