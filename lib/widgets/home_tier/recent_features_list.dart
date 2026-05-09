import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecentFeaturesList extends StatefulWidget {
  const RecentFeaturesList({super.key});

  @override
  State<RecentFeaturesList> createState() => _RecentFeaturesListState();
}

class _RecentFeaturesListState extends State<RecentFeaturesList> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

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
      final rows = await Supabase.instance.client
          .from('user_feature_usage')
          .select('feature_route, feature_label, tapped_at')
          .eq('user_id', user.id)
          .order('tapped_at', ascending: false)
          .limit(8);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final row in rows) {
        final route = row['feature_route'] as String? ?? '';
        if (route.isNotEmpty && seen.add(route)) deduped.add(row);
      }
      if (mounted) {
        setState(() {
          _items = deduped;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'まだ利用履歴がありません。',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _items.map((item) {
          final route = _normalizeRoute(item['feature_route'] as String? ?? '');
          final label = item['feature_label'] as String? ??
              route.substring(1).replaceAll('-', ' ');
          return ActionChip(
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFE5E7EB),
                height: 1.5,
              ),
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            side: const BorderSide(color: Color(0xFF2A2A2A)),
            onPressed: route.isEmpty
                ? null
                : () => Navigator.pushNamed(context, route),
          );
        }).toList(),
      ),
    );
  }

  static String _normalizeRoute(String value) {
    final route = value.trim();
    if (route.isEmpty) return '';
    return route.startsWith('/') ? route : '/$route';
  }
}
