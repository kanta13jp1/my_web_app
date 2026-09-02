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

  test('LPのモバイル下部では登録CTAの上に退避する', () {
    expect(
      resolveAiShareFabBottomOffset(routePath: '/', screenWidth: 390),
      kAiShareFabLandingBottomOffset,
    );
    expect(
      kAiShareFabLandingBottomOffset,
      greaterThan(kAiShareFabDefaultBottomOffset),
    );
  });

  test('LP以外またはデスクトップでは既定位置を維持する', () {
    expect(
      resolveAiShareFabBottomOffset(routePath: '/notes', screenWidth: 390),
      kAiShareFabDefaultBottomOffset,
    );
    expect(
      resolveAiShareFabBottomOffset(routePath: '/', screenWidth: 1200),
      kAiShareFabDefaultBottomOffset,
    );
  });

  test('MUSUBIではDM送信ボタンの上に退避する', () {
    for (final routePath in <String>['/musubi', '/social-feed']) {
      expect(
        resolveAiShareFabBottomOffset(
          routePath: routePath,
          screenWidth: 1280,
        ),
        kAiShareFabMusubiBottomOffset,
      );
    }
    expect(
      kAiShareFabMusubiBottomOffset,
      greaterThan(kAiShareFabDefaultBottomOffset),
    );
  });

  test('anonymous landing hides only the universal share FAB', () {
    expect(
      shouldShowUniversalAiShareFab(routePath: '/', isLoggedIn: false),
      isFalse,
    );
    expect(
      shouldShowUniversalAiShareFab(routePath: '/', isLoggedIn: true),
      isTrue,
    );
    expect(
      shouldShowUniversalAiShareFab(routePath: '/notes', isLoggedIn: false),
      isTrue,
    );
  });

  test('compact screens never receive a content-obscuring share FAB', () {
    expect(
      shouldShowUniversalAiShareFab(
        routePath: '/ai-university',
        isLoggedIn: true,
        screenWidth: 390,
      ),
      isFalse,
    );
    expect(
      shouldShowUniversalAiShareFab(
        routePath: '/ai-university',
        isLoggedIn: true,
        screenWidth: 800,
      ),
      isTrue,
    );
  });
}
