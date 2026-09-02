import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/home_feature_actions.dart';
import 'home_tier_styles.dart';

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
      // dedup 前に十分な履歴を取得する。limit を dedup より先に効かせると、
      // 多用機能(例: サイト案内AI)の連続タップが直近行を占有し、たまにしか
      // 使わない機能(例: 統一地方選必達管理室)が窓から押し出されて
      // 「最近使った機能」に出てこない。多めに取得してから distinct 上位を採る。
      final rows = await Supabase.instance.client
          .from('user_feature_usage')
          .select('feature_route, feature_label, tapped_at')
          .eq('user_id', user.id)
          .order('tapped_at', ascending: false)
          .limit(200);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final row in rows) {
        final route = row['feature_route'] as String? ?? '';
        if (route.isNotEmpty && seen.add(route)) deduped.add(row);
        if (deduped.length >= 10) break;
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
          'まだ利用履歴がありません。',
          style: TextStyle(
            color: palette.secondaryText,
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
          return GestureDetector(
            onLongPress: route.isEmpty
                ? null
                : () => pinHomeFeature(context, route, label),
            child: ActionChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.primaryText,
                  height: 1.5,
                ),
              ),
              backgroundColor: palette.chipBackground,
              side: BorderSide(color: palette.chipBorder),
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
}
