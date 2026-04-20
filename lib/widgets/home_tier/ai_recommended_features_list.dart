import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiRecommendedFeaturesList extends StatefulWidget {
  const AiRecommendedFeaturesList({super.key});

  @override
  State<AiRecommendedFeaturesList> createState() =>
      _AiRecommendedFeaturesListState();
}

class _AiRecommendedFeaturesListState extends State<AiRecommendedFeaturesList> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'home.recommend', 'user_id': user.id},
      );
      final data = resp.data as Map<String, dynamic>?;
      final items = data?['recommendations'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _items = items.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'AIがあなたにおすすめの機能を分析中...',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null || _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'おすすめ機能を取得できませんでした。後でお試しください。',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }
    return Column(
      children: _items.map((item) {
        final label =
            item['label'] as String? ?? item['feature_route'] as String? ?? '';
        final reason = item['reason'] as String? ?? '';
        final route = item['feature_route'] as String? ?? '';
        return ListTile(
          dense: true,
          leading: const Icon(
            Icons.auto_awesome,
            size: 18,
            color: Color(0xFF6366F1),
          ),
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          subtitle: reason.isNotEmpty
              ? Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                )
              : null,
          trailing: const Icon(
            Icons.chevron_right,
            size: 16,
            color: Color(0xFF64748B),
          ),
          onTap: route.isNotEmpty
              ? () => Navigator.pushNamed(context, route)
              : null,
        );
      }).toList(),
    );
  }
}
