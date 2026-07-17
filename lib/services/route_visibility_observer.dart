import 'package:flutter/widgets.dart';

/// deep link (/admin や公開メモ等) を直接開くと Flutter の初期ルート展開が
/// ['/', '<deep link>'] を積み、ルート '/' の HomePage / LandingPage が不可視の
/// まま下に mount される。その状態で fetch・計測 (LP View 等) を発火させない
/// よう、「上のルートが pop され可視になった瞬間 (didPopNext)」を購読するための
/// 共有 RouteObserver。main.dart の navigatorObservers に登録する。
final RouteObserver<ModalRoute<void>> deepLinkVisibilityRouteObserver =
    RouteObserver<ModalRoute<void>>();
