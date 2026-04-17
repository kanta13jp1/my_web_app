---
date: 2026-04-17
from: Windowsアプリ版#74
to: VSCode版, PowerShell版
status: done
priority: medium
---

# WBS 進捗反映通知 — 各インスタンスの担当タスク確認依頼

## 概要

ユーザーから **「α/β/v1 マイルストーン達成に向けて各インスタンスが開発作業を進める」** 要望。
既に PS版#107 で WBS + ガントチャート + マイルストーン実装済。
本 PR では Windows版#74 の進捗を反映 + 各インスタンスに担当タスク再確認を依頼。

## マイルストーン状況

| | α版 | β版 | 最終版 v1.0 |
|---|---|---|---|
| **目標日** | 2026-05-31 (44日後) | 2026-07-31 (105日後) | 2026-10-31 (197日後) |
| **ユーザー** | 50人 | 500人 | 5,000人 |
| **達成度目安** | α阻害タスク要完了 | 全AI統合+グロース | 競合21社対抗+収益化 |

## 各インスタンス 次回優先タスク (α版までの44日で完了必須)

### VSCode版

1. **DESIGN.md準拠 55%→60%達成** (α目標)
2. **FSRS学習システム 残り30%** (AI大学コア)
3. **flutter analyze 0エラー常時維持** (Rule 1)
4. **モバイルレスポンシブ完全対応**

### PowerShell版

1. **BYPASS_RULES secret 設定** (ユーザー対応待ち・ブロッカー)
2. **ai-hub provider.chat 残 56社対応** (Phase 4)
3. **Rule17 WF health weekly実施**
4. **ブログ自動投稿安定化 (Qiita 429 監視)**

### Windowsアプリ版

1. **AI大学 78社 quiz/fallback充実化** (コンテンツ深化)
2. **provider.chat 画像系3社 (Phase 3)** — Stability/Runware/Replicate
3. **毎セッション新規AIプロバイダー評価 (Step 0)**
4. **NotebookLM Master Brain活用強化**

### 全インスタンス

1. **ユーザー数 50人達成 (α) — 現在 8% = 4人** ← 最重要 KPI
2. **オンボーディング最適化 (現 10%)**
3. **competitor比較ページ最新化 (現 70%)**

## 参照

- **WBS ドキュメント**: `docs/WBS.md`
- **本番ガントチャート**: https://my-web-app-b67f4.web.app/project-gantt
- **DB**: `wbs_milestones` + `wbs_tasks` (migration 20260417180000 / 20260417190000 / 20260417200000)

## 完了条件

- [ ] 各インスタンスが自担当タスクを毎セッション1件以上進捗更新
- [ ] 毎セッション `/project-gantt` で進捗確認
- [ ] α版(5/31)までにα分類タスク全完了

各インスタンスは毎セッション wbs_tasks の progress UPDATE をコミットしてください。
