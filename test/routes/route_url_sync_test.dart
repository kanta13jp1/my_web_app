import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/route_url_sync.dart';

import 'app_route_names.dart';

/// Flutter Web でブラウザの URL が更新される条件は 1 つだけ。Navigator 最前面
/// route の `settings.name` が null でないことである (`Navigator._flushHistoryUpdates`
/// が `settings.name` を見て `SystemNavigator.routeInformationUpdated()` を呼ぶ)。
///
/// 本アプリは `onGenerateRoute` の出口を [ensureRouteAnnouncesUrl] に通すことで、
/// どの case が `settings` を渡し忘れても URL が必ず入る単一チョークポイントにして
/// いる。ここでは (1) その wrapper の実ランタイム挙動を VM 上で直接検証し、
/// (2) wrapper が効く前提 (= 全 case が MaterialPageRoute を返す / 直叩き push は
/// 自前で settings を持つ / 名前は必ず実在 route を指す) を静的に検証する。
///
/// main.dart はアプリ全体を推移的に import するため VM ではコンパイルできない。
/// よって switch 本体はソースを静的に検査する (既存 direct_path_routes_test と同方針)。
void main() {
  group('ensureRouteAnnouncesUrl (URL を必ず入れる chokepoint)', () {
    Widget builder(BuildContext _) => const SizedBox.shrink();

    test('name の無い MaterialPageRoute には要求 URL を補う', () {
      final route = MaterialPageRoute<void>(builder: builder);
      expect(route.settings.name, isNull);

      final fixed = ensureRouteAnnouncesUrl(
        route,
        const RouteSettings(name: '/admin'),
      );

      expect(fixed, isA<MaterialPageRoute>());
      expect(
        fixed.settings.name,
        '/admin',
        reason: '渡し忘れた route に URL が入っていない = 画面は変わるが URL が変わらない',
      );
    });

    test('既に name のある route は尊重してそのまま返す', () {
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/compatibility'),
        builder: builder,
      );

      final result = ensureRouteAnnouncesUrl(
        route,
        const RouteSettings(name: '/compatibility-result?my=A&partner=B'),
      );

      expect(
        identical(result, route),
        isTrue,
        reason: 'case が意図的に名乗った URL (フォールバック等) を壊してはいけない',
      );
      expect(result.settings.name, '/compatibility');
    });

    test('補える URL が無い (requested.name == null) 場合は素通し', () {
      final route = MaterialPageRoute<void>(builder: builder);
      final result = ensureRouteAnnouncesUrl(route, const RouteSettings());
      expect(identical(result, route), isTrue);
    });

    test('MaterialPageRoute 以外 (ダイアログ等) は対象外', () {
      final route = PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
      final result = ensureRouteAnnouncesUrl(
        route,
        const RouteSettings(name: '/whatever'),
      );
      expect(identical(result, route), isTrue);
    });

    test('builder と主要フラグを引き継ぐ', () {
      final route = MaterialPageRoute<void>(
        builder: builder,
        fullscreenDialog: true,
        maintainState: false,
      );

      final fixed = ensureRouteAnnouncesUrl(
        route,
        const RouteSettings(name: '/x'),
      ) as MaterialPageRoute;

      expect(fixed.fullscreenDialog, isTrue);
      expect(fixed.maintainState, isFalse);
      expect(
        identical(fixed.builder, route.builder),
        isTrue,
        reason: '元の builder を捨てて別画面を描いてはいけない',
      );
    });
  });

  // wrapper は MaterialPageRoute にしか効かない。全 case が MaterialPageRoute を
  // 返すことを保証し、URL の入らない route が生まれないようにする。
  test('every generateAppRoute case returns a MaterialPageRoute', () {
    final offenders = _routeCases()
        .where(
          (c) =>
              !c.body.contains('MaterialPageRoute') &&
              !c.body.contains('PageRouteBuilder'),
        )
        .map((c) => c.labels.join('/'))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'MaterialPageRoute 以外を返す case は wrapper が URL を補えない:\n'
          '${offenders.join('\n')}',
    );
  });

  test('legacy duplicate routes resolve to the consolidated page', () {
    const expectedPageByLegacyRoute = <String, String>{
      '/pomodoro-timer': 'FocusTimerPage',
      '/referral-program': 'ReferralPage',
      '/habit-gamification': 'HabitCenterPage',
      '/goal-tracker': 'GoalCenterPage',
      '/social-media-scheduler': 'SocialMediaSchedulerPage',
      '/travel-itinerary': 'TravelItineraryPage',
      '/video-ad-generator': 'ViralAdGeneratorPage',
      '/viral-video-generator': 'ViralAdGeneratorPage',
      '/wip-limit': 'DigestQueuePage',
      '/local-election-schedule': 'ElectionVictoryPage',
      '/stats': 'RewardsPage',
      '/ai-summarizer': 'WritingCenterPage',
      '/manual': 'UserManualPage',
    };
    final cases = _routeCases();

    for (final expected in expectedPageByLegacyRoute.entries) {
      final routeCase = cases.singleWhere(
        (candidate) => candidate.labels.contains(expected.key),
      );
      expect(
        routeCase.body,
        contains(expected.value),
        reason: '${expected.key} が統合先 ${expected.value} を開いていない',
      );
    }
  });

  test('retired analytics route resolves to canonical non-admin home', () {
    final routeCase = _routeCases().singleWhere(
      (candidate) => candidate.labels.contains('/app-analytics-dashboard'),
    );

    expect(routeCase.body, contains("RouteSettings(name: '/')"));
    expect(routeCase.body, contains('_AuthenticatedHomePage'));
    expect(routeCase.body, contains('LandingPage'));
    expect(routeCase.body, isNot(contains('AdminAnalyticsPage')));
  });

  // 直叩き Navigator.push は onGenerateRoute を通らないので wrapper の対象外。
  // これらは各サイトで settings を持っていないと URL が変わらない。
  test('every direct Navigator.push of a page route passes settings', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r'Navigator\.(?:of\([^)]*\)\.)?push(?:Replacement)?\s*(?:<[^>]*>)?\s*\(',
      ).allMatches(source)) {
        final block = _balancedParens(source, match.end - 1);
        if (block == null) continue;
        if (!block.contains('MaterialPageRoute') &&
            !block.contains('PageRouteBuilder')) {
          continue;
        }
        if (block.contains('settings:')) continue;
        offenders.add('${entity.path}:${_lineOf(source, match.start)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'RouteSettings(name: ...) の無い push は URL を変えない:\n'
          '${offenders.join('\n')}',
    );
  });

  // settings を明示する case が、自分のラベル以外の URL を名乗っていないか。
  // (名乗ってよいのは「引数が無いと復元できず別画面へ落とす」フォールバックだけ)
  test('a case never announces a URL other than its own path', () {
    final offenders = <String>[];
    for (final entry in _routeCases()) {
      final hardcoded = RegExp(
        r"RouteSettings\(\s*name:\s*'([^']+)'",
      ).firstMatch(entry.body);
      if (hardcoded == null) continue;
      final name = hardcoded.group(1)!;
      if (entry.labels.contains(name)) continue;
      if (_intentionalFallbacks[entry.labels.firstOrNull] == name) continue;
      offenders.add('${entry.labels} -> $name');
    }

    expect(
      offenders,
      isEmpty,
      reason: '画面と URL が食い違う route:\n${offenders.join('\n')}',
    );
  });

  test('every hardcoded route name resolves to a registered route', () {
    final registered = _registeredRoutes();
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r"RouteSettings\(\s*name:\s*'([^']+)'",
      ).allMatches(source)) {
        final route = match.group(1)!.split('?').first;
        // 競合比較ページは `/vs-<key>` を default 節がまとめて処理する。
        if (route.startsWith('/vs-')) continue;
        if (registered.contains(route)) continue;
        offenders
            .add('${entity.path}:${_lineOf(source, match.start)} -> $route');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'リロード/共有すると復元できない URL:\n${offenders.join('\n')}',
    );
  });

  // 全 route を 1 件ずつ扱う VM 検証 (上の case テスト) が main.dart と一致した
  // 一覧の上で回るよう、kAllAppRoutes と main.dart の完全一致を保証する。
  test('kAllAppRoutes matches the routes registered in main.dart', () {
    final registered = _registeredRoutes();
    final listed = kAllAppRoutes.toSet();

    expect(
      registered.difference(listed).toList()..sort(),
      isEmpty,
      reason: 'main.dart に足した route が app_route_names.dart に無い',
    );
    expect(
      listed.difference(registered).toList()..sort(),
      isEmpty,
      reason: 'app_route_names.dart に main.dart から消えた route が残っている',
    );
  });

  // トップ画面の機能カタログ (= ユーザーから見た「全機能」) が
  // 1 件残らず URL を持つことを確認する。
  test('every home catalog feature has a registered route', () {
    final registered = _registeredRoutes();
    final catalog = File('lib/data/home_tool_catalog.dart').readAsStringSync();
    final ids = RegExp(
      r"^      id: '([^']+)',",
      multiLine: true,
    ).allMatches(catalog).map((m) => m.group(1)!).toList();

    expect(ids, isNotEmpty, reason: 'カタログの id 抽出に失敗している');

    final offenders = ids
        .map((id) => MapEntry(id, _catalogRouteForId(id)))
        .where((e) => e.value != null && !registered.contains(e.value))
        .map((e) => '${e.key} -> ${e.value}')
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'URL の無いトップ画面機能:\n${offenders.join('\n')}',
    );
  });

  test('distinct home catalog features do not share a route', () {
    final catalog = File('lib/data/home_tool_catalog.dart').readAsStringSync();
    final ids = RegExp(
      r"^      id: '([^']+)',",
      multiLine: true,
    ).allMatches(catalog).map((match) => match.group(1)!).toList();
    final idsByRoute = <String, List<String>>{};

    for (final id in ids) {
      final route = _catalogRouteForId(id);
      if (route == null) continue;
      idsByRoute.putIfAbsent(route, () => <String>[]).add(id);
    }

    final duplicates = idsByRoute.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
        .toList(growable: false);

    expect(
      duplicates,
      isEmpty,
      reason: '異なるホーム機能が同じ URL を共有している:\n${duplicates.join('\n')}',
    );
  });
}

/// 引数が無いと画面を復元できないため、意図的に別 route へ落とすもの。
/// URL は必ず変わるが、実際に表示する画面に合わせた URL を名乗る。
const Map<String?, String> _intentionalFallbacks = <String?, String>{
  // Retired analytics UI must not expose the unguarded admin analytics page.
  '/app-analytics-dashboard': '/',
  // 出走表は race マップ全体が必要で URL からは復元できない。
  '/horse-racing/race': '/horse-racing/predictions',
  // `case` ラベルが定数なので識別子のまま照合する (= '/compatibility-result')。
  // my/partner の query が欠けていると結果を描けないので診断入口へ落とす。
  'compatibilityResultRoutePath': '/compatibility',
};

/// `_homeToolRoutePathForId` (home_tool_catalog.dart) と同じ対応表。
String? _catalogRouteForId(String id) => switch (id) {
      'digital-danshari' => '/digital-danshari',
      'agent-org' => '/agents',
      'admin-analytics' => '/admin',
      'edge-function-status' => '/edge-functions',
      'public-profile' => null,
      _ => '/$id',
    };

Set<String> _registeredRoutes() {
  final body = _generateAppRouteBody();
  final routes = <String>{};
  for (final match
      in RegExp(r'^    case\s+([^:]+):', multiLine: true).allMatches(body)) {
    final caseExpr = match.group(1)!;
    for (final routeMatch in RegExp(r"'([^']+)'").allMatches(caseExpr)) {
      routes.add(routeMatch.group(1)!);
    }
  }
  return routes
    // 定数経由で宣言している route。
    ..add('/compatibility-result');
}

String _generateAppRouteBody() {
  final source = File('lib/main.dart').readAsStringSync();
  final start = source.indexOf('Route<dynamic> generateAppRoute(');
  expect(start, isNot(-1), reason: 'generateAppRoute が見つからない');
  return source.substring(start);
}

class _RouteCase {
  final List<String> labels;
  final String body;
  const _RouteCase(this.labels, this.body);
}

/// `case '/a': case '/b': <body>` を 1 件にまとめて返す。
List<_RouteCase> _routeCases() {
  final body = _generateAppRouteBody();
  final matches =
      RegExp(r'^    case (.+):$', multiLine: true).allMatches(body).toList();
  final cases = <_RouteCase>[];
  var pendingLabels = <String>[];
  for (var i = 0; i < matches.length; i++) {
    final raw = matches[i].group(1)!.trim();
    final label = RegExp(r"^'(.+)'$").firstMatch(raw)?.group(1);
    pendingLabels.add(label ?? raw);
    final end = i + 1 < matches.length ? matches[i + 1].start : body.length;
    final segment = body.substring(matches[i].end, end);
    // return を含まない segment は次の case に流れ落ちるラベル (コメントのみでも同じ)。
    if (!segment.contains('return ')) continue;
    cases.add(_RouteCase(List<String>.of(pendingLabels), segment));
    pendingLabels = <String>[];
  }
  return cases;
}

/// [open] 位置の `(` に対応する `)` までを返す。対応が取れなければ null。
String? _balancedParens(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return null;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;
