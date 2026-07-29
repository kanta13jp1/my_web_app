import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 同一ページ内のタブ切替を URL (`?tab=<slug>`) に反映するための仕組み。
///
/// [route_url_sync.dart](route_url_sync.dart) が「別画面への遷移」で URL を必ず
/// 変える単一チョークポイントなのに対し、こちらは「画面は同じだがユーザーから
/// 見える内容が変わる」タブ切替を URL に載せる。共有・リロード・ブックマークで
/// 同じタブを復元できるようにするのが目的。
///
/// **`main.dart` の route 定義は一切増やさない。** 各ページが自分の
/// `RouteSettings.name` から query を読み書きするので、340 個の route はそのまま。
///
/// スラッグ (index ではなく名前) を使うのは、タブを並べ替えたときに既存の共有
/// リンクが黙って別のタブを開くのを防ぐため。

/// URL の `?tab=` に載せるキー。
const String tabRouteQueryParam = 'tab';

/// [index] のタブを指す route 名を組み立てる。
///
/// 既定タブ (index 0) は query を付けない (`/foo`)。それ以外は `/foo?tab=<slug>`。
/// 組み立てられない場合 (route 名が無い / index が範囲外) は null を返し、
/// 呼び出し側は URL 更新を行わない。
String? tabSyncRouteName({
  required String? currentRouteName,
  required List<String> slugs,
  required int index,
}) {
  if (currentRouteName == null) return null;
  if (index < 0 || index >= slugs.length) return null;
  final path = Uri.parse(currentRouteName).path;
  if (path.isEmpty) return null;
  if (index == 0) return path;
  return '$path?$tabRouteQueryParam=${Uri.encodeQueryComponent(slugs[index])}';
}

/// route 名の `?tab=` から復元すべきタブ index を解決する。
///
/// query が無い / 未知のスラッグなら null を返す (= 呼び出し側は既定タブのまま)。
/// 未知スラッグでエラーにしないのは、古い共有リンクを踏んでも画面が壊れず
/// 既定タブで開けるようにするため。
int? tabIndexFromRouteName({
  required String? routeName,
  required List<String> slugs,
}) {
  if (routeName == null) return null;
  final slug = Uri.parse(routeName).queryParameters[tabRouteQueryParam];
  if (slug == null || slug.isEmpty) return null;
  final index = slugs.indexOf(slug);
  return index < 0 ? null : index;
}

/// タブ付きページに付けると、タブ切替が URL に反映され、URL からタブが復元される。
///
/// 使い方: `with TickerProviderStateMixin, TabRouteUrlSync` を付け、
/// [tabUrlSlugs] と [tabUrlController] を実装する。`TabController` の生成は
/// 従来どおり `initState` のままでよい。
///
/// 注意: このページで `didChangeDependencies` / `dispose` を override する場合は
/// 必ず `super` を呼ぶこと (呼ばないと同期が動かない / listener が残る)。
mixin TabRouteUrlSync<T extends StatefulWidget> on State<T> {
  /// タブ index → URL スラッグ。**TabBar の並び順と一致させること。**
  /// 検証は `test/routes/tab_route_url_sync_test.dart` が行う。
  List<String> get tabUrlSlugs;

  /// URL と同期する `TabController`。
  TabController get tabUrlController;

  bool _tabUrlBound = false;
  String? _tabUrlRouteName;
  int? _lastAnnouncedTabIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabUrlBound) return;
    _tabUrlBound = true;

    _tabUrlRouteName = ModalRoute.of(context)?.settings.name;
    final initial = tabIndexFromRouteName(
      routeName: _tabUrlRouteName,
      slugs: tabUrlSlugs,
    );
    if (initial != null && initial != tabUrlController.index) {
      tabUrlController.index = initial;
    }
    _lastAnnouncedTabIndex = tabUrlController.index;
    tabUrlController.addListener(_announceTabUrl);
  }

  void _announceTabUrl() {
    if (!mounted) return;
    final index = tabUrlController.index;
    // TabController の listener はアニメーション中に何度も発火するため、
    // 実際に index が変わった 1 回だけ URL を更新する。
    if (index == _lastAnnouncedTabIndex) return;
    // このページが最前面でないときに URL を書くと、上に積まれた別画面の URL を
    // 奪ってしまう。最前面のときだけ名乗る。
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;

    final next = tabSyncRouteName(
      currentRouteName: _tabUrlRouteName,
      slugs: tabUrlSlugs,
      index: index,
    );
    if (next == null) return;
    _lastAnnouncedTabIndex = index;
    // replace: true = 履歴に積まない。タブを何度切り替えても、戻るキー 1 回で
    // 前の画面へ戻れるようにする (既存の horse_racing_predictor_page と同じ方針)。
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(next),
      replace: true,
    );
  }

  @override
  void dispose() {
    if (_tabUrlBound) {
      tabUrlController.removeListener(_announceTabUrl);
    }
    super.dispose();
  }
}
