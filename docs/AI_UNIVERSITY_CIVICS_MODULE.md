# AI大学 公民モジュール (政治・選挙リテラシー学部) 設計

> **新設**: 2026-06-03 (Win Claude part 240e / L3 設計) — user 依頼「[kokkaimap.jp](https://kokkaimap.jp/) 相当機能の取り込み」
> **位置づけ**: 既存 [`AI_UNIVERSITY_FACULTY_DEPARTMENT_DESIGN.md`](AI_UNIVERSITY_FACULTY_DEPARTMENT_DESIGN.md) の学部/学科階層に **civics 学部**を追加する feature spec。実装=L2 Codex。

## 1. 背景と方針

kokkaimap.jp = 国会議員マップ (712 議員を地図可視化 + 発言/投票/政治資金 + AI要約[Claude Haiku] + 投票マッチング診断 / データ源 = 国会会議録検索システム + 衆参公式議員一覧)。

そのまま「政治可視化サービス」を足すと 自分株式会社の core mission (人生=会社経営) と別軸 + 政治コンテンツ固有のリスク (中立性 / 名誉毀損)。→ **AI大学の「学び」ミッションに接続** = `civics` 学部 (政治・選挙リテラシー) として **教育コンテンツ先行**で取り込む。

## 2. アーキテクチャ (既存資産に load / 新規 EF 不要)

AI大学はデータ駆動階層 (学部→学科→content)。**学部行を足すと UI が自動表示** (Flutter 変更不要で基本ドリルダウン成立):
- `university_faculties` に `civics` 1 行追加
- `university_departments` に 4 学科追加
- `ai_university_content` に教材 seed (`faculty_id`/`department_id` 紐付け)
- AI要約は既存 `ai-hub` EF `summarize.text` action 再利用 (EF 数 ~15 ≪ 50 / [EF-CAP-50] OK)

## 3. 段階プラン (リスクゲート付き)

| Phase | 内容 | リスク | 状態 |
|-------|------|--------|------|
| **1. 学部/学科** | civics 学部 + 4 学科 (国会の仕組み / 国会議員 / 政策テーマ / 選挙制度) migration | 低 | **本 spec の MVP** → Codex handoff |
| **2. 教育コンテンツ** | 各学科に教材 `ai_university_content` seed (出典付き・中立) | 低 | **本 spec の MVP** → Codex handoff |
| **3. UI 強化** | kokkaimap風 地図 + 「あなたの選挙区」(郵便番号) + AI要約表示 | 中 | 別 Issue / **要 GO** |
| **4. ライブデータ** | 国会会議録 API 同期 + 議員投票記録 + 検索 | 🔴 中立性/名誉毀損 | **要 中立性ポリシー策定** |

**v1 = 教材のみ** = 議員のスコアリング/レビューを持たない → 中立性・名誉毀損リスクを v1 で構造的に回避。

## 4. 中立性・倫理ガードレール ([AI-CHARACTER-24] / Phase 3-4 で必須)

- **政治的中立**: 全政党を等価に提示。推奨・序列付けをしない。投票マッチング診断 (Phase 3) は結果を誘導しない / 出典明示。
- **事実ベース + 出典必須**: 議員情報は公開公式データ (国会会議録 / 衆参公式一覧) のみ。私的データの名寄せ禁止。
- **AI要約の明示**: kokkaimap 同様「AI要約 (原文と差異の可能性)」ラベル + 原文リンク必須。編集的論評をしない。
- **名誉毀損回避**: 議員レビュー/評点機能は v1 で**持たない**。Phase 4 で導入する場合は法務確認 + 公式記録の引用のみ。
- **免責**: 「本モジュールは中立的な civic 教育目的。特定政党・候補者を支持しない」を UI に明記。

## 5. データ源 (Phase 4)

[国会会議録検索システム 検索用API](https://kokkai.ndl.go.jp/api.html) — 登録不要 / JSON・XML / 3 種 (会議単位簡易・会議単位・発言単位) / 100 件/req。
- **利用規約**: 利用者責任 (著作権等は利用者負担 / NDL 免責)。
- **制約**: 高頻度アクセス禁止 = **リクエスト間数秒待機** → EF 側で rate-limit + Supabase キャッシュ必須 (毎回 live 呼びしない)。同期は cron で日次バッチ。

## 6. MVP スコープ (本 spec で Codex へ)

Phase 1+2 のみ = migration 1 本 (civics 学部 + 4 学科 + 教育コンテンツ seed)。Flutter 変更なしで AI大学に「政治・選挙リテラシー学部」が出現しドリルダウン可能になる。SQL = [`cross-instance-prs/20260603_civics_module_mvp.md`](cross-instance-prs/20260603_civics_module_mvp.md)。

## 7. スコープ外 / follow-up ゲート

- Phase 3 (地図UI/郵便番号/AI要約表示) = 別 Issue + user GO 後。
- Phase 4 (国会会議録 live 同期 / 投票記録) = **中立性ポリシー策定 + 法務確認**が前提。unilateral 実装しない。
- 議員レビュー/評点は当面**非対応**。
