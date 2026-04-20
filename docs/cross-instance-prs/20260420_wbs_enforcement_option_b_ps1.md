# PS版#1 宛: Option B — wrap-up skill で wbs.update_progress 強制

- **起票元**: PS版#2 S17 (2026-04-20)
- **優先度**: MEDIUM (Option A Win / Option C cron と合わせて 3 層 enforcement の最終層)
- **起票理由**: ユーザー「wrap-up 時に wbs.update_progress 未実行ならエラー」要望。

## Context

- 現状: `.claude/commands/wrap-up.md:131` に以下記述:

  > **全インスタンス必須**: 本セッションで進めた WBS タスクを `tools-hub:wbs.update_progress` で更新する。

  → テキスト指示のみ。未実行でも skill は完走する (blocking なし)。
- ユーザー要望の enforcement:

  > Option B: wrap-up skill 内で wbs.update_progress 必須化 + 未実行ならエラー

## PS版#1 着手タスク

### 実装: wrap-up skill に Step 5.5 追加

`.claude/commands/wrap-up.md` (既存 Step 5 の後) に:

````markdown
### Step 5.5: WBS 更新確認 (必須・blocking)

セッション中に `tools-hub:wbs.update_progress` を 1 回以上呼んだか確認:

```bash
# 当セッションの tool call ログから grep (claude-mem sqlite or session log)
# 簡易実装: session_id 絞りなしで過去 1h の呼出を確認
UPDATED_COUNT=$(curl -s -X POST "$SUPABASE_URL_PROD/functions/v1/tools-hub" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY_PROD" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"wbs.list_tasks\",\"instance\":\"<instance>\",\"updated_since\":\"$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)\"}" \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('tasks',[])))")

if [ "$UPDATED_COUNT" = "0" ]; then
  echo "❌ ERROR: [WBS-SYNC] 違反 — 本セッションで wbs.update_progress 未実行"
  echo "   → wrap-up を continue する前に以下いずれかを実施:"
  echo "     (a) 進行中タスクに progress 数値更新"
  echo "     (b) 新規タスクを wbs.add_task で追加"
  echo "     (c) 本セッションで touch すべき WBS タスクなしを明示宣言 (memory に記録)"
  exit 1
fi
```

※上記は `updated_since` option を `wbs.list_tasks` に追加する前提 (現 EF は未対応)。
先に `tools-hub/index.ts:690` の `wbs.list_tasks` に `updated_since` filter 追加 → deploy → skill 有効化。
````

### EF 拡張 (先行)

`supabase/functions/tools-hub/index.ts:690` の `wbs.list_tasks` case:

```typescript
case "wbs.list_tasks": {
  // ... 既存 ...
  const updatedSince = body.updated_since;
  let q = admin.from("wbs_tasks").select("*");
  if (body.instance) q = q.eq("instance", body.instance);
  if (updatedSince) q = q.gte("updated_at", updatedSince);
  // ...
}
```

### 効果

- Option A = session-start 自動注入で知ることを保証
- Option B = session-end 更新を保証
- Option C = 24h cron で漏れ検知

→ 3 層 defense-in-depth で WBS 陳腐化を原理的に防止。

## 関連

- wrap-up: `.claude/commands/wrap-up.md`
- EF: `supabase/functions/tools-hub/index.ts:690`
- Option A 連携: `docs/cross-instance-prs/20260420_wbs_enforcement_option_a_win.md`
- Option C (稼働中): `.github/workflows/wbs-staleness-audit.yml`

## SLA

- 48h 以内着手 (INSTANCE-ROLES Rule)。EF 先行 deploy → wrap-up skill 更新の順。


---

## 🚨 PREREQ FIX (PS#6 S22 2026-04-20 commit 232b2783)

本 handoff 着手の前に **tools-hub の wbs.* dispatch bug が修復された** ことを確認:

- **Bug**: `supabase/functions/tools-hub/index.ts` line 335 で wbs.* 全 9 actions が horseracing switch 内に誤ネスト → `startsWith("horseracing.")` false で unreachable → 401 Unauthorized silent fail (2 週間潜伏)
- **Fix**: line 335 の条件を `|| action.startsWith("wbs.")` で拡張 (commit 232b2783 main)
- **確認 curl**:
  ```bash
  curl -X POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub \
    -H "Authorization: Bearer <ANON_KEY>" -H "Content-Type: application/json" \
    -d "{\"action\":\"wbs.priority_for_instance\",\"instance\":\"ps6\"}"
  ```
  期待値: `{"success":true,"instance":"ps6","top_tasks":[...]}`

deploy-prod 反映まで最大 11 min × 並行数。反映確認後に本 handoff 作業着手可。

