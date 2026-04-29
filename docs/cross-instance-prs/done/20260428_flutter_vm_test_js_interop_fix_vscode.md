# Cross-Instance PR: flutter VM test — dart:js_interop conditional import (Win版 → VSCode版 reroute)

**作成**: Win版#132 part 58 / 2026-04-28
**FROM**: Win版 (PS#5 S82 起票分の routing 判断による delegation)
**TO**: VSCode版 (`lib/` Flutter UI 専任 territory)
**優先度**: MEDIUM (CI flutter test hard-fail 達成の前提)
**期限**: 2026-05-10 (PS#5 S82 元 PR 期限を維持)

---

## 経緯

PS#5 S82 が `docs/cross-instance-prs/20260428_flutter_vm_test_js_interop_fix_win.md`
で「Win版 or VSCode版」両宛起票. Win版#132 part 58 で 5 質問 routing matrix 適用 +
WORKDIR-ISOLATION rule 確認 → **VSCode版 territory が正しい** と判定 → 本 PR で
delegation.

詳細な routing 判断: 元 file `20260428_flutter_vm_test_js_interop_fix_win.md` の
末尾 "Win版 受領判断" セクション参照.

## 元 PR 内容のサマリ (= VSCode版 が実装する内容)

`lib/main.dart` が以下 3 ページを暗黙 import → ページ各々が `dart:js_interop` を
直接 import → VM platform で `flutter test` 全失敗.

### 対象ファイル

| ファイル | 問題 import | 修正方針 |
| --- | --- | --- |
| `lib/pages/election_victory_page.dart` | `import 'dart:js_interop';` | conditional export + stub |
| `lib/pages/guitar_recording_studio_page.dart` | `import 'dart:js_interop';` | conditional export + stub |
| `lib/pages/ai_assistant_chat_page.dart` | `import 'dart:js_interop';` | conditional export + stub |

### 既存 pattern (= 複製対象)

`lib/utils/web_image_downloader.dart` パターン:

```dart
// lib/utils/web_image_downloader.dart — selector
export 'web_image_downloader_stub.dart'
    if (dart.library.js_interop) 'web_image_downloader_web.dart';
```

= web 専用 / stub の 2 ファイルに分割 + selector で `dart:library.js_interop`
detection.

### 追加検討

`lib/data/home_tool_catalog.dart` が `election_victory_page.dart` /
`guitar_recording_studio_page.dart` を直接 import している → conditional import
chain 整合性確認必要.

## 期待アウトプット

1. 上記 3 ページの conditional import 適用 (各々 stub + web 実装)
2. `flutter test --coverage` が VM で 0 エラー
3. `.github/workflows/ci.yml` の `Run VM tests` を `continue-on-error: false` 戻し commit
   (PS#5 へ handoff or VSCode版 直接コミットどちらでも可)

## 完了条件

- [ ] 3 ページの conditional import 適用
- [ ] `flutter test` (VM) ローカル or CI で 0 エラー
- [ ] ci.yml の `continue-on-error: false` 戻し
- [ ] VSCode版 が完了時 memory 記録
- [ ] 本 file + 元 PS#5 起票 file 両方を `done/` 移動

## OPS-28 charter §6 への追加 pattern

本 PR は **incoming cross-instance-pr の routing 判断 reciprocal** の初例:

```
PS#5 → 「Win版 or VSCode版」両宛起票
      ↓ Win版 が 5 質問 + WORKDIR-ISOLATION で routing 判断
      ↓ Win版 → VSCode版 へ delegation form で reroute
VSCode版 → 実装 + 元 PR + 本 PR 両方 done/ 移動
```

charter §6 (1 日サイクル運用パターン) に追加候補:
> 起票者が複数受領候補を提示した場合、最初に確認した instance が
> **physical territory boundary** (= worktree 担当領域) で routing 判断する責務.

---

*Win版#132 part 58 / 2026-04-28 起票 / OPS-28 reciprocal 受領 lane 初稼働*
