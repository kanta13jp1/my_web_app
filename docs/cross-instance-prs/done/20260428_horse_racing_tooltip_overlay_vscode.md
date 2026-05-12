# Cross-Instance PR: /horse-racing で Tooltip Overlay 不在 → 修復

**作成**: Win版#132 part 63 / 2026-04-28
**FROM**: Win版 (production bug 一次受領)
**TO**: VSCode版 (`lib/widgets/` Flutter UI 専任 territory)
**優先度**: HIGH (production console 永続的エラー / part 48 fix の盲点)
**期限**: 2026-05-05
**関連 Issue**: #912
**前例**: Win版#132 part 48 (Issue #857 / commit 1a8e6623 = InkWell+Material wrap)

---

## Win版 routing 判断 (5 質問 + WORKDIR-ISOLATION)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | **YES** | Tooltip Overlay 解決 4 案 (Overlay ラップ / triggerMode manual / MaterialApp builder / 自前 popover) のうち判断必要 |
| Q2 cross-instance 調整? | NO | VSCode版 単方向 |
| Q3 軸 docs 更新? | NO |
| Q4 docs に残す判断? | △ | 解決方法による (= MaterialApp builder + Overlay 注入は複数 page 影響) |
| Q5 NotebookLM 連携? | NO |

→ **Q1+Q4 部分 YES + WORKDIR-ISOLATION lib/widgets** = VSCode版 territory 確定.

## 症状サマリ

`/horse-racing` でバージョンバッジマウスオーバー → **`No Overlay widget found.`**
が console に流出. Tooltip widget が Overlay ancestor を見つけられない.

User screenshot 添付済 (Issue #912).

### Stack trace key
- `Object.E` (4242) = assert helper
- `Object.edF` (31765) = `_debugCheckHasOverlay`
- `aNp.bBu/A` = TooltipState
- `rV.nt/qL/af8` = Tooltip widget / `ensureTooltipVisible`

= Flutter framework の **「Tooltip 表示時に祖先 Widget tree に Overlay が無い」** 既知挙動.

## 推定原因

`lib/widgets/global_header_clock_bar.dart` の version badge Tooltip:

```dart
Tooltip(
  message: AppVersion.isDev ? 'アプリバージョン (開発ビルド)' : 'アプリバージョン',
  child: Semantics(
    label: 'アプリバージョン $versionText',
    button: true,
    child: Material(
      color: Colors.transparent,
      ...
      child: InkWell(...),
    ),
  ),
)
```

= Tooltip → Semantics → Material → InkWell.
**Material は Overlay を提供しない**. /horse-racing route の build path で
GlobalHeaderClockBar が Overlay 不在 widget tree に組まれている.

実際 `lib/pages/horse_racing_predictor_page.dart` は Scaffold + AppBar + TabBar 持つが、
GlobalHeaderClockBar をどこで使っているか要確認 (User screenshot は home の経営コックピット
が映っているが URL は /horse-racing = navigation race の可能性).

## part 48 fix との関係

Win版#132 part 48 (commit 1a8e6623) で **同 file の InkWell を Material でラップ**:
- 旧 bug: InkWell が Material ancestor 不在 → `Null check operator used on a null value`
- 新 fix: Material(color: Colors.transparent) で InkWell をラップ

しかし **Tooltip は Material と独立** = Tooltip が Overlay 要求するのに対する fix は未着手.

= part 48 が **InkWell の ancestor 問題** だけ解消し、**Tooltip の Overlay 問題** が残存していた.

## 修正候補

### 案 A: Tooltip を Overlay でラップ (= self-contained)

```dart
Overlay(
  initialEntries: [
    OverlayEntry(builder: (_) => Tooltip(...)),
  ],
)
```
- メリット: scope 完結 / 他 page 影響なし
- デメリット: 既存 lifecycle 複雑化

### 案 B: Tooltip を自前 hover popover に置換 (= MouseRegion)

```dart
MouseRegion(
  onEnter: (_) => setState(() => _showTooltip = true),
  onExit: (_) => setState(() => _showTooltip = false),
  child: Stack(
    children: [
      <existing widget>,
      if (_showTooltip)
        Positioned(top: -28, child: Container(...child: Text(message))),
    ],
  ),
)
```
- メリット: Overlay 依存なし / Flutter 既知挙動完全回避
- デメリット: Tooltip の標準 a11y 失う (Semantics で代替可)

### 案 C: MaterialApp の `builder` で Overlay 強制注入

```dart
MaterialApp(
  builder: (context, child) => Overlay(
    initialEntries: [
      OverlayEntry(builder: (_) => child ?? const SizedBox.shrink()),
    ],
  ),
  ...
)
```
- メリット: 全 page で Tooltip 動作
- デメリット: lib/main.dart 変更 = 影響範囲大 / Navigator との相性検証必要

### 案 D (推奨): `triggerMode: TooltipTriggerMode.manual` + 既存維持

```dart
Tooltip(
  triggerMode: TooltipTriggerMode.manual,
  message: ...,
  child: ...,
)
```
- メリット: Tooltip Overlay 自動 trigger を抑制 / 既存 layout 維持
- デメリット: マウスオーバーで自動表示しない = UX 軽度低下

**VSCode版が判断**.

## 完了条件

- [ ] `lib/widgets/global_header_clock_bar.dart` の Tooltip 周辺修正
- [ ] /horse-racing で console error 消滅 (production verify)
- [ ] dart format / flutter analyze 0 エラー
- [ ] git commit + push origin HEAD:main
- [ ] Issue #912 close
- [ ] 本 cross-instance-pr を `done/` 移動

## OPS-28 charter §6 受領 lane 履歴 (本日 3 件目)

| part | from | to | 内容 |
| --- | --- | --- | --- |
| 58 | PS#5 → Win版 | VSCode版 | dart:js_interop conditional import |
| 62 | User → Win版 | VSCode版 | AIシェアモーダル Uncaught Error (Issue #911) |
| **63 (本)** | **User → Win版** | **VSCode版** | **/horse-racing Tooltip Overlay 不在 (Issue #912)** |

= Win版 が **on-call routing hub** として機能している実例 3 件目.

## 構造的観察 (= 改善トリガー候補)

part 48 と part 63 は **同 file global_header_clock_bar.dart の異なる ancestor 問題**.
今後 Tooltip / Material / Overlay などの **Flutter ancestor 要求 widget** を組み合わせる
場合は **routing pattern check** を CI で導入する価値あり (= cross-instance-pr 候補 / PS#1 lane).

具体例:
```python
# scripts/check_widget_ancestor_requirements.py (案)
# Tooltip が Material > Overlay の祖先順を持つか dart:analyzer で AST check
```

但し本提案は part 63 のスコープ外. VSCode版 完了後に別 cross-instance-pr で検討.

---

*Win版#132 part 63 / 2026-04-28 起票 / Issue #912 連携 / OPS-28 §6 受領 lane 第 3 例 / part 48 fix の盲点解消*
