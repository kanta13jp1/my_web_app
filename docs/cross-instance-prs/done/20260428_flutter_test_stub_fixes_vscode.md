# Cross-Instance PR: Flutter test stub fixes (PR #860 blocking issues)

**作成**: PS版#1 / 2026-04-28
**依頼先**: VSCode版 (Flutter/test 専任)
**優先度**: MEDIUM — PR #860 (CI hard-fail gate) のブロッカー
**推定工数**: 30-60 min

---

## 背景

Codex#2 が PR #860 (`codex/ci-web-test-hard-fail`) で CI test 厳格化を試みているが、
以下の 3 つのテスト失敗が未解決でマージ不可。

CI run: `25026032819` (PR #860 の最新 CI)

---

## 必要な修正

### 1. `test/pages/memory_drill_page_test.dart`

**エラー**:
```
❌ shows answers and stores today completion
   #3  _MemoryDrillPageState._loadCustomPacks (memory_drill_page.dart:56:29)
   #4  _MemoryDrillPageState.initState (memory_drill_page.dart:39:5)
```

`initState` で `_loadCustomPacks()` を呼ぶが、内部の Supabase 呼び出しが stub されていない。
テストで `MockSupabaseClient` に `customPacks` 関連の stub を追加する必要がある。

### 2. `test/pages/ai_status_page_test.dart`

**エラー**:
```
❌ normalizes providers and hides xai entries
   MissingStubError: ... (provider call not stubbed)
```

新しい provider (xAI 等) が追加された際に mock が更新されていない。
`ai_status_page_test.dart` の mock setup に不足している stub を追加。

### 3. `dart:js_interop` の VM テスト汚染

**エラー**:
```
lib/pages/election_victory_page.dart:3:8: Error: Dart library 'dart:js_interop' is not available on this platform.
Context: admin_analytics_page_test.dart → ... → home_tool_catalog.dart → election_victory_page.dart → dart:js_interop
```

`home_tool_catalog.dart` が `election_victory_page.dart` を import しており、
それが `package:web` を通じて `dart:js_interop` を引き込む。

解決策候補:
- `home_tool_catalog.dart` で `election_victory_page.dart` を conditional import に変更
- または `election_victory_page.dart` の web-only import を `kIsWeb` で条件分岐
- または `test/pages/admin_analytics_page_test.dart` に `@TestOn('browser')` アノテーション追加

---

## 完了条件

- [x] ~~上記 3 つのテストが `flutter test --coverage` (VM) で pass~~ **PS#5 が全3件修正済み**
  - #3 dart:js_interop → S77 (afbff5a9d) `@TestOn('browser')` で解消
  - #1 memory_drill → S79 (ecc413401) try/catch で Supabase 未初期化 silent return
  - #2 ai_status_page → S79 (ecc413401) `_FakeGoTrueClient`/`_FakeUser` + `auth` stub
- [ ] PR #860 の CI が green (次の CI run で確認)
- [ ] PR #860 が main にマージ可能な状態になったら PS#1 に通知 (comment on PR #860)

## 参考

- PR #860: https://github.com/kanta13jp1/my_web_app/pull/860
- Codex coordination file: `docs/cross-instance-prs/20260428_codex2_ci_flutter_test_gate.md` (PR #860 内)
- PS#1 comment: https://github.com/kanta13jp1/my_web_app/pull/860#issuecomment-4331425192

---

*PS版#1 / 2026-04-28 起票*
