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
  // Retired compatibility URL. It resolves to the canonical home route.
  '/app-analytics-dashboard',
};

/// 旧導線や重複実装から、利用者に見せる正規機能へ集約する対応表。
///
/// 旧 URL 自体は [generateAppRoute] で引き続き受け付ける。一方、利用履歴まで
/// 旧 URL のまま保存すると「最近使った機能 / よく使われる機能」に同じ機能が
/// 複数表示されるため、計測上は必ず正規 route に寄せる。
const Map<String, String> kCanonicalFeatureRouteAliases = <String, String>{
  '/ai-summarizer': '/ai-writing-assistant',
  '/autonomous-ops': '/autonomous-ops-console',
  '/billing': '/subscription-billing',
  '/expense-tracker': '/asset-management',
  '/gemini-university': '/ai-university',
  '/goal-tracker': '/life-goals',
  '/habit-gamification': '/daily-habits',
  '/local-election-schedule': '/local-election-700',
  '/mindmap': '/mind-map',
  '/musubi': '/social-feed',
  '/notes': '/note-list',
  '/one-in-two-out': '/one-in-two-out-assist',
  '/pomodoro-timer': '/focus-timer',
  '/referral-program': '/referral',
  '/stats': '/rewards',
  '/social-media-scheduler': '/social-scheduler',
  '/travel-itinerary': '/travel-planner',
  '/video-ad-generator': '/viral-ad-generator',
  '/viral-video-generator': '/viral-ad-generator',
  '/wip-limit': '/digest-queue',
};

const Map<String, String> _consolidatedFeatureLabels = <String, String>{
  '/sound-bloom': '音と光の庭 · SOUND BLOOM',
  '/aero-lab': '3D実験室 · AERO LAB',
  '/ai-writing-assistant': 'AI文章・要約アシスタント',
  '/ai-university-toeic': 'AI大学 TOEIC対策',
  '/art-museums': '全国の美術館',
  '/asset-management': '資産・家計管理',
  '/autonomous-ops-console': '自律オペレーションコンソール',
  '/custom-task-list': 'AI カスタムタスクリスト',
  '/focus-timer': '集中タイマー',
  '/life-goals': '人生目標管理',
  '/local-election-700': '2027 統一地方選 700必達管理室',
  '/daily-habits': '毎日の習慣',
  '/mind-map': 'マインドマップ',
  '/one-in-two-out-assist': '1 In 2 Out UI整理アシスト',
  '/procrastination-reset': '先延ばしリセット',
  '/proactive-form-check': '入力チェックアシスタント',
  '/referral': '友達招待・紹介プログラム',
  '/rewards': '実績・リワード',
  '/social-feed': 'MUSUBI ソーシャル',
  '/social-scheduler': 'SNS投稿スケジューラー',
  '/subscription-billing': 'サブスクリプション管理',
  '/travel-planner': '旅行プランナー',
  '/viral-ad-generator': 'バイラル広告ジェネレーター',
  '/digest-queue': '消化してから次へ',
};

/// 別名 route を、履歴・おすすめ・表示名で共通利用する正規 route に変換する。
String canonicalFeatureRoutePath(String route) =>
    kCanonicalFeatureRouteAliases[route] ?? route;

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
    ..._consolidatedFeatureLabels,
  };
}

/// route からラベルを解決する。固定機能に無ければ slug を整形して返す。
String featureLabelForRoute(String route) {
  final parsedPath = Uri.tryParse(route)?.path;
  final path = parsedPath == null || parsedPath.isEmpty ? route : parsedPath;
  final canonicalPath = canonicalFeatureRoutePath(path);
  return _featureRouteLabels()[canonicalPath] ?? _titleFromRoute(canonicalPath);
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
  final canonicalPath = canonicalFeatureRoutePath(path);
  unawaited(
    recordFeatureTap(canonicalPath, featureLabelForRoute(canonicalPath)),
  );
}
