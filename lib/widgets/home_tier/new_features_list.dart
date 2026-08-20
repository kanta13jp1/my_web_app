import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/home_feature_actions.dart';
import 'home_tier_styles.dart';

class NewFeaturesList extends StatefulWidget {
  const NewFeaturesList({super.key});

  @override
  State<NewFeaturesList> createState() => _NewFeaturesListState();
}

class _NewFeaturesListState extends State<NewFeaturesList> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _showingLatestFallback = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var rows = await Supabase.instance.client
          .from('feature_releases')
          .select('feature_route, feature_label, description, released_at')
          .gte(
            'released_at',
            DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
          )
          .order('released_at', ascending: false)
          .limit(6);
      var fallback = false;
      if (rows.isEmpty) {
        // 直近14日が空でもセクションが死なないよう、最新リリースを表示する
        rows = await Supabase.instance.client
            .from('feature_releases')
            .select('feature_route, feature_label, description, released_at')
            .order('released_at', ascending: false)
            .limit(3);
        fallback = rows.isNotEmpty;
      }
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows);
          _showingLatestFallback = fallback;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeTierPalette.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '直近14日間に追加された機能はありません。',
          style: TextStyle(
            color: palette.secondaryText,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_showingLatestFallback)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '直近14日間の追加はありません。最新の追加機能を表示しています。',
                style: TextStyle(
                  color: palette.secondaryText,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ..._items.map((item) {
          final label = item['feature_label'] as String? ?? '新機能';
          final desc = item['description'] as String? ?? '';
          final route = _normalizeRoute(item['feature_route'] as String? ?? '');
          return HomeTierFeatureListTile(
            icon: Icons.new_releases_outlined,
            iconColor: const Color(0xFFFF6B35),
            label: label,
            description: desc,
            onTap: route.isEmpty
                ? null
                : () => openHomeFeature(context, route, label),
            onLongPress: route.isEmpty
                ? null
                : () => pinHomeFeature(context, route, label),
          );
        }),
      ],
    );
  }

  static String _normalizeRoute(String value) {
    final route = value.trim();
    if (route.isEmpty) return '';
    return route.startsWith('/') ? route : '/$route';
  }
}
