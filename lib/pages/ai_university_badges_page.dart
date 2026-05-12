import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiUniversityBadgesPage extends StatefulWidget {
  const AiUniversityBadgesPage({super.key});

  @override
  State<AiUniversityBadgesPage> createState() => _AiUniversityBadgesPageState();
}

class _AiUniversityBadgesPageState extends State<AiUniversityBadgesPage> {
  bool _loading = false;
  List<dynamic> _badges = [];
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
        'ai-hub',
        body: {'action': 'university.badges'},
      );
      final data = res.data;
      if (!mounted) return;
      setState(() {
        if (data is Map && data['badges'] is List) {
          _badges = data['badges'] as List;
        } else if (data is List) {
          _badges = data;
        } else {
          _badges = [];
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
        title: const Text('AI大学 バッジ'),
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
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _badges.isEmpty
                  ? const Center(child: Text('バッジはまだありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _badges.length,
                      itemBuilder: (context, i) {
                        final badge = _badges[i] as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: Text(
                              badge['icon_emoji'] as String? ?? '🏅',
                              style: const TextStyle(
                                fontSize: 28,
                                height: 1.5,
                              ),
                            ),
                            title: Text(
                              badge['badge_name'] as String? ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              badge['condition'] as String? ?? '',
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
