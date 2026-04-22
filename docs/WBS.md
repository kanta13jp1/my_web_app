# 自分株式会社 開発 WBS (Work Breakdown Structure)

> **最終更新**: 2026-04-22 Codex (統一地方選 立憲比較/UX改善)
> **参照**: サイト上の `/project-gantt` ページでリアルタイム確認可能  
> **DB**: `wbs_milestones` + `wbs_tasks` テーブル (migration 20260417180000 / 20260417190000 / 20260417200000)

## Codex 引き継ぎメモ (2026-04-21)

- Claude quota 制限中の一時対応として、**実際に着手済みのタスクのみ** `Codex` 担当に変更。
- Codex 担当対象:
  `DESIGN.md全ページ準拠 60%達成` / `モバイルレスポンシブ完全対応` /
  `競合比較ページ最新化` / `Webパフォーマンス最適化 (LCP < 2.5s)` /
  `BYPASS_RULES secret設定` / `オンボーディング最適化` / `紹介プログラム実装` /
  `E2Eテスト整備 (Playwright)` / `エラー監視強化 (Sentry連携)` /
  `画像生成統合` / `マルチモーダルAI` / `AI大学 100社達成` / `SEO改善 (sitemap・meta tags)` /
  `タイポグラフィ統一 (line-height 1.7+)` / `FSRS学習システム完全実装`
- 過去の「未完了タスク全件を Codex に集約」方針は過剰なため、後続 migration で担当を各 lane owner に戻す。

## Codex 引き継ぎメモ (2026-04-22)

- 今回実際に着手したタスクのみ Codex 担当に維持:
  `DESIGN.md全ページ準拠 60%達成` / `モバイルレスポンシブ完全対応` / `統一地方選 AI自動KPI更新`
- 実装内容: `2027 統一地方選 700必達管理室` に全国KPIマップを追加し、モバイルは縦積み、デスクトップは地図+詳細パネルの横並びで表示。
- WBS DB 反映: migration `20260422083000_wbs_codex_election_kpi_map.sql` で owner_instance=Codex、進捗を DESIGN 66% / モバイル 71% に更新。
- 追加改善: 日本地図UIに海面背景、地域ラベル、選択中県連バッジ、重点度バーを追加。migration `20260422093000_wbs_codex_election_map_ui_polish.sql` で DESIGN 67% / モバイル 72% に更新。
- AI連携強化: `local-election-intelligence` の実態データをユーザー入力なしで県連KPIへ反映。現職人数、目標擁立数、予定選挙数、公認期限、AI自動更新メモを保存する。migration `20260422100000_wbs_codex_election_ai_auto_sync.sql` で AI統合進捗を記録。
- 入力UI撤去: 県連KPI編集、テンプレート再適用、月次表からのKPI編集、投稿本文編集導線を外し、AI自動更新専用の読み取り中心UIへ変更。migration `20260422103000_wbs_codex_election_readonly_ai_sync.sql` で反映。
- アコーディオンUI: 県連一覧を地域別、議員名簿を県別、公式ソースを折り畳み可能にし、閉じた状態でも主要KPIを集計チップで確認できるよう改善。migration `20260422110000_wbs_codex_election_accordion_ui.sql` で反映。
- 立憲比較/UX改善: `local-election-intelligence` が立憲民主党公式「自治体議員」情報から県別地方議員数を自動集計し、統一地方選700必達管理室にベンチマーク、県別カード、地図詳細として反映。migration `20260422113000_wbs_codex_election_cdp_benchmark.sql` で反映。

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
| DESIGN.md全ページ準拠 60%達成 (Codex引継ぎ) | 🟡進行中 | 69% | α |
| モバイルレスポンシブ完全対応 (Codex引継ぎ) | 🟡進行中 | 74% | α |
| タイポグラフィ統一 (Codex引継ぎ) | 🟡進行中 | 65% | β |
| DESIGN.md全ページ準拠 100%達成 | ⚪未着手 | 0% | v1 |

### 🎓 カテゴリ3: AI大学 — **Windows版 + VSCode版 / Codex 一時引継ぎ**

| タスク | 担当 | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|---|
| 78社コンテンツ完全化 | Windows | 🟡進行中 | 85% | α |
| FSRS学習システム完全実装 (Codex引継ぎ) | Codex | 🟡進行中 | 92% | α |
| ストリーク・バッジ・ランキング | VSCode | ✅完了 | 100% | α |
| AIプロバイダー一覧・チャット機能 | PS | ✅完了 | 100% | α |
| AI大学 100社達成 | Codex | 🟡進行中 | 12% | β |
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
| 統一地方選 AI自動KPI更新 | Codex | ✅完了 | 100% | α |
| 統一地方選 AI自動更新専用UI | Codex | ✅完了 | 100% | α |
| 統一地方選 アコーディオンUI改善 | Codex | ✅完了 | 100% | α |
| 統一地方選 立憲比較/UX改善 | Codex | ✅完了 | 100% | α |

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
| SEO改善 (sitemap・meta tags) (Codex引継ぎ) | 🟡進行中 | 85% | α |
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
2. FSRS学習システム 残り8% (Codex引継ぎ: 評価/次回復習ラベル修正・回帰テスト追加)
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

## 直近完了項目 (2026-04-22 Codex)

- ✅ 統一地方選700必達管理室に全国KPIマップを追加
- ✅ 地図タイル・詳細パネル・凡例をモバイル/デスクトップ両対応で実装
- ✅ 選挙チャートWidgetテストの文字化け期待値を修正し、KPIマップ回帰テストを追加
- ✅ 日本地図UIに海面背景・地域ラベル・選択中県連バッジ・重点度バーを追加
- ✅ 統一地方選AI連携を強化し、各県連の現職人数・目標擁立数・予定選挙数・公認期限を自動更新
- ✅ 手入力でKPIを変更できるUIを撤去し、キャッシュ済みAIデータも初期表示時に自動同期
- ✅ 県連一覧・議員名簿・公式ソースをアコーディオン化し、長いリストを畳めるUIへ改善
- ✅ 立憲民主党公式「自治体議員」情報の県別自動集計を追加し、ベンチマーク/県別カード/地図詳細へ反映

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
2. VSCode版/Codex: DESIGN.md準拠 68%→主要ページ横展開 (α目標)
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
