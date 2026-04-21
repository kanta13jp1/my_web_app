# 自分株式会社 開発 WBS (Work Breakdown Structure)

> **最終更新**: 2026-04-21 Codex (Multimodal AI 引継ぎ)
> **参照**: サイト上の `/project-gantt` ページでリアルタイム確認可能  
> **DB**: `wbs_milestones` + `wbs_tasks` テーブル (migration 20260417180000 / 20260417190000 / 20260417200000)

## Codex 引き継ぎメモ (2026-04-21)

- Claude quota 制限中の一時対応として、**実際に着手済みのタスクのみ** `Codex` 担当に変更。
- Codex 担当対象:
  `DESIGN.md全ページ準拠 60%達成` / `モバイルレスポンシブ完全対応` /
  `競合比較ページ最新化` / `Webパフォーマンス最適化 (LCP < 2.5s)` /
  `BYPASS_RULES secret設定` / `オンボーディング最適化` / `紹介プログラム実装` /
  `E2Eテスト整備 (Playwright)` / `エラー監視強化 (Sentry連携)` /
  `画像生成統合` / `マルチモーダルAI`
- 過去の「未完了タスク全件を Codex に集約」方針は過剰なため、後続 migration で担当を各 lane owner に戻す。

## マイルストーン概要 (ユーザー可視)

| | α版 | β版 | 最終版 v1.0 |
|---|---|---|---|
| **目標日** | 2026-05-31 | 2026-07-31 | 2026-10-31 |
| **残日数** | 44日 | 105日 | 197日 |
| **ユーザー目標** | 50人 | 500人 | 5,000人 |

---

## リリースマイルストーン

| マイルストーン | 目標日 | ユーザー目標 | 概要 |
|---|---|---|---|
| **α版** | 2026-05-31 | 50人 | コア機能安定化・CI/CD完全自動化 |
| **β版** | 2026-07-31 | 500人 | 全AI統合・公開ベータ・グロース自動化完成 |
| **最終版 v1.0** | 2026-10-31 | 5,000人 | 競合21社全機能対抗・収益化開始 |

---

## WBS タスク一覧 (インスタンス別担当)

### ⚙️ カテゴリ1: インフラ・CI/CD — **PowerShell版 / Codex 一時引継ぎ**

| タスク | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|
| EFハードキャップ16本維持 | 🟡進行中 | 90% | α |
| deploy-prod 成功率100%維持 | 🟡進行中 | 80% | α |
| BYPASS_RULES secret設定 (Codex引継ぎ) | 🟡進行中 | 70% | α |
| cs-check最適化完了 | ✅完了 | 100% | α |
| orphan branch 0本維持 | ✅完了 | 100% | α |
| Rule17 WF health weekly実施 | 🟡進行中 | 70% | β |

### 🎨 カテゴリ2: デザインシステム — **GitHub Co-Pilot / Codex 一時引継ぎ**

| タスク | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|
| DESIGN.md全ページ準拠 60%達成 (Codex引継ぎ) | 🟡進行中 | 65% | α |
| モバイルレスポンシブ完全対応 (Codex引継ぎ) | 🟡進行中 | 70% | α |
| タイポグラフィ統一 | 🟡進行中 | 50% | β |
| DESIGN.md全ページ準拠 100%達成 | ⚪未着手 | 0% | v1 |

### 🎓 カテゴリ3: AI大学 — **Windows版 + VSCode版 担当**

| タスク | 担当 | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|---|
| 78社コンテンツ完全化 | Windows | 🟡進行中 | 85% | α |
| FSRS学習システム完全実装 | VSCode | 🟡進行中 | 90% | α |
| ストリーク・バッジ・ランキング | VSCode | ✅完了 | 100% | α |
| AIプロバイダー一覧・チャット機能 | PS | ✅完了 | 100% | α |
| AI大学 100社達成 | Windows | ⚪未着手 | 0% | β |
| 音声学習機能強化 | VSCode | 🟡進行中 | 40% | β |

### 💼 カテゴリ4: コアSaaS機能 — **VSCode版 / Codex 一時引継ぎ**

| タスク | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|
| ノート・メモ機能 (Notion対抗) | 🟡進行中 | 60% | β |
| タスク管理 (Asana対抗) | 🟡進行中 | 50% | β |
| 資産管理 (MoneyForward対抗) | 🟡進行中 | 45% | β |
| 競合比較ページ最新化 (Codex引継ぎ) | 🟡進行中 | 85% | α |
| 課金機能実装 (Stripe) | ⚪未着手 | 0% | v1 |

### 🤖 カテゴリ5: AI統合 — **PS版 + VSCode版 / Codex 一時引継ぎ**

| タスク | 担当 | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|---|
| ai-hub 502エラー根本修正 | PS | ✅完了 | 100% | α |
| ai-hub provider.chat 全対応 | PS+Win | 🟡進行中 | 20% | β | (13/78社実装 — Windows#74で OpenAI互換8+独自3+特殊2 追加)
| AIアシスタント Opus4.7/Sonnet4.6更新 | VSCode | 🟡進行中 | 80% | α |
| 画像生成統合 | Codex | 🟡進行中 | 35% | v1 |
| マルチモーダルAI | Codex | 🟡進行中 | 30% | v1 |

### 📈 カテゴリ6: グロース自動化 — **PS版 + Codex 担当**

| タスク | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|
| ブログ自動投稿安定化 (Qiita/dev.to) | 🟡進行中 | 75% | α |
| X自動投稿 daily-report連携 | 🟡進行中 | 60% | α |
| YouTube競合分析自動化 | 🟡進行中 | 70% | β |
| 競合21社モニタリング自動化 | 🟡進行中 | 50% | β |
| NotebookLM Master Brain完全活用 | 🟡進行中 | 70% | β |

### 👥 カテゴリ7: ユーザー獲得 — **全インスタンス / Codex 一時引継ぎ**

| タスク | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|
| LP最適化 (120のこと完全掲載) | 🟡進行中 | 70% | α |
| SEO改善 (sitemap・meta tags) | 🟡進行中 | 80% | α |
| オンボーディング最適化 (Codex引継ぎ) | 🟡進行中 | 35% | β |
| 紹介プログラム実装 (Codex引継ぎ) | 🟡進行中 | 25% | β |
| **ユーザー数50人達成 (α版目標)** | 🟡進行中 | 8% | α |
| **ユーザー数500人達成 (β版目標)** | ⚪未着手 | 0% | β |
| **ユーザー数5000人達成 (v1目標)** | ⚪未着手 | 0% | v1 |

### 🛡️ カテゴリ8: 品質・安定性 — **全インスタンス / Codex 一時引継ぎ**

| タスク | 担当 | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|---|
| flutter analyze 0エラー常時維持 | VSCode | 🟡進行中 | 85% | α |
| deno lint 0エラー維持 | PS | 🟡進行中 | 85% | α |
| Webパフォーマンス最適化 | Codex | 🟡進行中 | 40% | β |
| E2Eテスト整備 (Playwright) | Codex | 🟡進行中 | 20% | v1 |
| エラー監視強化 (Sentry連携) | Codex | 🟡進行中 | 25% | v1 |

---

## インスタンス別 優先タスク

### VSCode版 — 次回セッション優先タスク
1. DESIGN.md準拠 → 60%到達から残り主要ページへ展開
2. FSRS学習システム 残り30%
3. ノート機能強化 (Notion対抗)
4. モバイルレスポンシブ確認

### Windows版 — 次回セッション優先タスク
1. AI大学 78→85社コンテンツ追加
2. 毎セッション2社バッチ追加継続
3. docs Rule10全件チェック

### PowerShell版 — 次回セッション優先タスク
1. BYPASS_RULES secret設定 (Codex引継ぎ) — 進行中 (secret存在確認・安全ローテーション手順完了)
2. ai-hub provider.chat 残り60プロバイダー対応
3. Rule17 WF health check
4. T-1ブログ次弾 dispatch

---

## 進捗更新ルール

各セッション終了時に `wbs_tasks` テーブルの progress と status を更新すること:

```sql
-- 例: ai-hub provider.chat 進捗更新
UPDATE wbs_tasks SET progress = 30, status = 'in_progress'
WHERE title = 'ai-hub provider.chat 全対応';
```

または `/project-gantt` ページからUI更新 (管理者のみ)。

---

## 参照リンク

- **本番サイト**: https://my-web-app-b67f4.web.app/project-gantt
- **ROADMAP**: `docs/GROWTH_STRATEGY_ROADMAP.md`
- **DESIGN.md**: `docs/DESIGN.md`
- **COMPRESSED_PROMPT**: `.github/COMPRESSED_PROMPT_V3.md`

---

## 直近完了項目 (2026-04-17 Windows版#74)

- ✅ AI大学 77→78社 (SambaNova SN50 RDU 追加) — α達成度+1.3%
- ✅ AIプロバイダー実装ステータス一覧ページ (Phase 1)
- ✅ provider.chat 13社対応 (OpenAI互換8 + Mistral/Perplexity/Cohere + Anthropic/Gemini 特殊認証)
- ✅ ElevenLabs 課金制限 → Web Speech API 自動フォールバック
- ✅ ルーチン2スキル追加: `cross-instance-pr` / `session-start-check`
- ✅ ai-hub 502 transient incident report
- ✅ Rule 10 docs stale 数値修正 (56社目→79社目以降)
- ✅ Rule 11 モデル landscape 調査 (GPT-5.4/Gemini 3.1/Opus 4.7)
- ✅ Rule 14 ツールバージョン全最新確認

## 次セッション着手推奨 (α版 44日前)

**最優先 (α阻害)**:
1. PS版: BYPASS_RULES secret 設定 smoke test (Codexで存在確認・手順整備済み)
2. VSCode版: DESIGN.md準拠 60%→主要ページ横展開 (α目標)
3. Windows版: AI大学 78社 → quiz/fallback 充実化
4. 全インスタンス: ユーザー数 50人達成ドライブ (現在 8% = 4人)

**α版確実化タスク**:
- flutter analyze 0エラー常時維持 (現 85%)
- deploy-prod 成功率 100%維持
- オンボーディング最適化 (Codex引継ぎ・現 35%)
- 紹介プログラム実装 (Codex引継ぎ・現 25%)
- E2Eテスト整備 (Playwright) (Codex引継ぎ・現 20%)
- エラー監視強化 (Sentry連携) (Codex引継ぎ・現 25%)
- 画像生成統合 (Codex引継ぎ・現 35%)
- マルチモーダルAI (Codex引継ぎ・現 30%)
