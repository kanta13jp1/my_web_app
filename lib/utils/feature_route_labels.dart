import 'dart:async';

import '../data/home_system_fixed.dart';
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

/// route -> ラベルの参照表。`kHomeSystemFixed`(主要固定機能)から構築する。
///
/// home ツールカタログ由来の機能は `_runTrackedAction` 側が日本語タイトルで
/// 既に利用記録しており、かつ `Navigator.push`(= `onGenerateRoute` を通らない)
/// ため、ここでカタログを import する必要はない。重いページ群の import を避ける
/// ことで VM テストでも安全に評価できる。
Map<String, String> _featureRouteLabels() {
  return _labelCache ??= <String, String>{
    for (final f in kHomeSystemFixed) f.route: f.label,
  };
}

/// route からラベルを解決する。固定機能に無ければ slug を整形して返す。
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
