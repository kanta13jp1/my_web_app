import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPinnedFeaturesList extends StatefulWidget {
  const UserPinnedFeaturesList({super.key});

  @override
  State<UserPinnedFeaturesList> createState() => _UserPinnedFeaturesListState();
}

class _UserPinnedFeaturesListState extends State<UserPinnedFeaturesList> {
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
          .from('user_pinned_features')
          .select('feature_route, feature_label, sort_order')
          .eq('user_id', user.id)
          .order('sort_order', ascending: true);
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

  Future<void> _unpin(String route) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('user_pinned_features')
        .delete()
        .eq('user_id', user.id)
        .eq('feature_route', route);
    _load();
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
          '機能カードのピンを押すとここに表示されます。',
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
          final label =
              item['feature_label'] as String? ?? _fallbackLabel(route);
          return InputChip(
            label: Text(
              label,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            backgroundColor: const Color(0xFF1E1E2E),
            side: const BorderSide(color: Color(0xFF6366F1), width: 0.8),
            deleteIcon: const Icon(
              Icons.push_pin,
              size: 14,
              color: Color(0xFF6366F1),
            ),
            onDeleted: route.isEmpty ? null : () => _unpin(route),
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

  static String _fallbackLabel(String route) {
    if (route.isEmpty) return 'ピン止め機能';
    return route.substring(1).replaceAll('-', ' ');
  }
}
