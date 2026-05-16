import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiRecommendedFeaturesList extends StatefulWidget {
  const AiRecommendedFeaturesList({super.key});

  @override
  State<AiRecommendedFeaturesList> createState() =>
      _AiRecommendedFeaturesListState();
}

class _AiRecommendedFeaturesListState extends State<AiRecommendedFeaturesList> {
  static const List<Map<String, dynamic>> _fallbackItems = [
    {
      'feature_route': '/site-guide-ai',
      'label': 'サイト案内AI',
      'reason': '目的に近い入口をAIに案内してもらえます。',
    },
    {
      'feature_route': '/release-notes',
      'label': 'Release Notes',
      'reason': '最近追加された機能や修正をバージョン別に確認できます。',
    },
    {
      'feature_route': '/ai-university',
      'label': 'AI大学',
      'reason': '最新AIツールの学習とランキング確認を続けられます。',
    },
  ];

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
      setState(() {
        _items = _fallbackItems;
        _loading = false;
      });
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
          _items = items.whereType<Map<String, dynamic>>().toList();
          if (_items.isEmpty) _items = _fallbackItems;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _items = _fallbackItems;
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
              'AIがおすすめ機能を分析中...',
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

    return Column(
      children: [
        if (_error != null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'おすすめの取得に失敗したため、固定候補を表示しています。',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ..._items.map((item) {
          final route = _normalizeRoute(
            _stringValue(item['feature_route']) ??
                _stringValue(item['route']) ??
                _stringValue(item['id']) ??
                '',
          );
          final label = _stringValue(item['label']) ??
              _stringValue(item['feature_label']) ??
              _fallbackLabel(route) ??
              _stringValue(item['title']) ??
              'おすすめ機能';
          final reason = _stringValue(item['reason']) ?? _fallbackReason(route);
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
            onTap: route.isEmpty
                ? null
                : () => Navigator.pushNamed(context, route),
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

  static String? _fallbackLabel(String route) {
    if (route.isEmpty) return null;
    return route.substring(1).replaceAll('-', ' ');
  }

  static String _fallbackReason(String route) {
    if (route == '/release-notes') {
      return '最近の変更点をバージョン別に確認できます。';
    }
    if (route == '/site-guide-ai') {
      return '迷ったときに次の入口をすばやく探せます。';
    }
    return '利用頻度と固定導線から優先候補として表示しています。';
  }

  static String? _stringValue(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || _isLikelyMojibake(text)) return null;
    return text;
  }

  static bool _isLikelyMojibake(String text) {
    return text.contains('縺') ||
        text.contains('繝') ||
        text.contains('譁') ||
        text.contains('蟄') ||
        text.contains('螟');
  }
}
