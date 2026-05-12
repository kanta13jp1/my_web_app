# 🚨 User 作業依頼: BYPASS_RULES PAT 失効疑い — blog-publish Step 5 が GH006 で連続失敗

- **発行日**: 2026-04-20
- **発行元**: PS版#1 Session 21 (Rule17 WF health)
- **宛先**: ユーザー (kanta13jp1 ご本人のみ)
- **重要度**: 🟠 (chronic debt — 記事公開自体は Step 4 で成功、frontmatter 更新のみ失敗)

## 症状

最新の blog-publish run (24665960140 / 937366a sha) の Step 5 "Mark draft as published" で:

```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: [remote rejected] HEAD -> main (protected branch hook declined)
```

schedule trigger の分岐 (`github.event_name == 'schedule'`) では branch protection ruleset
を bypass して main に直接 push する設計 (`secrets.BYPASS_RULES` PAT を
`x-access-token:${BYPASS_TOKEN}@github.com/...` で使用)。その PAT が bypass できていない。

## 仮説

1. **BYPASS_RULES PAT の期限切れ** (最可能) — 再発行が必要
2. **ruleset bypass list から当該 PAT を除外した変更** — GitHub 設定変更があれば復旧
3. **PAT の scope 不足** (`contents:write` + `workflows:write` 必要か)

## 現在の暫定対処 (PS#1 S21 実施済)

`.github/workflows/blog-publish.yml` の Step 5 に `continue-on-error: true` を追加
(commit: 後段参照)。WF 全体は green を維持するが、**frontmatter の `published: true` 更新は
反映されない** = 同一 draft が次回 schedule で選ばれる可能性あり。

auto_select の orphan 検知 (`blog-publish/<run_id>-*` branch 実在チェック) で 2 重投稿は
回避できるが、根本解決ではない。

## ユーザー依頼アクション

### 選択肢 A (推奨): BYPASS_RULES PAT 再発行

1. github.com → Settings → Developer settings → Personal access tokens (classic)
2. 既存 `BYPASS_RULES` を確認 (expired ならここで判明)
3. 新規発行 scope = `repo` (full) + `workflow`
4. Repository `kanta13jp1/my_web_app` → Settings → Secrets and variables → Actions
   → `BYPASS_RULES` を更新
5. Repository → Settings → Rules → (既存 ruleset) → Bypass list に PAT owner 追加確認

### 選択肢 B (代替): PR ベースに統一

schedule 分岐の直 push を廃止して手動分岐と同じ branch push + auto-merge に統一。
`GH_PAT_BLOG_MERGE` secret 設定済なら auto-merge、未設定なら手動マージ待ちの warn-only。

PS#1 の scope 外 (workflow 構造変更 + review 必要) なので、option A が最短。

## 関連 run

- 24665960140 (2026-04-20 21:14 JST / sha 937366a)
- Protection status: https://github.com/kanta13jp1/my_web_app/settings/rules

## S21 で実施済 commit

- blog-publish Step 5 に `continue-on-error: true` 追加 (次段 push)
