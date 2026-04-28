# Cross-Instance PR: AIシェアモーダル Uncaught Error 修復

**作成**: Win版#132 part 62 / 2026-04-28
**FROM**: Win版 (production bug 一次受領)
**TO**: VSCode版 (`lib/widgets/` Flutter UI 専任 territory)
**優先度**: HIGH (production console で永続的 Uncaught Error / UX 影響)
**期限**: 2026-05-05
**関連 Issue**: #911

---

## Win版 routing 判断 (5 質問 + WORKDIR-ISOLATION)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | **YES** | async lifecycle の error path 設計 (try/catch / mounted check / initState pattern) |
| Q2 cross-instance 調整? | NO | VSCode版 受領 単方向 |
| Q3 軸 docs 更新? | NO |
| Q4 docs に残す判断? | NO | 標準 Flutter pattern |
| Q5 NotebookLM 連携? | NO |

→ Q1 YES + WORKDIR-ISOLATION の `lib/widgets/*` = VSCode版 territory → **VSCode版 reroute** が確定.

## 症状

production https://my-web-app-b67f4.web.app/gemini-university で右下「AIシェア」モーダル
を開くと console に **Uncaught Error** が大量発生 (User screenshot 添付済 / Issue #911).

### Stack trace (main.dart.js minified)

```
main.dart.js:4251 Uncaught Error
    at Object.aW (main.dart.js:4251:30)
    at az9.gN (main.dart.js:120218:18)
    at az9.gnf (main.dart.js:120219:18)
    at iw.ge5 (main.dart.js:137319:48)
    at Object.e8i (main.dart.js:30196:5)
    at Object.dAq (main.dart.js:30160:5)
    at brw.akP (main.dart.js:137777:11)
    at brw.aF5 (main.dart.js:137781:22)
    at ahT.aUA (main.dart.js:152508:45)
    at a7Q.aSS (main.dart.js:134451:52)
```

### 解読

- `Object.aW` (4251) = Dart runtime helper (= Future.error / async helper)
- `brw.aF5` = stream subscription error handler 系の minify pattern
- `ahT.aUA` = state machine
- `a7Q.aSS` = top-level event handler

→ **state 中で await した Future の error が catch されていない** 可能性が最有力仮説.

### 同時発火事象

screenshot console:
- `Awarded 50 points. Reason: AI大学クイズ正解: Cartesia AI` ← AI大学クイズ正解処理 並行発火
- `Fetch finished loading: DELETE "...guest_presence?session_id=eq.2fa73b60..."` ← guest_presence
  DELETE 重複 (= unmounted 後の DELETE 可能性)

= モーダル open + クイズ正解 reward + guest_presence cleanup の **3 事象 race condition** で
unhandled async error が発火している可能性.

## 推定箇所

### A) `lib/widgets/universal_ai_share_shell.dart` (571 行)

- `_generateImage` / `_generateVideo` は try/catch で safe.
- `initState` 系の `_buildInitialDraft` (or 同等) の async path で unhandled の可能性.
- `mounted` チェックが不足している箇所がある可能性 (state 破棄後 setState で error).

### B) `lib/services/universal_x_share_service.dart`

- `_invoke` 内の `Supabase.instance.client.functions.invoke(...)` が throw → 上位 catch なし.
- `generateDraft` 系で AI 応答 parse failure が unhandled.

### C) AI 大学クイズ正解処理の同時発火

- 別 widget が同時に reward 付与 → universal_ai_share_shell の context が unmount → race.
- 該当 widget は `lib/pages/gemini_university_v2_page.dart`.

## 期待する修正

### 必須

1. `lib/widgets/universal_ai_share_shell.dart` の **全 async lifecycle method を try/catch + mounted check** で守る.
   - `initState` から呼ぶ `_loadInitialDraft` (or 同等) も含む.
2. `lib/services/universal_x_share_service.dart` の **全 public Future** を `try { await client.functions.invoke(...) } catch (e) { ... }` でラップ.
3. unmount 後の DELETE / setState を防ぐため `dispose` で _disposed フラグ + 全 async path で `if (_disposed) return`.

### 推奨

- error 詳細を `_statusMessage` に表示 (User フィードバック向上).
- AI大学クイズ正解処理と AIシェアモーダルの interaction を `lib/pages/gemini_university_v2_page.dart`
  で確認 (= 同時発火しないよう modal open 中はクイズ無効化 など).

## 完了条件

- [ ] 上記 A/B/C の lifecycle 全部 try/catch + mounted/_disposed 化
- [ ] production /gemini-university でモーダル開いて console error が消えること
- [ ] dart format / flutter analyze 0 エラー
- [ ] git commit + push origin HEAD:main
- [ ] Issue #911 close
- [ ] 本 cross-instance-pr を `done/` 移動

## OPS-28 charter §6 reciprocal pattern

本 PR は **Win版 → VSCode版** 直接起票 (= part 58 の PS#5 → Win版 → VSCode版 reroute と異なる単純 chain). production bug 起点 = on-call routing で Win版 が一次受領 + VSCode版 territory に即 hand-off.

---

*Win版#132 part 62 / 2026-04-28 起票 / Issue #911 連携 / OPS-28 §6 受領 + delegation 第 2 例*
