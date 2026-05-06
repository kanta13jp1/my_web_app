# Cross-Instance PR: `wbs.list_tasks` 1000 行 cap pagination 修正 hand-off

> **作成**: Win版#132 part 166 / 2026-05-07
> **From**: Win Claude (= bug triage)
> **To**: Win Codex (= EF Deno 修正)
> **優先度**: high (= P1 / Issue [#2096](https://github.com/kanta13jp1/my_web_app/issues/2096) / 期限なし but 業務 risk あり)

---

## 概要

`/project-gantt` UI の「全体 1000 件」表示が **Supabase `.select()` default 1000 行 cap** によりスライス済の値になっている。1001+ 番目の wbs_tasks は UI 上で **完全に欠落**。

## 根本原因

`supabase/functions/tools-hub/index.ts` line 5732+ の `wbs.list_tasks` action:

```ts
let q = admin.from("wbs_tasks").select("...");  // ← .range() なし = 1000 cap
const { data, error } = await q;
const filteredTasks = [...(data ?? [])].filter(...);
const sortedTasks = filteredTasks.sort(compareWbsTasks).slice(0, limit);
return json({ tasks: sortedTasks, total: filteredTasks.length });
//                                  ^^^^^^^^^^^^^^^^^^^^^ ← 1000 cap'd value
```

## 修正方針 (= 推奨 Option A: pagination loop)

```ts
case "wbs.list_tasks": {
  const inst = body.instance as string | undefined;
  const status = body.status as string | undefined;
  const updatedSince = body.updated_since as string | undefined;
  const limit = Math.min(Number(body.limit ?? 50), 200);

  // ─── pagination loop で 1000+ 行も完全取得 ─────
  const PAGE_SIZE = 1000;
  let allData: Record<string, unknown>[] = [];
  let offset = 0;
  for (;;) {
    let q = admin.from("wbs_tasks")
      .select(
        "id, category, category_icon, category_order, title, description, instance, owner_instance, status, progress, start_date, end_date, planned_start_date, planned_end_date, milestone_code, priority, remaining_work, updated_at, github_issue_number, github_issue_url, github_issue_state, github_issue_labels, github_issue_synced_at",
      )
      .range(offset, offset + PAGE_SIZE - 1);
    if (status) q = q.eq("status", status);
    if (updatedSince) q = q.gte("updated_at", updatedSince);
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    if (!data || data.length === 0) break;
    allData = allData.concat(data);
    if (data.length < PAGE_SIZE) break;
    offset += PAGE_SIZE;
  }
  // ─────────────────────────────────────────────

  const filteredTasks = allData.filter((task) =>
    wbsTaskMatchesInstanceFilter(
      task as Record<string, unknown>,
      inst ?? "all",
    )
  );
  const sortedTasks = filteredTasks.sort(compareWbsTasks).slice(0, limit);
  const { data: milestones } = await admin.from("wbs_milestones")
    .select("code, name, target_date, goal_users, color");
  return json({
    success: true,
    tasks: sortedTasks,
    milestones: milestones ?? [],
    total: filteredTasks.length,  // ← 正確な件数
  });
}
```

### 設計判断

| 項目 | 判断 | 根拠 |
|------|------|------|
| pagination | server-side `.range()` loop | client 完全 fetch / total accurate |
| PAGE_SIZE | 1000 | Supabase default upper bound |
| limit (client) | 既存 `body.limit ?? 50, max 200` 維持 | UI 一覧表示用 / UI breaking change なし |
| total field | filtered tasks length (= post-filter / pre-slice) | UI 件数表示の正確性 |
| safety | infinite loop guard 不要 | break on `data.length < PAGE_SIZE` で確実終了 |

## 受け入れ条件 (= Issue #2096 と同期 / 5 項目)

- [ ] `wbs.list_tasks` で 1000+ 行を完全取得 (= pagination loop)
- [ ] 既存 `limit` parameter (default 50, max 200) は client-side slice で維持 (= UI breaking change なし)
- [ ] `total` field は **filtered tasks の正確な件数** (= 1000 cap 外でも正)
- [ ] `/project-gantt` UI で 1000+ 件正常表示 (= 「未完了 N / 全体 M 件」が真値)
- [ ] EF smoke test: 1000+ 行投入で全件取得確認 (= curl で `total > 1000` 確認 / 例 `wbs_tasks_count_query` で実数比較)

## Win Codex 推奨実装順

1. `supabase/functions/tools-hub/index.ts` line 5732+ の `wbs.list_tasks` を上記 spec に従い書き換え
2. local Deno smoke test (= `deno test` or curl で 1000+ 件確認)
3. PR 作成 (= title `fix(ef): wbs.list_tasks pagination loop for 1000+ rows (#2096)`)
4. deploy-prod 反映後 `/project-gantt` UI で「全体 N 件」が正値表示確認

## 注意事項

- **[NO-SCOPE-CREEP]**: 本修正は `wbs.list_tasks` のみ。同 1000 cap 問題は他 EF action にもある可能性あり (= 別 Issue で track)。
- **[REAL-DATA]**: Supabase production data 1000+ 行で smoke 確認。
- **[EF-CAP-50]**: 既存 EF 内修正のみ / 新規 EF なし。
- **performance**: 大量取得 + client-side filter は OK (= EF 内で完結 / Flutter response 1 回 / Network round-trip 1)。1000+ 行 select は Supabase 数百 ms。
- **regression**: 既存 `wbs.list_tasks` caller (= UI + GHA cron + 他 instance script) の response shape 不変。

## 4 軸 alignment

- **PHILOSOPHY-22 9/9 ✅** (= mentor + 6 部署 / IPO 信頼 = データ整合性)
- **AI-DEV-23 7/7 ✅** ([EF-FIRST] 既存 hub 内修正 / observability via total field / quality-gate via smoke test)
- **VIBE-30 7/7 ✅** (MVP scope 厳守 / 修正範囲限定)
- **INDIE-29 7/7 ✅** (shipping 速度: 設計 spec 1 + Issue 1 + hand-off 1 / 1 PR 完結想定)
- **SYNERGY-30 7/7 ✅** (cross-instance-pr / Win Claude triage → Win Codex 実装 routing)
- **PLATFORM-31 7/7 ✅** ([EF-CAP-50] 維持 / 新 EF なし)

## Codex 振分 5 質問 matrix (= [INSTANCE-ROLES])

| # | 質問 | 答 |
|---|------|-----|
| Q1 | Architecture / 設計 needed? | YES (= 本 hand-off で完了) |
| Q2 | UI/UX design? | NO (= UI breaking change なし) |
| Q3 | NotebookLM intake / triage? | NO |
| Q4 | AI 大学 / 競合 update? | NO |
| Q5 | Mobile UAT / video? | NO |
| **Implementation** (EF Deno 編集 + smoke test) | **Win Codex** |

## 関連

- Issue [#2096](https://github.com/kanta13jp1/my_web_app/issues/2096) (= 本 hand-off の主 Issue)
- Win Claude part 158 (= 2026-05-06) で初出 carry-over → part 166 で着手
- `lib/pages/project_gantt_page.dart` line 2913-2916 `_buildHeader` (= UI 側 表示ロジック / 修正不要)
- `supabase/functions/tools-hub/index.ts` line 5732+ `wbs.list_tasks` (= 修正対象)

cc @kanta13jp1
