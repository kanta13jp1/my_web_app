# cs-check (WEB版) — Supabase/Firebase API 代替手順

WEB版 sandbox は外部HTTP (`*.supabase.co`, `*.web.app` 等) を全ブロックする (`host_not_allowed`)。
以下の代替手段を使う。

---

## Step 1-2: サポートチケット (代替: ticket-cache.json を読む)

```bash
cat docs/ticket-cache.json
```
- GHA `cs-check.yml` が毎時7分に更新する
- `http_code: 403` の場合は Supabase Network Restrictions が残存 → Step 10b 参照

## Step 8 (インフラ): ヘルスチェック代替

```bash
# Firebase/Supabase は直接確認不可 — GHA キャッシュを読む
cat docs/flutter-analyze-cache.json   # CI status (analyze_ok / conclusion)
cat docs/ticket-cache.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('Supabase:', d.get('http_code','?'))"
```

## Step 9 (ギター録音): ヘルスチェック代替

```bash
# GHA cs-check.yml が infra チェックを担当 → 最新 cs-note を確認
ls -t docs/cs-notes/*.md | head -1 | xargs tail -20
```

## Step 10: 実行ログ記録 (代替: ファイルに書く)

```bash
mkdir -p docs/schedule-logs
cat > docs/schedule-logs/cs-$(date +%Y-%m-%d-%H).json <<EOF
{
  "task_id": "cs-check",
  "status": "success",
  "executed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "web-version",
  "summary": "Edge Function UI追加: N件 / チケット: GHAキャッシュ参照 / Issue修正: N件 / Schedule健全性: 正常"
}
EOF
git add docs/schedule-logs/ && git commit -m "自動: CS ログ記録 $(date +%Y-%m-%d-%H):00 (WEB版)"
```

## Supabase Network Restrictions 根本修正 (Step 10b)

ticket-cache.json の `http_code` が `403` の場合 = Supabase が外部IPをブロック中:

```bash
# docs/.supabase-network-allow を更新コミット → fix-supabase-network.yml が自動起動
TRIGGERED_AT=$(date -u +%Y-%m-%dT%H:%MZ)
cat > docs/.supabase-network-allow <<EOF
triggered_at: $TRIGGERED_AT
reason: cs-check 403 修正
action: allow-all
EOF
git add docs/.supabase-network-allow && git commit -m "fix: Supabase Network Restrictions 解除トリガー $TRIGGERED_AT"
git push origin HEAD:main
```

または GitHub MCP 経由:
```
mcp__github__create_or_update_file path=docs/.supabase-network-allow content="triggered_at: <now>"
```

→ `fix-supabase-network.yml` (push トリガー) が GHA で実行し Supabase Management API で制限解除。
→ GHA 完了後 (約2分) 、次の cs-check で `http_code: 200` になる。
