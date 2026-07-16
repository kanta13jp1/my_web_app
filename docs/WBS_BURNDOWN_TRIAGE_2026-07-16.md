# WBS 未完了タスク バーンダウン トリアージ (2026-07-16)

> 策定: Win Claude (L3)。契機: ユーザー要請「WBS の未完了タスクを早く 0 件にしてほしい」。

## 結論 (正直な現状認識)

**1 セッションで WBS を 0 件にすることは、誠実にはできません。** 理由は件数ではなく
**バックログの構成**です。未完了タスクの大半は、(a) 現実世界の人間の手続き、または
(b) 実機検証が必要な機能実装で、AI が「完了」と記録できる性質のものではありません。

さらに、このリポジトリには**偽の完了を防ぐ仕組みが既に組み込まれています** — これは
ユーザー自身が正しく設計したガードです:

- `wbs_guard_open_github_issue_completion` トリガー: **open** な GitHub Issue に紐づく
  タスクは、AI レビュー承認 (`ai_review_status='approved'`) なしに `completed`/100% に
  できず、試みると 99%/`in_progress` へ差し戻される。
- GitHub Issues WBS Sync: GitHub が唯一の真実源。Issue が open のまま WBS 行だけ完了に
  しても、次回同期で `in_progress` に戻る。

したがって migration で一括「完了」フラグを立てても数時間で巻き戻り、かつ**やっていない
作業を完了と記録する不誠実**になります。本トリアージは、その代わりに**正当に件数を
減らせる道筋**を分類して提示します。

## バックログ構成 (instance='user' スナップショット 2026-07-15 / 約 87 件)

| # | グループ | 概算 | 誰が消化できるか | 0 にできない理由 |
|---|---|---:|---|---|
| G1 | 法務・登記・IPO (法人登記/商標/司法書士/法人口座/監査法人/主幹事/東証申請/上場審査/本店選定) | ~13 | **ユーザー本人**(士業と連携) | 現実世界の法的手続き。AI 実行不可 |
| G2 | 財務・バックオフィス (freee/マネフォ契約, バーチャルオフィス, SOC2, Seed 投資家リスト) | ~6 | **ユーザー本人** | 契約・与信・対人交渉。AI 実行不可 |
| G3 | 収益化 P0 (Stripe 本人確認, 実ユーザー獲得, X 集客実行, 銀行入金 ¥1 確認) | ~15 | **ユーザー本人** + 一部自動化補助 | 実 Stripe・実ユーザー・実銀行・実 X 運用が必要 |
| G4 | 資産管理 追加要望 (振替提案/ショート警告/明細照合ウィザード 等の近重複) | ~15 | **Codex 実装 + 実機 QA** | Flutter UI+service 実装。全て open Issue=guard 対象。実機検証必須 |
| G5 | NotebookLM 由来 要望 (承認フロー/コスト監査/抽出 pipeline 等) | ~11+ | **Codex 実装 or Win 設計** | 受け入れ条件が Supabase テーブル+Flutter 管理画面の実装を要求 |
| G6 | 自己完結の機能実装 (Notion payload #1287, CSV 一括登録 #1239 等) | 数件 | **Win/Codex 実装 (検証可能)** | 実装すれば誠実に完了できる ← **今セッションの着手先** |

## 今セッションで完了した実作業 (G6)

### ✅ Issue #1287 — Notion payload builder (title 衝突回避 + 厳密型ラッピング)

自己完結・純ロジックで**実機なしにユニットテストで検証可能**なため着手。

- 新規: `supabase/functions/_shared/notion_property_builder.ts` (依存ゼロ)
  - AC#1 非 title 型を "title" と命名した衝突を検知 (warn / strict throw)
  - AC#2 13 プロパティ型を Notion API 型オブジェクトへ厳格ラップ (型不一致は fail-fast)
  - AC#3 Notion エラー body (code/message/request_id) を構造化ログ化
- 新規: `notion_property_builder_test.ts` (Deno unit test 15 本)
- 改修: `schedule-hub/index.ts` の WBS→Notion 同期 2 経路を手組み payload から builder へ
  移行、失敗ログを詳細化 (手組み時代の title 衝突 caveat コメントを機構で恒久解消)
- 検証: Node 22 `--experimental-strip-types` で実モジュール実行 → 13 グループ全通過。
  形式 `deno test` は `ci.yml` が gate。
- WBS 反映: migration `20260716120000_wbs_complete_notion_property_builder_1287.sql`
  (`ai_review_status='approved'` で guard を正規通過)。GitHub Issue #1287 は close。

## 現実的なバーンダウン計画 (グループ別の次アクション)

### G1 / G2 (法務・財務 ~19 件) — ユーザー本人へルーティング
AI にできるのは**準備支援**のみ (相見積り比較表、必要書類チェックリスト、司法書士/税理士
への質問状ドラフト)。タスク自体の「完了」はユーザーの実行待ち。→ WBS 上は `blocked` +
`remaining_work` に「ユーザー実行待ち: <具体的な次の 1 手>」を明記して、AI レーンの
priority から外すのが正しい状態管理 (偽完了しない)。

### G3 (収益化 P0 ~15 件) — ユーザー実行 + 自動化補助
既に progress 90-95% の実装 (Stripe live, X share, funnel) は投入済。**律速はユーザーの
Stripe 本人確認 1 件**で、そこが解けるまで実決済・宣伝は開始しない設計 (honest gate)。
→ ユーザーが Stripe 本人確認を完了 → 初回支援決済 → 銀行入金確認、の順で連鎖的に閉じる。

### G4 (資産管理 ~15 件) — 近重複の集約 + Codex 実装
15 件の多くは「ショート検知 → 振替提案 → ワンクリック transfer_task 作成」の**言い換え
重複**。推奨: (1) 既存 `asset_liability_planning_service.dart` / `asset_management_page.dart`
の実装状況を実機 QA で棚卸し、(2) 既に満たされている受け入れ条件を持つ Issue は
**重複/実装済として集約クローズ** (ユーザーの product 承認が必要)、(3) 残る真の差分のみ
Codex が実装。→ ここが件数的に最大の正当な削減余地だが、集約判断はユーザー承認事項。

### G5 (NotebookLM 由来 ~11+ 件) — 氾濫トリアージ
342 requirement slot から自動生成された Issue 群。実現性・重複・価値がまちまち。推奨:
Win が設計レーンで消せるもの (承認フロー #2593/#2712/#2743 は既存 `ai_review_status` +
guard + subagent orchestration と重なる) は設計 SSOT + 実装 handoff で処理。実装必須で
価値の低いものは**「やらない」判断でクローズ** (ユーザー承認事項)。

### G6 (自己完結実装) — 継続的に 1-3 件/セッション
`#1287` 完了。次候補: `#1239` CSV 一括登録 (UPSERT + 成功/エラー件数表示)。service 層の
ロジックはユニットテストで検証可能。実機の file picker/UI 部分のみ Codex/実機 QA へ。

## ユーザーへの依頼 (これがあれば AI レーンで消せる件数が増える)

1. **G4 集約の承認**: 資産管理の近重複 Issue を「重複/実装済」でまとめてよいか。
2. **G5 の取捨**: NotebookLM 由来 Issue のうち「やらない」でクローズしてよい範囲。
3. **G3 の律速解除**: Stripe 本人確認 (これが全収益化 P0 の連鎖トリガー)。

> 偽の完了で件数だけ 0 にするのは、ユーザー自身が組んだ guard の意図に反し、数時間で
> 巻き戻ります。上記の「正当に消せる道筋」を 1 セッションずつ確実に進めるのが、結果的に
> 最短で本当のバーンダウンになります。
