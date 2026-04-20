# 🚨 feedback_list_page still invokes dead EF `notify-feature-request` (PS#6 → PS#5)

**Date**: 2026-04-20 18:00 JST
**From**: PS版#6 (instance-ps6) — S15 live-dead EF audit
**To**: PS版#5 (on-call bug fix 専任)
**Priority**: 🔴 HIGH (admin feedback resolution 通知が 404 で壊れてる可能性)

## Summary

`lib/pages/admin/feedback_list_page.dart:79,84` が
`supabase.functions.invoke('notify-feature-request', ...)` で旧 EF 名を
呼んでいるが、`notify-feature-request` は deploy-prod.yml:358 のコメント
通り **core-hub に migrate 済**。deploy-prod は `notify-feature-request` を
deploy しないため、実 Supabase には存在せず、invoke は 404 を返す。

## 実証

```bash
$ grep -n "notify-feature-request" lib/pages/admin/feedback_list_page.dart
79:              'notify-feature-request',
84:              'notify-feature-request',

$ grep -c "supabase functions deploy notify-feature-request" .github/workflows/deploy-prod.yml
0

$ grep -n "notify-feature-request" .github/workflows/deploy-prod.yml | head -3
190:            notify-feature-request        # ← DEAD_LIST entry
358:          #   feature-request-manager, user-feedback-collector, notify-feature-request,
                                                                   # ↑ core-hub Merges コメント
```

`feedback-issue-resolved.yml:126` も同 EF を curl で呼ぶ → これも 404 の可能性。

## 影響

- admin が feedback を「対応完了」に更新 → `notify-feature-request` invoke
  → 404 → 通知メール飛ばず
- ユーザーは自分の feedback が対応されたことを知らない → UX 低下
- GitHub Issue close → `feedback-issue-resolved.yml` 起動 → 404 → メール漏れ

## Fix 案

### (A) Flutter + GHA を core-hub 呼出に更新

`feedback_list_page.dart` を:
```dart
await supabase.functions.invoke(
  'core-hub',
  body: { 'action': 'notify.feature_request', ...payload },
  ...
);
```
`feedback-issue-resolved.yml:126` も同様に:
```yaml
curl -X POST "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/core-hub" \
  -H "Content-Type: application/json" \
  -d '{"action":"notify.feature_request",...}' \
  ...
```

(core-hub 側の action 名は `supabase/functions/core-hub/index.ts` で
`notify-feature-request` 相当を探して合わせる必要あり)

### (B) notify-feature-request source を復活 + deploy 復帰

もし core-hub action として migrate されていない場合は、source
`supabase/functions/notify-feature-request/index.ts` を復活させて
deploy list に追加。ただし deploy-prod.yml のコメントは既に
core-hub 側 merge 済と表示しているため、基本的に (A) が正解のはず。

## PS#6 から見た手掛かり

`supabase/functions/notify-feature-request/index.ts` は **まだ残存**
(PS#6 S15 では削除候補に入れていない — flutter invoke 2 件あるため)。
core-hub の action 名を決めるときに参照可能。

## 関連

S15 の同バッチで source 削除したのは以下 10 EF (notify-feature-request は除外):
- admin-notification-hub / data-export-manager / gemini-election-analysis /
  landing-ab-test / growth-acquisition (d5b1e3f2)
- daily-judgment / development-achievements / ai-university-content /
  ai-university-streaks / ai-university-badges (本 session)

## Philosophy alignment

- 原則 5 (商品=ユーザー価値): 通知漏れはユーザー体験の直接的損失
- 原則 7 (資産=bug free baseline): stale invoke ← 負債

## PS#6 対応範囲外

PS#6 は horse_racing / cleanup 専任。Flutter 修正 + EF ルーティング変更は
PS#5 (on-call) に委任。
