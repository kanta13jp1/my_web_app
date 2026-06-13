import 'dart:async';

import '../data/home_system_fixed.dart';
import '../data/home_tool_catalog.dart';
import 'feature_tap_logger.dart';

/// 「最近使った機能 / よく使われる機能」に集計しないルート。
/// 認証・アプリシェル・ホーム自体など、機能チップとして並べる対象外の導線。
const Set<String> _nonFeatureRoutes = <String>{
  '/',
  '/login',
  '/home',
  '/landing',
  '/maintenance',
};

Map<String, String>? _labelCache;
bool _catalogLoaded = false;

/// route -> ラベルの参照表。
/// `kHomeSystemFixed` と home ツールカタログから構築し、カタログ構築に
/// 成功した時点でキャッシュする（Supabase 未初期化時は次回再試行）。
Map<String, String> _featureRouteLabels() {
  if (_catalogLoaded && _labelCache != null) return _labelCache!;
  final map = <String, String>{
    for (final f in kHomeSystemFixed) f.route: f.label,
  };
  try {
    for (final entry in buildHomeToolCatalog()) {
      final route = entry.routePath;
      if (route != null && route.isNotEmpty) {
        map.putIfAbsent(route, () => entry.title);
      }
    }
    _catalogLoaded = true;
  } catch (_) {
    // カタログ構築失敗時は system-fixed 分とフォールバックで継続する。
  }
  _labelCache = map;
  return map;
}

/// route からラベルを解決する。カタログに無ければ slug を整形して返す。
String featureLabelForRoute(String route) {
  return _featureRouteLabels()[route] ?? _titleFromRoute(route);
}

String _titleFromRoute(String route) {
  final segments = route.split('/').where((part) => part.isNotEmpty).toList();
  if (segments.isEmpty) return route;
  return segments.last
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

/// named route 遷移を利用履歴 (`user_feature_usage`) に記録する共通フック。
///
/// `MaterialApp.onGenerateRoute` から全ての `Navigator.pushNamed` 遷移に対して
/// 呼ばれ、トップページの 5-tier（最近使った / よく使われる）へ反映される。
/// これまで home tier チップ等の一部導線でしか記録されず、主要導線の
/// 直叩き `pushNamed` が履歴に残らなかった機能不全を解消する。
void recordFeatureRouteNavigation(String? routeName) {
  if (routeName == null || routeName.isEmpty) return;
  final path = Uri.tryParse(routeName)?.path ?? routeName;
  if (path.isEmpty || _nonFeatureRoutes.contains(path)) return;
  unawaited(recordFeatureTap(path, featureLabelForRoute(path)));
}
