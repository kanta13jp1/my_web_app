import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/home_feature_actions.dart';
import 'home_tier_styles.dart';

class PopularFeaturesList extends StatefulWidget {
  const PopularFeaturesList({super.key});

  @override
  State<PopularFeaturesList> createState() => _PopularFeaturesListState();
}

class _PopularFeaturesListState extends State<PopularFeaturesList> {
  static const List<Map<String, dynamic>> _fallbackItems = [
    {
      'feature_route': '/site-guide-ai',
      'feature_label': 'サイト案内AI',
      'use_count': 0,
    },
    {
      'feature_route': '/ai-university',
      'feature_label': 'AI大学',
      'use_count': 0,
    },
    {'feature_route': '/project-gantt', 'feature_label': 'WBS', 'use_count': 0},
    {
      'feature_route': '/release-notes',
      'feature_label': 'Release Notes',
      'use_count': 0,
    },
  ];

  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'home.popular', 'window_days': 30, 'limit': 8},
      );
      final data = resp.data as Map<String, dynamic>?;
      final features = data?['features'] as List<dynamic>? ?? const [];
      final items = features
          .whereType<Map<String, dynamic>>()
          .where((item) => (item['feature_route'] as String? ?? '').isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = items.isEmpty ? _fallbackItems : items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = _fallbackItems;
        _loading = false;
      });
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _items.map((item) {
          final route = _normalizeRoute(item['feature_route'] as String? ?? '');
          final label = (item['feature_label'] as String?) ??
              (item['label'] as String?) ??
              _fallbackLabel(route);
          final countValue = item['use_count'];
          final count = countValue is num ? countValue.toInt() : 0;
          return GestureDetector(
            onLongPress: route.isEmpty
                ? null
                : () => pinHomeFeature(context, route, label),
            child: ActionChip(
              avatar: const Icon(
                Icons.trending_up,
                size: 16,
                color: Color(0xFF0D9488),
              ),
              label: Text(
                count > 0 ? '$label  $count' : label,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.primaryText,
                  height: 1.5,
                ),
              ),
              backgroundColor: palette.tintedChipBackground(
                const Color(0xFF0D9488),
              ),
              side: const BorderSide(color: Color(0xFF0D9488), width: 0.8),
              onPressed: route.isEmpty
                  ? null
                  : () => openHomeFeature(context, route, label),
            ),
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
    if (route.isEmpty) return '機能';
    return route.substring(1).replaceAll('-', ' ');
  }
}
