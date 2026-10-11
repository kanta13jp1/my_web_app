---
date: 2026-10-11
from: Codex #1
to: Claude Code #1
status: pending
priority: medium
issue: null
wbs: null
---

# 哲学書の読書管理: 著者・著作目録と私的読書記録

## Delegation Packet

- WBS / Issue: 未割当。既存 Issue のタイトルと cross-instance 記録を検索し同一機能の項目は確認できなかった。WBS 割当は Claude Code #1。
- Due date: TBD / Claude Code #1。
- Current owner: Claude Code #1（設計レビュー）。
- Objective: 利用者の「すべての哲学書を読破する」を、拡張する著者・著作目録と版単位のページ数・理解度・感想で支える。
- Branch: codex/philosophy-reading-proposal-20261011。
- Worktree: remote-only。既存 checkout は別タスクの dirty 7 paths を保護。追加 worktree は作らない。
- Allowed write set: 本 PR は docs/features/philosophy-reading/ とこの handoff のみ。実装パケットの write set はレビュー後に Claude Code #1 が定義する。
- Prohibited write set: 未レビューのアプリ・DB・権限変更、他タスクの dirty paths、共有ルール、production データ。
- Required validation: 本 PR は CSV 13 件の ID 一意性、出典、書式、remote commit 内容の一致と変更パス確認。実装では Flutter、API、RLS/migration、旧レコード互換、再読・ページ集計を exact SHA の Actions と PR CI で検証。
- Expected output: 保存方式・権限・合本/分冊・初期公開範囲を確認した実装パケット。仕様案と著者候補は docs/features/philosophy-reading/ を参照。
- Risk triggers that must return to Claude Code: 共通目録の編集権限、スキーマ/RLS、旧データ統合、他利用者の記録へのアクセス、目録網羅性の誤表示。
- Memory/disk hygiene: intake で free disk 20.19 GiB / memory used 89.0%。CLOUD_REQUIRED。依存関係、ビルド、dev server、local child worker、worktree を作らない。
- Subagent plan: none。router 推奨 Astra/high は資源制約で worker に適用せず lead で調査。

## Result Contract

- Changed files: docs/features/philosophy-reading/proposal.md、docs/features/philosophy-reading/authors-seed.csv、この handoff。
- Validation result: CSV 13 件、必須列・ID 一意性・HTTPS SEP 出典・candidate 状態を検証。GitHub の commit tree と remote file 内容を確認する。
- PR / Issue links: この draft PR。Issue/WBS は未割当。
- Remaining risk: アプリ機能は未実装。著者候補は網羅的でなく、著作の帰属・活動世紀・地域タグは編集レビューが必要。既存 reading.mark_read の ownership と metadata 保持を最新 main で再確認してから安全に直す。
- Next owner: Claude Code #1。その後、レビュー済みパケットを Codex #1 が実装。
- Subagent evidence: 使用なし。

## 参照

- ../features/philosophy-reading/proposal.md
- ../features/philosophy-reading/authors-seed.csv
- ../AGENT_DELEGATION_PROTOCOL.md

## Intake の付記

ルール同期の verify は drift なし。NotebookLM CLI list は失敗したが、この作業は NotebookLM-driven ではないため intake gate は実施しない。AI tool watch の変化は既存 #1422/#1377/#1375/#1408（runtime）、#1337/#1350（hooks）、#1339/#1335/#1405（integration）、#1380/#1374/#1336/#1352（quality-cost）、#862/#1307/#1372（schedule）への既存ルートを確認し、新規 Issue を増やさない。この PR に当該ツール更新を混在させない。
