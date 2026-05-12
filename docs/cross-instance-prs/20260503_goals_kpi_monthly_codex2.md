# Cross-Instance PR: goals.kpi_monthly EF action (#1827 最適化)

**作成**: VSCode版 S27 / 2026-05-03
**FROM**: VSCode版 (LifeGoalsKpiPage UI 完成 → server-side 集計最適化要求)
**TO**: Codex#2 (tools-hub EF)
**優先度**: P2 (クライアント側実装が動作するため non-blocking)
**期限**: 2026-05-10
**親軸**: #1827 LifeGoals 月次 KPI 台帳

---

## 1. 背景

VSCode版 S27 で `LifeGoalsKpiPage` UI 実装完了。
- `/life-goals-kpi` route 追加済み
- `LifeGoalsPage` AppBar → `/life-goals-kpi` リンク追加済み
- 現状: `life_goals` + `life_goal_reviews` テーブルをクライアント側で集計
- 課題: life_goals 数が増えると全件取得がボトルネックになる可能性

tools-hub EF に `goals.kpi_monthly` action を追加してサーバー側で集計することで負荷削減。

---

## 2. Codex#2 依頼: tools-hub EF に `goals.kpi_monthly` action 追加

`supabase/functions/tools-hub/index.ts` に追加:

### `goals.kpi_monthly` — 月次 KPI 集計

```typescript
case 'goals.kpi_monthly': {
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

  // life_goals (非 abandoned)
  const { data: goals } = await supabase
    .from('life_goals')
    .select('id, level, title, progress, target_date, status, category')
    .eq('user_id', userId)
    .neq('status', 'abandoned');

  // life_goal_reviews (今月)
  const { data: reviews } = await supabase
    .from('life_goal_reviews')
    .select('goal_id, progress_before, progress_after, created_at')
    .eq('user_id', userId)
    .gte('created_at', monthStart);

  const goalMap = new Map((goals ?? []).map((g: any) => [g.id, g]));

  // delta per goal (今月最初 progress_before → 最後 progress_after)
  const deltaMap = new Map<string, number>();
  for (const r of (reviews ?? []).sort((a: any, b: any) =>
    a.created_at.localeCompare(b.created_at)
  )) {
    const existing = deltaMap.get(r.goal_id);
    if (existing === undefined) {
      deltaMap.set(r.goal_id, (r.progress_after ?? 0) - (r.progress_before ?? 0));
    } else {
      // Keep first-to-last delta: update only the "after" part
      deltaMap.set(
        r.goal_id,
        Math.max(0, Math.min(100, (r.progress_after ?? 0) - (r.progress_before ?? 0)))
      );
    }
  }

  const goalsWithDelta = (goals ?? []).map((g: any) => ({
    ...g,
    delta_this_month: deltaMap.get(g.id) ?? 0,
  }));

  // 集計サマリ
  const allDeltas = goalsWithDelta.map((g: any) => g.delta_this_month);
  const overall_avg_delta =
    allDeltas.length > 0
      ? allDeltas.reduce((s: number, d: number) => s + d, 0) / allDeltas.length
      : 0;

  const smallGoals = goalsWithDelta.filter((g: any) => g.level === 'small');
  const achieved_small = smallGoals.filter(
    (g: any) => g.progress >= 100 || g.status === 'completed'
  ).length;

  return {
    goals: goalsWithDelta,
    summary: {
      overall_avg_delta,
      achieved_small,
      total_small: smallGoals.length,
      total_goals: goalsWithDelta.length,
    },
  };
}
```

---

## 3. 受入基準

- [ ] `tools-hub` に `goals.kpi_monthly` action 追加 — Codex#2
- [ ] `LifeGoalsKpiPage` の `_load()` 内 `Future.wait` を `goals.kpi_monthly` 単一呼び出しに差し替え (VSCode版 次 iteration)
- [ ] `flutter analyze` 0 issues (既存 Flutter 変更なし)
- [ ] CI green (deploy-prod)
- [ ] cross-instance-pr 完了時 `done/` 移動

## 4. 連携

- 前 phase: VSCode版 S27 (LifeGoalsKpiPage UI 完成 / `/life-goals-kpi` route)
- 後 phase: クライアント側集計 → EF 呼び出しに差し替え (VSCode版 S28 以降)
- 関連 Issue: #1827 (P1)

---

*VSCode版 S27 / 2026-05-03 起票 / goals.kpi_monthly EF / VSCode → Codex#2 lane*
