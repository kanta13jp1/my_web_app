import 'package:flutter/material.dart';

/// 画面遷移で必ずブラウザ URL が変わるようにするための単一チョークポイント。
///
/// Flutter Web は Navigator 最前面 route の `settings.name` が null でないときだけ
/// `SystemNavigator.routeInformationUpdated()` を呼ぶ
/// (`Navigator._flushHistoryUpdates`)。`MaterialPageRoute` は `settings` 省略時に
/// `name` が null の `const RouteSettings()` を使うため、`onGenerateRoute` の case が
/// `settings` を渡し忘れると「画面は変わるのに URL が変わらない / ブラウザの戻る
/// 履歴も積まれない」状態になる (実際に 260+ route がこの状態だった)。
///
/// この関数を `onGenerateRoute` の出口に一度だけ挟めば、どの case が渡し忘れても
/// 要求された [requested] (= 遷移先 URL を含む `RouteSettings`) を補って返すので
/// URL が必ず更新される。各 case に `settings:` を書いて回る必要がなくなり、
/// 将来 route を足すときの付け忘れも構造的に起きない。
///
/// 既に名前が入っている route はそのまま返すので、case が意図的に別 URL を名乗る
/// フォールバック (引数が無いと復元できない画面を一覧へ落とす等) は壊さない。
Route<dynamic> ensureRouteAnnouncesUrl(
  Route<dynamic> route,
  RouteSettings requested,
) {
  // 既に URL 名を持つ route は尊重する。補える URL が無い (requested.name == null)
  // 場合も手を出さない。対象は名前欠落の MaterialPageRoute のみ。
  if (route is! MaterialPageRoute ||
      route.settings.name != null ||
      requested.name == null) {
    return route;
  }
  // builder 以外の指定 (フルスクリーンダイアログ等) を落とさないよう引き継ぐ。
  return MaterialPageRoute<dynamic>(
    settings: requested,
    builder: route.builder,
    maintainState: route.maintainState,
    fullscreenDialog: route.fullscreenDialog,
    allowSnapshotting: route.allowSnapshotting,
  );
}
