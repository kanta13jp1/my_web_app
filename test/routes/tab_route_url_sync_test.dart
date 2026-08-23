import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// タブ切替を URL に反映する仕組み ([tab_route_url_sync.dart]) のガード。
///
/// (1) URL の組み立て / 解釈を担う純関数を VM 上で直接検証し、
/// (2) mixin が実際に `SystemNavigator.routeInformationUpdated` を呼ぶことを
///     ウィジェットテストで検証し、
/// (3) 適用済みページのスラッグ定義がタブ数と一致しているかを静的に検証する。
///
/// アプリ全体を推移的に import するとテストがコンパイルできないため、
/// (3) は既存の route ガードと同じくソースを静的に検査する。
void main() {
  group('tabSyncRouteName (URL の組み立て)', () {
    const slugs = ['overview', 'budget', 'simulation'];

    test('既定タブ (index 0) は query を付けない', () {
      expect(
        tabSyncRouteName(
          currentRouteName: '/budget-financial-planner',
          slugs: slugs,
          index: 0,
        ),
        '/budget-financial-planner',
      );
    });

    test('index 1 以降は ?tab=<slug> を付ける', () {
      expect(
        tabSyncRouteName(
          currentRouteName: '/budget-financial-planner',
          slugs: slugs,
          index: 1,
        ),
        '/budget-financial-planner?tab=budget',
      );
    });

    test('既存の query は捨てて path だけを土台にする', () {
      expect(
        tabSyncRouteName(
          currentRouteName: '/budget-financial-planner?tab=simulation',
          slugs: slugs,
          index: 1,
        ),
        '/budget-financial-planner?tab=budget',
        reason: 'タブを切り替えるたびに query が積み重なってはいけない',
      );
    });

    test('route 名が無い / index が範囲外なら null (URL を触らない)', () {
      expect(
        tabSyncRouteName(currentRouteName: null, slugs: slugs, index: 1),
        isNull,
      );
      expect(
        tabSyncRouteName(currentRouteName: '/x', slugs: slugs, index: 9),
        isNull,
      );
      expect(
        tabSyncRouteName(currentRouteName: '/x', slugs: slugs, index: -1),
        isNull,
      );
    });
  });

  group('tabIndexFromRouteName (URL の解釈)', () {
    const slugs = ['daily', 'weekly', 'monthly'];

    test('スラッグから index を復元する', () {
      expect(
        tabIndexFromRouteName(
          routeName: '/financial-report?tab=monthly',
          slugs: slugs,
        ),
        2,
      );
    });

    test('query 無しなら null (既定タブのまま)', () {
      expect(
        tabIndexFromRouteName(routeName: '/financial-report', slugs: slugs),
        isNull,
      );
    });

    test('未知のスラッグでも例外にせず null (古い共有リンクを壊さない)', () {
      expect(
        tabIndexFromRouteName(
          routeName: '/financial-report?tab=quarterly',
          slugs: slugs,
        ),
        isNull,
      );
    });

    test('組み立てと解釈が往復する', () {
      for (var i = 0; i < slugs.length; i++) {
        final url = tabSyncRouteName(
          currentRouteName: '/financial-report',
          slugs: slugs,
          index: i,
        );
        final back = tabIndexFromRouteName(routeName: url, slugs: slugs);
        // index 0 は query を付けないので null (= 既定タブ) に戻るのが正しい。
        expect(back, i == 0 ? isNull : i, reason: 'index $i で往復しない');
      }
    });
  });

  group('TabRouteUrlSync mixin (実ランタイム)', () {
    late List<String> announced;

    setUp(() {
      announced = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        if (call.method == 'routeInformationUpdated') {
          final args = call.arguments as Map<Object?, Object?>;
          announced.add((args['uri'] ?? args['location']).toString());
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, null);
    });

    Future<void> pump(WidgetTester tester, String routeName) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: routeName,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const _TabProbe(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('タブを切り替えると URL が通知される', (tester) async {
      await pump(tester, '/probe');
      announced.clear();

      tester.state<_TabProbeState>(find.byType(_TabProbe)).goTo(2);
      await tester.pumpAndSettle();

      expect(
        announced,
        contains('/probe?tab=third'),
        reason: 'タブが変わったのにブラウザ URL が更新されていない',
      );
    });

    testWidgets('既定タブへ戻すと query の無い URL に戻る', (tester) async {
      await pump(tester, '/probe');
      final probe = tester.state<_TabProbeState>(find.byType(_TabProbe));

      probe.goTo(1);
      await tester.pumpAndSettle();
      announced.clear();

      probe.goTo(0);
      await tester.pumpAndSettle();

      expect(announced, contains('/probe'));
    });

    testWidgets('?tab= 付きで開くとそのタブが復元される', (tester) async {
      await pump(tester, '/probe?tab=second');

      expect(
        tester.state<_TabProbeState>(find.byType(_TabProbe)).controller.index,
        1,
        reason: '共有リンク/リロードでタブが復元されない',
      );
    });

    testWidgets('未知のスラッグなら既定タブで開く (壊れない)', (tester) async {
      await pump(tester, '/probe?tab=removed-tab');

      expect(
        tester.state<_TabProbeState>(find.byType(_TabProbe)).controller.index,
        0,
      );
    });
  });

  // スラッグの数がタブ数とずれると、URL が別のタブを指したり範囲外で
  // 無視されたりする。適用済みページで一致していることを保証する。
  test('applied pages: tabUrlSlugs の数が TabController の length と一致する', () {
    final offenders = <String>[];
    var checked = 0;

    for (final entity in Directory('lib/pages').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('TabRouteUrlSync')) continue;
      if (_dynamicSlugPages.any(entity.path.replaceAll(r'\', '/').endsWith)) {
        // タブが実行時に決まるページ。静的にスラッグ数を数えられないので、
        // ここでは対象外にし、代わりに下の専用テストで契約を確認する。
        continue;
      }

      // `=>` と `const` の間、`<String>[` の前後は dart format が行を折り返す
      // ことがある (スラッグが多いページで必ず起きる)。空白・改行を許容しないと
      // 「読めない」という偽の失敗になるため、区切りは \s* で受ける。
      final slugMatch = RegExp(
        r'List<String>\s+get\s+tabUrlSlugs\s*=>\s*const\s*<String>\s*\[([\s\S]*?)\];',
      ).firstMatch(source);
      final lenMatch = RegExp(
        r'TabController\(\s*length:\s*(\d+)',
      ).firstMatch(source);

      if (slugMatch == null || lenMatch == null) {
        offenders.add('${entity.path}: スラッグ定義か TabController が読めない');
        continue;
      }
      checked++;
      final slugs = RegExp(
        r"'([^']+)'",
      ).allMatches(slugMatch.group(1)!).map((m) => m.group(1)!).toList();
      final length = int.parse(lenMatch.group(1)!);

      if (slugs.length != length) {
        offenders.add('${entity.path}: slugs=${slugs.length} vs tabs=$length');
      }
      if (slugs.toSet().length != slugs.length) {
        offenders.add('${entity.path}: スラッグが重複している ($slugs)');
      }
      for (final s in slugs) {
        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(s)) {
          offenders.add('${entity.path}: URL に使えないスラッグ "$s"');
        }
      }
    }

    expect(checked, greaterThan(0), reason: '適用済みページを 1 つも検出できていない');
    expect(offenders, isEmpty, reason: 'タブとスラッグの不整合:\n${offenders.join('\n')}');
  });

  // 動的スラッグのページは静的に数えられない代わりに、
  // 「controller を作り直したら必ず張り替える」契約が守られているかを見る。
  // これを忘れると古い controller に listener が残り、タブを切っても URL が
  // 変わらない (= 対応したつもりで効いていない) 状態になる。
  test('dynamic-slug pages rebind after recreating their TabController', () {
    for (final rel in _dynamicSlugPages) {
      final raw = File('lib/pages/${rel.split('/').last}').readAsStringSync();
      // コメント中の `rebindTabUrlSync()` (使い方の説明) を実際の呼び出しと
      // 数え間違えると、呼び出しを消しても緑のままになる。行コメントを落とす。
      final source = raw
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      final assigns = RegExp(r'_tabController = ').allMatches(source).length;
      final rebinds = RegExp(r'rebindTabUrlSync\(\)').allMatches(source).length;

      expect(
        assigns,
        greaterThan(0),
        reason: '$rel: TabController の代入が見つからない (このリストが古い可能性)',
      );
      expect(
        rebinds,
        greaterThanOrEqualTo(assigns),
        reason: '$rel: TabController を $assigns 回作り直しているのに '
            'rebindTabUrlSync() が $rebinds 回しかない。'
            '張り替え漏れがあるとタブを切っても URL が変わらない。',
      );
    }
  });
}

/// タブ数が実行時に決まるため、スラッグ数を静的に検証できないページ。
/// (AI 大学はプロバイダ一覧を取得してからタブを作る)
const List<String> _dynamicSlugPages = <String>[
  'lib/pages/gemini_university_v2_page.dart',
];

class _TabProbe extends StatefulWidget {
  const _TabProbe();

  @override
  State<_TabProbe> createState() => _TabProbeState();
}

class _TabProbeState extends State<_TabProbe>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  late final TabController controller;

  @override
  List<String> get tabUrlSlugs => const <String>['first', 'second', 'third'];

  @override
  TabController get tabUrlController => controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 3, vsync: this);
  }

  void goTo(int index) => controller.index = index;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: controller,
        children: const [
          SizedBox.shrink(),
          SizedBox.shrink(),
          SizedBox.shrink(),
        ],
      ),
    );
  }
}
