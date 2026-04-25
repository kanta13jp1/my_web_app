# Cross-Instance PR: User Tasks → NotebookLM 蓄積 + 分析

**作成**: PS版#2 S25 / 2026-04-25
**宛先**: PS版#3 (NotebookLM Deep Research 担当)
**優先度**: medium

## ユーザー要件

> ユーザータスクについてはNotebookLMに蓄積するようできますか？
> NotebookLM側でユーザータスクを分析して具体的な手順を明確化したいです。

## 実装方針

### Phase 1: GHA で user tasks を定期 export → NotebookLM source に追加

```yaml
# .github/workflows/wbs-user-tasks-notebooklm.yml
name: WBS User Tasks → NotebookLM
on:
  schedule:
    - cron: '0 1 * * 1'  # 毎週月曜 10:00 JST
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Fetch user tasks from Supabase
        run: |
          curl -s -X POST "$SUPABASE_URL/functions/v1/tools-hub" \
            -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
            -H "Content-Type: application/json" \
            -d '{"action":"wbs.notify_user_tasks","send_slack":false,"limit":50}' \
            | jq '.tasks' > /tmp/user_tasks.json
          # JSON → markdown 変換
          python3 << 'PYEOF'
          import json, datetime
          tasks = json.load(open("/tmp/user_tasks.json"))
          lines = [f"# WBS ユーザータスク一覧 ({datetime.date.today()})", ""]
          for t in tasks:
              due = t.get("end_date", "未設定")
              prog = t.get("progress", 0)
              lines.append(f"## [{t['category']}] {t['title']}")
              lines.append(f"- 期限: {due} / 進捗: {prog}% / 優先度: {t.get('priority')}")
              if t.get("description"):
                  lines.append(f"- 詳細: {t['description']}")
              lines.append("")
          open("/tmp/user_tasks.md", "w").write("\n".join(lines))
          PYEOF

      - name: Add to NotebookLM
        run: |
          pip install "notebooklm-py[browser]" -q
          notebooklm use jibun-master-brain
          notebooklm source add /tmp/user_tasks.md \
            --title "WBS User Tasks $(date +%Y-%m-%d)"
          notebooklm ask "今週のユーザー手動タスクの優先順位と具体的な実施手順を教えて"
```

### Phase 2: tools-hub に wbs.export_user_tasks_md action 追加

EF action: `wbs.export_user_tasks_md`
- user tasks を markdown 形式で返す
- GHA から curl で取得して NotebookLM へ

### 実装者: PS#3

PS#3 は notebooklm CLI の認証状態確認 + GHA workflow 作成を担当。

## 依存

- tools-hub:wbs.notify_user_tasks (既存・実装済み)
- SUPABASE_ANON_KEY (GHA secret)
- NOTEBOOKLM_SESSION (cookie または API token)
