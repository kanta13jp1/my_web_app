import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/universal_ai_share_shell.dart';

void main() {
  // R33: AI シェア FAB は Navigator Overlay に載りページの AppBar より前面に出る。
  // top 配置が AppBar 高さより上だと actions (例 /admin のデータリセット・更新)
  // を覆って押せなくなるため、ツールバー高さを必ず超える不変条件を固定する。
  test('top 配置の FAB オフセットは標準 AppBar 高さを超える', () {
    expect(
      kAiShareFabTopOffset,
      greaterThan(kToolbarHeight),
      reason: 'top 配置で AppBar の actions を覆ってはならない',
    );
  });

  test('よくある拡張 AppBar (toolbarHeight: 74) も塞がない', () {
    // home_page など toolbarHeight を広げたページでも干渉しないこと。
    expect(kAiShareFabTopOffset, greaterThan(74.0));
  });
}
