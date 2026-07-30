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
  ///
  /// まだ用意できていない場合 (タブ数が非同期ロード後に決まるページ) は null を
  /// 返してよい。その間は同期を行わず、用意できた時点で [rebindTabUrlSync] を
  /// 呼べば同期が始まる。
  TabController? get tabUrlController;

  String? _tabUrlRouteName;
  int? _lastAnnouncedTabIndex;

  /// 現在 listener を張っている controller。作り直しを検知して張り替えるために
  /// 「束縛済みフラグ」ではなく実体を持つ (フラグだと古い controller に listener が
  /// 残り、新しい方は同期されない)。
  TabController? _boundController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabUrlRouteName ??= ModalRoute.of(context)?.settings.name;
    _bindTabUrl();
  }

  /// `TabController` を作り直したページは、新しい controller を作った直後に
  /// これを呼ぶ。古い listener を外して張り替え、URL からのタブ復元をやり直す。
  ///
  /// 例: プロバイダ一覧を取得してから `TabController(length: providers.length)` を
  /// 作る AI 大学のようなページ。
  void rebindTabUrlSync() {
    _tabUrlRouteName ??= ModalRoute.of(context)?.settings.name;
    _bindTabUrl();
  }

  void _bindTabUrl() {
    final controller = tabUrlController;
    if (controller == null || identical(controller, _boundController)) return;

    _boundController?.removeListener(_announceTabUrl);
    _boundController = controller;

    final initial = tabIndexFromRouteName(
      routeName: _tabUrlRouteName,
      slugs: tabUrlSlugs,
    );
    if (initial != null && initial != controller.index) {
      controller.index = initial;
    }
    _lastAnnouncedTabIndex = controller.index;
    controller.addListener(_announceTabUrl);
  }

  void _announceTabUrl() {
    if (!mounted) return;
    final controller = _boundController;
    if (controller == null) return;
    final index = controller.index;
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
    // 張り替え後は必ず最後に束縛した controller から外す (作り直し前の
    // controller は既に _bindTabUrl で外してある)。
    _boundController?.removeListener(_announceTabUrl);
    super.dispose();
  }
}
