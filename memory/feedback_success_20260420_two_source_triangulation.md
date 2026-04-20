---
name: 報道の数字は 2 社交差検証必須 (three-point triangulation)
description: 競合 delta 検出で「90+ plugins」等の具体数字を含む情報は、公式サイト + 独立報道 2 社の三点測定で確認。二次情報単独を根拠に SCOREBOARD / PR / SNS 弾に埋め込むと訂正コストが発生。
type: feedback
---

# 報道の数字は 2 社交差検証必須

競合 delta 検出で具体数字 (plugin 数 / ARR / valuation / 機能数 / ユーザー数) を根拠にする場合、**公式 site + 独立報道 2 社**の三点測定で確認する。

## Why

PS版#4 S21 で「OpenAI Codex 90+ plugins」を TechCrunch + smartscope blog (後者は前者の引用) の 2 ソースで SCOREBOARD + S21 PR + S23 PR に埋め込んだ。S24 で再調査したところ:

- OpenAI 公式 (`openai.com/index/codex-for-almost-everything/`) は「plugins available」とだけ書き**具体数字なし**
- TechNewStack / community.openai.com は「**20+ plugins at launch, self-serve publish not yet available**」と明示
- → 90+ は誤情報 (TechCrunch 原文または後続報道の誤記/誤読の可能性)

S23 SNS 弾を PS#2 が 4/23+ で dispatch する前に訂正できたため公開 SNS に誤情報を出さず済んだが、**訂正コスト** (SCOREBOARD + 2 PR + SNS 弾 framing 差し替え) は発生した。

## How to apply

- 数字を含む delta 検出時は即 `site:openai.com` / `site:anthropic.com` / `site:notion.com` など公式検索で具体数字が載っているか確認
- 公式に数字なし → **独立報道 2 社**で同じ数字が出ているか確認 (同じ source を引用しているだけ = NG)
- 三点で一致 → SCOREBOARD/PR に埋め込み可
- 三点で不一致 → 最も低い数字 (控えめ) を採用 or 数字を省略
- 煽り narrative (「X 一強崩壊」「Y が追いついた」) は数字が固まる前に使用禁止
- 既に埋め込んだ後で訂正発見 → SCOREBOARD + 関連 PR の **末尾に訂正 block 追記** (本文改変は git history で辿れなくなる)

## 対応 skill / template

- 将来的に「competitor-delta-verify」skill 化を検討 (3 site へ自動 WebSearch → 数字一致率を返す)
- 暫定: PS#4 の delta scan で数字含む情報は `confidence=low/medium/high` ラベル併記 (low → PR 埋め込み保留)
