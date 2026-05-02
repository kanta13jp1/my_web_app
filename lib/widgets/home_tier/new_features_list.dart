import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewFeaturesList extends StatefulWidget {
  const NewFeaturesList({super.key});

  @override
  State<NewFeaturesList> createState() => _NewFeaturesListState();
}

class _NewFeaturesListState extends State<NewFeaturesList> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('feature_releases')
          .select('feature_route, feature_label, description, released_at')
          .gte(
            'released_at',
            DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
          )
          .order('released_at', ascending: false)
          .limit(6);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows);
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
          '直近14日間に追加された機能はありません。',
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
        final label = item['feature_label'] as String? ?? '新機能';
        final desc = item['description'] as String? ?? '';
        final route = _normalizeRoute(item['feature_route'] as String? ?? '');
        return ListTile(
          dense: true,
          leading: const Icon(
            Icons.new_releases_outlined,
            size: 18,
            color: Color(0xFFFF6B35),
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
          subtitle: desc.isNotEmpty
              ? Text(
                  desc,
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
          onTap:
              route.isEmpty ? null : () => Navigator.pushNamed(context, route),
        );
      }).toList(),
    );
  }

  static String _normalizeRoute(String value) {
    final route = value.trim();
    if (route.isEmpty) return '';
    return route.startsWith('/') ? route : '/$route';
  }
}
