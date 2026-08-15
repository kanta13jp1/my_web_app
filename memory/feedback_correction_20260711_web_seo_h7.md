---
name: WEB版 2026-07-11 — web sandbox 制約 (AskUserQuestion/send_later 不通・Supabase 403・巨大 actions_list)
description: WEB版セッションでは AskUserQuestion/send_later(mcp) が permission stream 不通でテキスト fallback 必須。Supabase 直 curl と workflow_dispatch は 403 → 本番検証は日次 smoke cron 依存。mcp github actions_list は 100KB+ でトークン超過 → jq/python で file 抽出。squash 後 branch は origin/main から作り直し + force-with-lease。
type: feedback
---

# 失敗・訂正 / 環境制約 (WEB版 2026-07-11)

## 1. AskUserQuestion / send_later(mcp) がこの WEB版セッションで使えない
両ツールとも "Tool permission request failed / stream closed / requires approval" で不通。
→ **ユーザー確認は本文テキストで選択肢 (A/B/C・a/b/c) を提示し、記号回答してもらう** 方式が確実。

## 2. Supabase 直アクセス・workflow_dispatch は 403
- `curl https://<proj>.supabase.co/...` = CONNECT tunnel failed 403 (agent proxy)。
- `mcp__github__actions_run_trigger run_workflow` = 403 "Resource not accessible by integration"。
→ 本番 smoke 検証は**日次 smoke cron (public-memo-smoke.yml / 06:07 JST) に委ねる**。手動即時検証は不可と割り切る。

## 3. mcp__github__actions_list の出力が巨大でトークン超過
perPage 少数でも 100-400KB。`branch` / `workflow_id` filter が効かない (flaky) こともある。
→ persisted file を **python3/jq で必要フィールドのみ抽出**。conclusion が null (in_progress) の行は KeyError に注意 (`r.get('conclusion')`)。

## 4. squash merge 済 branch の follow-up は作り直す (merged-branch rule)
PR を squash merge した後、同名 branch に積み増すと merged 履歴と衝突。
→ `git fetch origin main && git checkout -B <branch> origin/main`(作業ツリー変更は保持) → commit →
`git push -u origin <branch> --force-with-lease`。本セッションで #3925/#3927/#3941 と 3 回実施。

**Why:** WEB版 (remote/web sandbox) は local Windows 版と権限・ネットワークが大きく異なり、
UI ツールや外部 API が沈黙で失敗する。前提を誤ると無駄なリトライやユーザー待ちが発生。
**How to apply:** WEB版セッション開始時から「AskUserQuestion/send_later は使わずテキスト確認」「Supabase 検証は cron 依存」「actions_list は file 抽出」「merge 後は branch 作り直し」を既定運用にする。
