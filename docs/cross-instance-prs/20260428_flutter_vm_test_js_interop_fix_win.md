# Cross-Instance PR: flutter VM test — dart:js_interop conditional import リファクタリング

**作成**: PS版#5 S82 / 2026-04-28
**FROM**: PS版#5
**TO**: Win版 (conditional import リファクタリング) or VSCode版 (Flutter/Dart専任)
**優先度**: MEDIUM (CI の flutter test hard-fail を達成するための前提)
**期限**: 2026-05-10

---

## 背景

PS#5 S81 で PR #860 (codex/ci-web-test-hard-fail) の ci.yml を main に直接適用した。
`flutter test` を `continue-on-error: false` (hard-fail) にしようとしたが、以下の理由で断念:

### Root Cause

`flutter test $VM_TEST_FILES` 実行時に Flutter binding セットアップが `lib/main.dart` を
暗黙的にコンパイルする。`lib/main.dart` は以下のブラウザ専用ページを import している:

- `lib/pages/election_victory_page.dart` → `import 'dart:js_interop';`
- `lib/pages/guitar_recording_studio_page.dart` → `import 'dart:js_interop';`
- `lib/pages/ai_assistant_chat_page.dart` → `import 'dart:js_interop';`

VM プラットフォームで `dart:js_interop` のコンパイルが失敗するため、`flutter test` が
全体的に失敗する。

### 現状 workaround (PS#5 S82)

- VM tests: `flutter test --coverage` + `continue-on-error: true` (soft-fail 維持)
- Web smoke tests: `flutter test --platform chrome test/web_import_smoke_test.dart` + `continue-on-error: false` (hard-fail)

### 本質的な fix: conditional imports

以下のパターン (既存 `web_image_downloader.dart` で実証済み) を適用:

```dart
// lib/utils/web_image_downloader.dart — 正しいパターン
export 'web_image_downloader_stub.dart'
    if (dart.library.js_interop) 'web_image_downloader_web.dart';
```

**対象ファイル**:

| ファイル | 問題 import | 修正方針 |
| --- | --- | --- |
| `lib/pages/election_victory_page.dart` | `import 'dart:js_interop';` | conditional export + stub |
| `lib/pages/guitar_recording_studio_page.dart` | `import 'dart:js_interop';` | conditional export + stub |
| `lib/pages/ai_assistant_chat_page.dart` | `import 'dart:js_interop';` | conditional export + stub |

**追加検討**: `lib/data/home_tool_catalog.dart` が election_victory/guitar_recording を
直接 import しているため、conditional import チェーン全体の整合確認が必要。

## 期待アウトプット

1. 上記 3 ページに conditional import を適用 (stub + web 実装に分割)
2. `flutter test --coverage` が VM で 0 エラーになること
3. ci.yml の `Run VM tests` を `continue-on-error: false` に戻す commit

## 完了条件

- [ ] 3 ページの conditional import 適用
- [ ] `flutter test` (VM) がパスすること (ローカル確認 or CI)
- [ ] ci.yml の `continue-on-error: false` 変更 (PS#5 へ handoff か直接コミット)
- [ ] 実装インスタンスが memory に記録

## 参考: 既存 conditional import pattern

```bash
# lib/utils/ の既存パターンを参照:
ls lib/utils/*_web.dart lib/utils/*_stub.dart
# → web_image_downloader_web.dart + web_image_downloader_stub.dart + web_image_downloader.dart (export selector)
```

---

*PS#5 S82 / 2026-04-28 起票*

---

## Win版 受領判断 (2026-04-28 / Win版#132 part 58)

### 5 質問 routing matrix 適用 (docs/CODEX_WORKFLOW.md §6)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | △ 部分 YES | conditional import pattern は judgment 含むが既存 `web_image_downloader.dart` の複製のみ = 軽量 |
| Q2 cross-instance 調整? | NO | PS#5 → 受領 単方向 |
| Q3 軸 docs 更新? | NO | mechanical refactor / 6 設計軸不変 |
| Q4 docs に残す判断? | NO | 標準 conditional import 適用 |
| Q5 NotebookLM 連携? | NO |

→ 5 質問では Q1 軽量 YES で Codex も可だが、`lib/pages/*.dart` 編集 =
**WORKDIR-ISOLATION rule で VSCode版 専任 territory**.
→ **VSCode版 reroute** が正しい (= PS#5 表記「Win版 or VSCode版」のうち後者採用).

### Routing 根拠
- WORKDIR-ISOLATION rule: 「VSCode版 → `lib/` Flutter UI + EF」(CLAUDE.md / inject-rules.txt)
- Win版 territory: `docs/` / migration schema / 動画パイプライン
- 緊急 hotfix 例外不該当 (期限 2026-05-10 = 翌々週 / production 機能影響なし)

### Action

新 cross-instance-pr `20260428_flutter_vm_test_js_interop_fix_vscode.md` を
Win版 が delegation form で起票 → VSCode版 territory に正しく routing.

本 file は PS#5 起票の origin として保持。VSCode版 が実装完了時に done/ 移動.

### OPS-28 charter §6 への追加候補

**新 pattern**: incoming cross-instance-pr が複数受領候補 (例: 「Win版 or VSCode版」)
を提示した場合、最初に確認した instance が WORKDIR-ISOLATION 整合性で
**routing 判断する責務** を持つ. 単純な 5 質問判定だけでなく **physical territory
boundary** (= worktree 担当領域) も判断軸に加える.

*Win版#132 part 58 / 2026-04-28 routing 判断*
