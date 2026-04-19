---
from: 📱 スマホ版 (claude/mobile-version-task-2B9tz)
to: VSCode版 (or Windowsアプリ版)
date: 2026-04-19
priority: medium
status: pending
---

# UI Design Rollout Status を Supabase 化（DB 駆動に変更）

## 背景

実機 UAT で `https://my-web-app-b67f4.web.app/ui-design-status` を確認したところ、
ユーザーから **「この画面はいつ更新されるのか？」** という疑問が出た。

調査結果:

- 表示は完全に **Dart の const 配列ハードコード**:
  - `lib/data/design_compliance_data.dart` (1067 行, 157 画面)
  - `lib/data/ui_improvement_rollout_data.dart` (148 行, 7 画面の override)
- audit date の最新は **2026-04-05** で約 2 週間止まっている
- 自動更新の仕組みは無く、開発者が手で書き換え → commit → deploy しないと反映されない

「毎セッション UI 改善ツールチェーン実行」(CLAUDE.md Rule 12) と整合させるため、
**audit の結果を DB に書き、UI は DB から読む** 構造に変える。
これにより `/design-review` や `design-skills` サブエージェントの結果を
EF 経由で UPSERT するだけで UI 反映できる。

## ゴール

1. **Source of truth を Supabase に移す** — Dart const は seed 用に残し、UI は EF から fetch
2. **既存 UI の見た目・フィルタ動作は完全維持** — `_ScreenStatusCard` などの widget は変更しない
3. **EF 増やさない (Rule 7)** — `core-hub` に 3 action 追加して 50 本制約を維持
4. **後方互換** — fetch 失敗時はハードコードデータにフォールバック (オフライン耐性)

## 実装プラン

### Phase 1: Supabase スキーマ

**新規 migration**: `supabase/migrations/20260420000010_create_design_audit_tables.sql`

```sql
-- 画面マスタ + 直近 audit 結果 (1 行 = 1 画面)
CREATE TABLE IF NOT EXISTS design_screens (
  route          text PRIMARY KEY,
  name           text NOT NULL,
  category       text NOT NULL CHECK (category IN (
    'marketing','home','notes','ai','business','personal','creative','admin'
  )),
  compliance     boolean[],          -- length=7, NULL = 未審査
  audit_date     date,
  notes          text,
  mcp_tool_used  text[],             -- ['figma','aidesigner','designskills','designmd']
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- rollout 状態 (override 用 — design_screens の subset)
CREATE TABLE IF NOT EXISTS design_rollout (
  route          text PRIMARY KEY REFERENCES design_screens(route) ON DELETE CASCADE,
  stage          text NOT NULL CHECK (stage IN ('applied','in_progress','planned')),
  figma_mcp      text NOT NULL CHECK (figma_mcp IN ('applied','in_progress','planned')),
  ai_designer    text NOT NULL CHECK (ai_designer IN ('applied','in_progress','planned')),
  design_skills  text NOT NULL CHECK (design_skills IN ('applied','in_progress','planned')),
  design_md      text NOT NULL CHECK (design_md IN ('applied','in_progress','planned')),
  headline       text NOT NULL,
  next_step      text NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_design_screens_category ON design_screens(category);
CREATE INDEX IF NOT EXISTS idx_design_screens_audit_date ON design_screens(audit_date DESC);

ALTER TABLE design_screens ENABLE ROW LEVEL SECURITY;
ALTER TABLE design_rollout ENABLE ROW LEVEL SECURITY;

CREATE POLICY "design_screens read" ON design_screens FOR SELECT USING (true);
CREATE POLICY "design_rollout read" ON design_rollout FOR SELECT USING (true);
-- 書込みは service_role のみ (EF 経由で audit 結果 UPSERT)
```

### Phase 2: 初期 seed

**migration**: `supabase/migrations/20260420000011_seed_design_screens.sql`

`lib/data/design_compliance_data.dart` の 157 件を `INSERT ... ON CONFLICT DO NOTHING` で投入。

> ⚠️ **VSCode版が dart コードから自動生成すると安全**:
> ```bash
> dart run tool/generate_design_seed.dart > supabase/migrations/20260420000011_seed_design_screens.sql
> ```
> 生成スクリプトは別 PR でも可。手書きで 157 件は事故るので非推奨。

`lib/data/ui_improvement_rollout_data.dart` の 7 件 override も同 migration に追加。

### Phase 3: Edge Function (`core-hub` に 3 action 追加)

**ファイル**: `supabase/functions/core-hub/index.ts` に以下を追加 (既存 `case "notification.list":` の近くを参考に)

```ts
case "design.screens.list": {
  // 画面 + rollout を JOIN して 1 リクエストで取得
  const { data: screens, error: e1 } = await admin
    .from("design_screens")
    .select("route, name, category, compliance, audit_date, notes, mcp_tool_used");
  if (e1) return json({ error: e1.message }, 500);

  const { data: rollouts, error: e2 } = await admin
    .from("design_rollout")
    .select("*");
  if (e2) return json({ error: e2.message }, 500);

  return json({ screens: screens ?? [], rollouts: rollouts ?? [] });
}

case "design.audit.upsert": {
  // service_role 必須 (audit 結果書込み)
  const auth = req.headers.get("authorization") ?? "";
  if (auth.replace(/^Bearer\s+/i, "") !== SERVICE_ROLE_KEY) {
    return json({ error: "forbidden" }, 403);
  }
  const route = String(body.route ?? "");
  if (!route) return json({ error: "route required" }, 400);
  const compliance = Array.isArray(body.compliance) ? body.compliance : null;
  if (compliance && (compliance.length !== 7 || compliance.some((v) => typeof v !== "boolean"))) {
    return json({ error: "compliance must be boolean[7]" }, 400);
  }
  const { error } = await admin.from("design_screens").upsert({
    route,
    name: body.name,
    category: body.category,
    compliance,
    audit_date: body.audit_date ?? new Date().toISOString().slice(0, 10),
    notes: body.notes ?? null,
    mcp_tool_used: body.mcp_tool_used ?? null,
    updated_at: new Date().toISOString(),
  });
  if (error) return json({ error: error.message }, 500);
  return json({ success: true });
}

case "design.rollout.upsert": {
  const auth = req.headers.get("authorization") ?? "";
  if (auth.replace(/^Bearer\s+/i, "") !== SERVICE_ROLE_KEY) {
    return json({ error: "forbidden" }, 403);
  }
  const route = String(body.route ?? "");
  if (!route) return json({ error: "route required" }, 400);
  const valid = new Set(["applied", "in_progress", "planned"]);
  for (const k of ["stage", "figma_mcp", "ai_designer", "design_skills", "design_md"]) {
    if (!valid.has(String(body[k]))) return json({ error: `invalid ${k}` }, 400);
  }
  const { error } = await admin.from("design_rollout").upsert({
    route,
    stage: body.stage,
    figma_mcp: body.figma_mcp,
    ai_designer: body.ai_designer,
    design_skills: body.design_skills,
    design_md: body.design_md,
    headline: body.headline,
    next_step: body.next_step,
    updated_at: new Date().toISOString(),
  });
  if (error) return json({ error: error.message }, 500);
  return json({ success: true });
}
```

`deno lint` 0 エラー必須。

### Phase 4: Flutter UI を DB 駆動に変更

**新規**: `lib/services/design_audit_service.dart`

```dart
class DesignAuditService {
  static const String _endpoint =
      'https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/core-hub';

  Future<({List<PageComplianceRecord> screens, Map<String, UiImprovementRollout> rollouts})>
      fetchAll() async {
    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({'action': 'design.screens.list'}),
      );
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      // map JSON → PageComplianceRecord / UiImprovementRollout
      // ...
      return (screens: parsedScreens, rollouts: parsedRollouts);
    } catch (e) {
      // フォールバック: ハードコードデータ
      return (
        screens: kDesignComplianceData,
        rollouts: kUiImprovementRolloutOverrides,
      );
    }
  }
}
```

**修正**: `lib/pages/ui_design_status_page.dart`

- `_filteredRecords` getter を `late List<PageComplianceRecord> _records` に変更
- `initState` で `DesignAuditService().fetchAll()` を呼んで `setState`
- ローディング中は `CircularProgressIndicator` 表示
- 既存の widget tree (hero / summary grid / filter / card) は完全維持

### Phase 5: audit 自動化フック (任意・後続 PR)

`design-skills` サブエージェントが audit 完了時に `design.audit.upsert` を叩く workflow を追加すると
完全自動化できる。今回の PR では含めず、手動 UPSERT で動作確認するだけで OK。

## 完了条件

- [ ] migration 2 本作成 (`20260420000010_*` + `20260420000011_*`)
- [ ] `core-hub` に 3 action 追加 + `deno lint` 0 エラー
- [ ] `design_audit_service.dart` 新規作成
- [ ] `ui_design_status_page.dart` を DB 駆動に変更 (widget tree 維持)
- [ ] `flutter analyze` 0 エラー
- [ ] 本番 deploy 後 `https://my-web-app-b67f4.web.app/ui-design-status` で 157 画面が表示される
- [ ] 試しに `design.audit.upsert` で 1 画面の `audit_date` を更新 → リロードで反映を確認
- [ ] フォールバック動作確認 (ネットワーク断時もハードコードデータで表示される)

## 推定工数

- Phase 1+2 (migration): 30 分 (seed 生成スクリプト含む)
- Phase 3 (EF): 20 分
- Phase 4 (UI): 40 分
- 検証: 20 分
- **合計**: ~2 時間

## Philosophy alignment

- **原則 1 (CEO 感)**: 「いつ更新されるか」が透明 = ユーザーが状況を把握して意思決定できる
- **原則 6 (資本=時間)**: 開発者が手で 1067 行の Dart を編集する時間を削減
- **原則 8 (KPI = 昨日の自分)**: audit date の鮮度可視化により、改善ペースが自分の進捗として見える

整合性スコア: **3/9 ✅** (主目的は技術改善のため低めだが、間接的にユーザー体験を改善)

## 関連

- スマホ版 session で起票した #514 (バージョン表示) と思想は同じ — 「ユーザーに状態を見える化」
- CLAUDE.md Rule 12 (UI改善ツールチェーン) のループを閉じる
- 競合 `notion` の database view と同じ思想 — 構造化データ + 自動更新

---

**handoff by**: 📱 スマホ版 Claude (claude/mobile-version-task-2B9tz)
**user request**: 「この画面はいつ更新されるのでしょうか？」(2026-04-19 19:10)
