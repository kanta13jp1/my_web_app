---
title: "Supabase Edge Functions を50本以下に抑える — hub パターンとその実践"
tags: supabase,AI,個人開発,postgresql
published: false
---

# Supabase Edge Functions を50本以下に抑える — hub パターンとその実践

Supabase の Edge Functions には暗黙の制約があります: **デプロイ可能な EF 数の上限**。私のプロジェクトでは `[EF-CAP-50]` ルールとして明示化し、50本以下を絶対制約にしています。

この制約の中で機能を増やすための解法が「**hub パターン**」です。

## 問題: EF が際限なく増える

初期フェーズでは素直に1機能=1 EF で実装しました:

```
check-competitor-updates
get-competitor-features
update-competitor-pricing
check-competitor-availability
competitor-monitoring-run
...
```

気づいたときには competitor 系だけで7本。20機能を追加すれば20本消費する。これは持続不可能です。

## hub パターン: N機能を1 EF で処理

```typescript
// supabase/functions/admin-hub/index.ts
serve(async (req) => {
  const { action, params } = await req.json();

  switch (action) {
    case 'competitor.check':    return competitorCheck(params);
    case 'competitor.pricing':  return competitorPricing(params);
    case 'competitor.features': return competitorFeatures(params);
    case 'wbs.priority_for_instance': return wbsPriority(params);
    case 'wbs.update_progress': return wbsUpdateProgress(params);
    default:
      return new Response('Unknown action', { status: 400 });
  }
});
```

1つの `admin-hub` EF が複数の action を処理する。EF を追加せずに機能を追加できます。

## 現在の hub 構成

| Hub EF | 担当 actions |
|---|---|
| `admin-hub` | competitor.check / pricing / features / wbs.* |
| `schedule-hub` | digest.run / daily.report / cs.check |
| `ai-hub` | judgment.get / horse.predict / writing.assist |
| `tools-hub` | wbs.priority_for_instance / wbs.update_progress / notify.* |

4本の hub が ~35 の action を処理。個別 EF 化していたら35本消費していたところを、**4本で済んでいます**。

## action の追加フロー

```bash
# 新機能追加手順
# 1. 既存 hub の switch に case を追加
# 2. handler 関数を実装
# 3. EF 数は変わらない

# NG: 新 EF を追加する (EF カウント +1)
supabase functions new my-new-feature  # ← これはしない

# OK: 既存 hub に action を追加 (EF カウント +0)
# admin-hub/index.ts の switch に case 追加
```

## 型安全な action 定義

```typescript
// _shared/action-types.ts
type AdminHubAction =
  | 'competitor.check'
  | 'competitor.pricing'
  | 'competitor.features'
  | 'wbs.priority_for_instance'
  | 'wbs.update_progress';

type AdminHubRequest = {
  action: AdminHubAction;
  params: Record<string, unknown>;
};
```

TypeScript の union type で action 名をコンパイル時に検証。誤字によるバグを防ぎます。

## EF-CAP-50 ルールの実装

```yaml
# .github/workflows/ef-audit.yml
- name: Count Edge Functions
  run: |
    EF_COUNT=$(ls supabase/functions/ | grep -v '_shared' | wc -l)
    echo "EF count: $EF_COUNT"
    if [ "$EF_COUNT" -gt 50 ]; then
      gh issue create \
        --title "EF-CAP-50 violated: $EF_COUNT functions" \
        --body "Add to existing hub instead of creating new EF"
      exit 1
    fi
```

CI で EF 数を監視。50本を超えた PR は自動的に Issue が上がる設計です。

## deny-by-default: 新 action の追加ルール

hub パターンの重要な原則: **新 action はデフォルトで拒否**。

```typescript
// admin-hub/index.ts
const ALLOWED_ACTIONS = new Set([
  'competitor.check',
  'competitor.pricing',
  // ...明示的に許可したもののみ
]);

if (!ALLOWED_ACTIONS.has(action)) {
  return new Response(
    JSON.stringify({ error: 'Action not permitted' }),
    { status: 403 }
  );
}
```

想定外の action が実行されないようにする。MCP セキュリティ原則の最小権限と同じ思想です。

## 実際の EF カウント推移

| フェーズ | EF 数 | 備考 |
|---|---|---|
| 初期 (個別 EF) | 23本 | 1機能=1 EF |
| hub 移行後 | 15本 | competitor系7本→admin-hub 1本 |
| 現在 | **18本** | 追加機能を hub action で吸収 |

機能数は 23 → 50+ に増えましたが、EF 数は 23 → 18 に**減っています**。

## まとめ

EF-CAP-50 は単なる制約ではなく、「設計が正しいかどうかの指標」です。EF が増え始めたら、それは機能が hub に収まっていないサインです。

hub パターンの核心: **EF はドメイン境界、action は機能境界**。ドメインは増やさず、機能を action として hub に積み上げる。これが Supabase Edge Functions を長期的に管理可能に保つ設計です。
