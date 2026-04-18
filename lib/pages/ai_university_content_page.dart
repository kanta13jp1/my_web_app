import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiUniversityContentPage extends StatefulWidget {
  const AiUniversityContentPage({super.key});

  @override
  State<AiUniversityContentPage> createState() =>
      _AiUniversityContentPageState();
}

class _AiUniversityContentPageState extends State<AiUniversityContentPage> {
  bool _loading = false;
  List<dynamic> _items = [];
  String? _error;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-university-content',
        method: HttpMethod.get,
      );
      final data = res.data;
      setState(() {
        if (data is List) {
          _items = data;
        } else if (data is Map && data['items'] is List) {
          _items = data['items'] as List;
        } else {
          _items = [];
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
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
        title: const Text('AI大学 コンテンツ管理'),
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
                        style: const TextStyle(color: Colors.red),
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
                  ? const Center(child: Text('コンテンツなし'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final item = _items[i] as Map<String, dynamic>? ?? {};
                        return ListTile(
                          leading: const Icon(
                            Icons.school,
                            color: Color(0xFF6366F1),
                          ),
                          title: Text(
                            '${item['provider'] ?? ''} — ${item['category'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            item['title']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            item['published_at']?.toString().substring(0, 10) ??
                                '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
