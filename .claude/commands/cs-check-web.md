# cs-check (WEB版) — Supabase/Firebase API 代替手順

WEB版 sandbox は外部HTTP (`*.supabase.co`, `*.web.app` 等) を全ブロックする (`host_not_allowed`)。
以下の代替手段を使う。

---

## ⚠️ コード修正の安全ルール (必須 / 2026-06-25 incident 由来)

cs-check 中の「バグ修正 / P0 修復」で `.dart` / `.ts` ソースを編集する場合は、以下を**必ず**守る。

### なぜこのルールがあるか
2026-06-25, cs-check が Issue #3644 の URL typo (`b6f7f4`→`b67f4`) を修正した際、
`lib/pages/subscription_billing_page.dart` の文字列補間 `${...}` を `\${...}` へ**過剰エスケープ**し、
`flutter build` を全 PR/本番で失敗させた (compile 不能化 / commit `805166663` → PR #3652 で復旧)。
原因 = この routine が教えるファイル書き込みは **unquoted heredoc** (`cat > file <<EOF`) で `$` がシェル展開されるため、
ソース編集時に展開を防ごうと `$`→`\$` を付け、`\$` がそのままファイルへ残った。

### ルール
1. **`$` を絶対にエスケープしない**。Dart/TS の文字列補間 `${expr}` / `$var` はソース通りそのまま書く。
2. ソース編集には **Edit ツール** を使う。`sed` / `create_or_update_file` で**全文を手書き上書きしない**。
   やむを得ず heredoc を使う場合は **必ず quoted heredoc** (`<<'EOF'`) を使い `$` 展開を無効化する
   (unquoted `<<EOF` は禁止)。
3. **検証ゲート (必須)**: 編集後・commit 前に、変更ファイルを analyzer へ通し 0 エラーを確認する。
   ```bash
   dart analyze lib/pages/subscription_billing_page.dart   # Dart (変更ファイルのみ / 全体は OOM)
   deno check supabase/functions/<fn>/index.ts             # TypeScript
   ```
   - エラーが残る場合は **commit しない**。
   - 補間崩れの早期検知: `grep -nF '\${' <変更ファイル>` が 1 件でもヒットしたら過剰エスケープ → 修正する。
4. **WEB版 sandbox は `flutter` / `dart` / `deno` を実行できない** ("flutter コマンド不可")。
   analyzer を回せない以上、**`.dart` / `.ts` ソースを main へ直接 commit してはならない**。
   代わりに **PR を作り ci.yml (Lint/Format/Test) にゲートさせる**:
   ```bash
   git switch -c fix/cs-<issue>
   # Edit でソース修正 (heredoc/sed で全文上書きしない)
   git commit -am "fix: <内容> (Issue #NNNN)"
   git push origin HEAD
   gh pr create --fill --base main
   ```
   docs (`docs/cs-notes/`, `docs/schedule-logs/` 等) のみの変更は従来通り main へ直接 commit 可。

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
