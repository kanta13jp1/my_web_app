# Asset Management WBS Plan

Last updated: 2026-08-29 JST

## Current WBS Snapshot

- This Codex session used a fresh worktree because the root tree was dirty.
- GitHub Issues WBS Sync succeeded through the latest Issue-triggered run after
  the NotebookLM batch. Manual run `26044482065` was cancelled by concurrency,
  but the last Issue-triggered run `26044490280` completed successfully.
- WBS Auto Reschedule was manually dispatched as run `26044670021` and
  completed successfully at `2026-05-19 00:56 JST`.
- The reschedule updated `880` open WBS tasks with `0` errors:
  `47` pinned tasks now run `2026-05-31 -> 2026-08-09`; GitHub Issue backlog
  then runs `2026-08-10 -> 2027-08-10`.
- #2448, #2449, #2450, #2451, #2452, #2453, #2456, #2508, #2521, and #2522 are
  already closed. The next open pinned asset-management implementation task is
  #2454.
- #2520 remains open only for live provider scoring and final scored verdict;
  the deterministic benchmark foundation and source recheck are already merged.
- NotebookLM requirement extraction now covers all `114` notebooks with `342`
  stable requirement slots linked to GitHub Issues.

The current WBS dates are the live `wbs.reschedule_realistic` output, not an
optimistic same-day backlog. Work should continue from the nearest due pinned
task unless Claude Code routes a product-judgment blocker first.

## Scheduling Rules

- One effort point is a small bounded change.
- Codex capacity is treated as 2 effort points per day.
- The two top-level lanes remain Claude Code #1 and Codex #1. Extra historical
  agent labels are dormant unless explicitly reactivated.
- Medium feature work is usually 2 effort points.
- Larger sync, import, or simulation work is 3 effort points.
- The asset-management roadmap is pinned first because this session explicitly
  prioritizes the asset/liability board.
- Existing Codex backlog resumes after the pinned asset-management window.
- NotebookLM issue extraction is an intake lane, not implementation capacity.
  Scheduled runs should keep the default creation cap of 9 new Issues per day;
  uncapped full backfills require explicit operator intent, dedup evidence, and
  a WBS reschedule immediately afterward.
- Two-instance routing is reflected in planning:
  - Claude Code owns ambiguous product judgment, architecture, prompt policy,
    and review-gate design.
  - Codex owns scoped implementation, SQL/migration review, CI, GitHub
    automation, deterministic checks, and merge follow-through.
- Every session must include memory/disk hygiene:
  - check free RAM and disk at start and wrap-up,
  - prefer fresh worktrees,
  - remove merged task worktrees and stale branches,
  - avoid full dependency/cache repair unless the task requires it.

## Current Goal

Use `/goal` as the durable execution frame when available. The local Codex CLI
is new enough for a pilot, but `codex --help` did not expose a non-interactive
goal command in this shell session, so this plan mirrors the same state through
GitHub Issue, WBS task, branch, PR body, and wrap-up prompt.

Goal statement:

```text
Keep the asset-management roadmap realistic, evaluate AI models with project
benchmarks instead of fixed social-media rankings, and continue implementation
from the nearest due WBS task.
```

## Asset Management Roadmap

Completed before this rebaseline: #2448-#2453, #2456, #2508, #2521, and #2522.
Current open pinned work starts here:

| Issue | Task | Estimate | Planned Start | Planned End |
|---:|---|---:|---|---|
| #2454 | Repayment simulation | 3d | 2026-05-31 | 2026-06-02 |
| #2455 | CSV import and restore | 2d | 2026-06-03 | 2026-06-04 |
| #2520 | Official AI model comparison benchmark foundation | 2d | 2026-06-06 | 2026-06-07 |

## Phase 2 Roadmap

| Issue | Task | Estimate | Planned Start | Planned End |
|---:|---|---:|---|---|
| #2460 | Monthly asset report DB schema | 1d | 2026-06-12 | 2026-06-12 |
| #2461 | EF monthly asset report with snapshot + LLM summary | 2d | 2026-06-13 | 2026-06-14 |
| #2462 | Month-end report cron | 1d | 2026-06-15 | 2026-06-15 |
| #2463 | Monthly report list/detail UI | 2d | 2026-06-16 | 2026-06-17 |
| #2464 | Monthly report integration test | 1d | 2026-06-18 | 2026-06-18 |
| #2465 | Investment assets DB schema | 1d | 2026-06-19 | 2026-06-19 |
| #2466 | Market price fetch/cache EF | 2d | 2026-06-20 | 2026-06-21 |
| #2467 | Investment asset Repository/Service | 1d | 2026-06-22 | 2026-06-22 |
| #2468 | Investment asset input/list UI | 2d | 2026-06-23 | 2026-06-24 |
| #2469 | Investment asset trend graph | 2d | 2026-06-25 | 2026-06-26 |
| #2470 | Investment CSV import | 2d | 2026-06-27 | 2026-06-28 |
| #2471 | Investment validation tests | 1d | 2026-06-29 | 2026-06-29 |
| #2472 | Monthly dashboard layout | 2d | 2026-06-30 | 2026-07-01 |
| #2473 | Net worth panel | 1d | 2026-07-02 | 2026-07-02 |
| #2474 | Cashflow panel | 1d | 2026-07-03 | 2026-07-03 |
| #2475 | Alert panel | 1d | 2026-07-04 | 2026-07-04 |
| #2476 | Anomaly detection DB | 1d | 2026-07-05 | 2026-07-05 |
| #2477 | EF anomaly detection | 2d | 2026-07-06 | 2026-07-07 |
| #2478 | Daily anomaly scan cron | 1d | 2026-07-08 | 2026-07-08 |
| #2479 | Anomaly review UI | 2d | 2026-07-09 | 2026-07-10 |
| #2480 | Department KPI link DB | 1d | 2026-07-11 | 2026-07-11 |
| #2481 | EF department finance summary | 2d | 2026-07-12 | 2026-07-13 |
| #2482 | Finance department asset summary panel | 1d | 2026-07-14 | 2026-07-14 |
| #2483 | Department-linked E2E test | 1d | 2026-07-15 | 2026-07-15 |
| #2484 | AI asset chat DB | 1d | 2026-07-16 | 2026-07-16 |
| #2485 | EF asset chat | 2d | 2026-07-17 | 2026-07-18 |
| #2486 | Sticky chat widget | 2d | 2026-07-19 | 2026-07-20 |
| #2487 | Chat history page | 1d | 2026-07-21 | 2026-07-21 |
| #2488 | PII guardrail | 1d | 2026-07-22 | 2026-07-22 |
| #2489 | Tax DB | 1d | 2026-07-23 | 2026-07-23 |
| #2490 | Furusato tax calculator | 1d | 2026-07-24 | 2026-07-24 |
| #2491 | Medical deduction tracking UI | 1d | 2026-07-25 | 2026-07-25 |
| #2492 | Tax export | 2d | 2026-07-26 | 2026-07-27 |
| #2493 | Invoice skeleton | 1d | 2026-07-28 | 2026-07-28 |
| #2496 | MoneyForward DB schema | 1d | 2026-07-29 | 2026-07-29 |
| #2497 | EF MoneyForward sync | 2d | 2026-07-30 | 2026-07-31 |
| #2498 | MoneyForward daily cron | 1d | 2026-08-01 | 2026-08-01 |
| #2499 | MoneyForward connection UI | 1d | 2026-08-02 | 2026-08-02 |
| #2500 | MoneyForward transaction merge | 1d | 2026-08-03 | 2026-08-03 |
| #2501 | MUFG eSmart Securities DB schema | 1d | 2026-08-04 | 2026-08-04 |
| #2502 | EF MUFG eSmart Securities sync | 2d | 2026-08-05 | 2026-08-06 |
| #2503 | MUFG eSmart daily cron | 1d | 2026-08-07 | 2026-08-07 |
| #2504 | MUFG eSmart connection UI | 1d | 2026-08-08 | 2026-08-08 |
| #2505 | MUFG eSmart holdings merge | 1d | 2026-08-09 | 2026-08-09 |
| #2508 | Memory/disk hygiene KPI dashboard | 2d | 2026-08-10 | 2026-08-11 |

## Implementation Order

1. Continue implementation from #2454, the nearest due open pinned
   asset-management feature.
2. Keep #2454 deterministic: repayment priority, extra payment, payoff date,
   and interest math must live in Dart service tests, not AI output.
3. Complete #2455 before broadening import/export flows.
4. Finish #2520 live-provider scoring only when API keys and operator approval
   are available; no production routing should depend on unverified social-media
   model rankings.
5. Start Phase 2 at #2460 with monthly reports, then investment assets, then
   dashboard/anomaly/tax work.
6. Defer MoneyForward and MUFG eSmart integrations until local/Supabase state,
   conflict handling, monthly reporting, and investment asset storage are stable.

## NotebookLM Requirement Batch

- `notebooklm list --json` returned `114` notebooks.
- All notebooks now have 3 requirement markers, for `342` total NotebookLM
  requirement slots.
- This session backfilled the missing notebooks and created Issues #2829-#2933.
- `scripts/notebooklm_requirements_to_issues.py` now tolerates raw control
  characters inside NotebookLM JSON strings so one malformed answer does not
  block a full batch.
- `.github/workflows/notebooklm-requirements-to-issues.yml` remains the daily
  automation entrypoint. Keep the default cap of 9 created Issues per scheduled
  run and rely on stable markers for dedup.
- After any manual full backfill, immediately run GitHub Issues WBS Sync and
  WBS Auto Reschedule, as was done in this session.

## Safety Notes

### Living Expense Priority Mode (#4999)

- The `生活費優先モード` toggle is shown above the asset-management action
  list and defaults to OFF so the existing severity/date/title order remains
  unchanged.
- ON applies the deterministic emergency-advice order immediately:
  1. minimum living expenses and lifelines (food, housing, and utilities),
  2. contact for overdue payments,
  3. high-interest card loans (annual rate of 10% or more),
  4. all remaining actions.
- Subscription fixed costs are not treated as housing or utilities, even though
  they share the `fullPaymentEstimate` representation. Within each priority
  group, the existing severity/date/title order is preserved.
- Switching OFF rebuilds the report with the original order. The mode changes
  presentation order only; it does not change balances, payment amounts, due
  dates, AI calculations, or persisted financial data.

- Money calculations stay in Dart service/repository code.
- AI can summarize or explain already-calculated values, but must not be the
  source of truth for balances, due dates, or available cash.
- Supabase sync stays feature-flagged until conflict resolution and rollback
  paths are proven.
- QA and monthly operations for the current asset-management surface are tracked
  in [`ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md`](ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md).

### 借金しない宣言モニター (#4902) 仕様と評価観点

- **目的**: 負債残高の複利増加（スパイラル）を防止し、「カード以外の追加借入ゼロ」および「カード新規利用分の25日全額返済」の2誓約を月次で二値判定・監視する。
- **違反根拠の可視化**:
  - 各カード/ローン口座の利用残高、前月比増減（例: `前月比: +約107,446円`）、月利息、24ヶ月完済ライン（目安月額）を同一UI上に提示。
  - 脱却目安額（12ヶ月完済ライン・24ヶ月完済ライン）と現状ペースでの完済年数・利息総額シミュレーションを併記。
- **「今後一括に固定」トグルと違反数連動**:
  - 違反タイル上で直接「今後一括に固定」の意思記録が可能。
  - チェックを入れると次回評価レポートで該当カードが規律違反カウントから除外され、違反数が減少する。
- **前月データ欠損時のセーフティ**:
  - 前月末残高が未蓄積の場合は『今月のみの推定』と明示し、誓約①（追加借入）を誤検出せず判定保留とする。

### リボカード照合のUI分岐と説明強化 (#4901) 仕様と評価観点

- **目的**: リボ払いカードは請求額が「リボ設定額＋限度超過分」で確定し、取込明細内訳と請求額が一致しないのが正常挙動であるため、不要な不一致アラートを抑止し確定額ロジックをUIで明示する。
- **UI照合テーブルの表示分岐**:
  - `group.isRevolving` が true のカード口座には、カード名の横に青い「リボ」バッジと説明ツールチップを常時表示。
  - 差額列は `—` とし、不一致アラート（設定差分・明細差分）を出さない。
  - 確認事項列には「リボ返済ルール: 最低返済＋新規利用分の全額返済＝25日返済予定」の確定額ロジックを表示。
- **非リボカードの整合性**:
  - 非リボ（アコムショッピング、ファミペイ等で一括払いまたはリボ設定なし）は、通常通り明細未取込時や差分発生時のみ警告を出す。
- **Workbook準拠**:
  - UIの表示切り替えは `Workbook.cardStatementReconciliation.groups[*].isRevolving`（`revolvingBilling != null`）に完全準拠する。

### 今日やることトリアージに出金/移動テンプレ（1万/2万）実装 (#4903) 仕様と評価観点

- **目的**: 今日の使用可能額がマイナス、または手元現金不足時に、生活費の先取りを行動レベルに落とし込むため、指定預金口座からの「1万円/2万円」出金テンプレをトリアージ領域に提示し、ワンタップで振替タスク（transferTask）登録・見込み残高即時再計算を可能にする。
- **UI表示条件とテンプレボタン**:
  - `available_money.today` がマイナスまたは生活費不足時にトリアージ領域へ「1万円出金」「2万円出金」ボタンを表示。
  - 各ボタン押下時に「生活費は専用財布へ」の注意文を併記。
  - 振替タスク保存中（非同期処理中）は二重押下を防止し、両ボタンを無効化。
  - 予定出金後に余力不足となった金額のテンプレートは非表示に制御。
- **データ更新とロールバック**:
  - 押下直後に現金口座への未完了 transferTask を生成・保存し、画面の見込み残高・使用可能額を即時再計算。
  - 同日・同口座・同額の重複登録を防止。
  - 保存失敗時は追加したタスクのみを取り消し（ロールバック）、エラー通知と再試行を提供。
- **クラウド検証**:
  - VMテスト、E2Eテスト（`integration_test/asset_triage_withdrawal_test.dart`）、および Chrome 視覚回帰検証（デスクトップ・モバイル）で挙動を担保。

### カード明細手動照合ウィザード・手動明細入力・仮内訳 (#3329 / #3326 / #3349) 仕様

- **3ステップ手動照合ウィザード (#3329)**:
  - `card_statement_reconciliation.needs_review` が true のときのみ上部に専用警告バナー（`asset_card_reconciliation_needs_review_banner`）および「手動照合を開始」ボタンを表示する。
  - ステップ1（請求額・内訳・差分確認）→ ステップ2（不足差分プレフィル入力 + `CardStatementReconciliationPlanner.previewAdjustment` によるライブ整合/超過判定）→ ステップ3（反映前後確認・保存）の3段階で `configuredDetailTotal` と `billedAmount` を一致させ、完了後はバナーを非表示化する。
  - 暫定保存先は `AssetLiabilityMonthlyState.cardStatementLines` の月次オーバーライドとし、専用のサーバーテーブル正規化同期は将来の追加調査項目として扱う。
- **手動明細入力ウィザードと整合チェック (#3326)**:
  - 明細取り込みが無い／失敗した場合に「手動で明細を追加」モーダルから複数行（利用日・金額・摘要・カテゴリ）を入力し、リアルタイムで請求額との一致を検証する。
  - 差分が残る場合は警告を表示して保存ボタンをブロックし、明示的な許可チェック（`card_manual_entry_allow_mismatch_checkbox`）がある場合のみ部分保存を許可する。
  - AI要約ペイロードの `card_statement_reconciliation` に `manual_statement_pending` / `provisional_detail_count` を含め、未取込時の手動入力誘導を支援する。
- **仮内訳の登録・昇格・削除 (#3349)**:
  - 照合差分がある場合「仮内訳として追加」ボタンから差額を一時記録でき、`isProvisional=true` 行は正式内訳合計（`configuredDetailTotal`）・明細合計（`statementLineTotal`）・給与サイクル支出集計のすべてから除外して二重計上を防止する。
  - UI上は薄色カード＋「仮内訳」バッジで区別し、前月以前の作成日（`createdAt`）を持つ繰越行には「翌月繰越・要確認」バッジを表示する。各行から「正式内訳へ昇格」または「削除」をワンタップで実行できる。

### 安全残高事前振替・入金予定ゲート・資金繰り自動割当 (#3350 / #3291 / #4059) 仕様

- **安全残高割れの事前振替提案・編集ウィザード (#3350)**:
  - `AssetSafetyTransferSuggestionService` で `projectedBalance < minimumSafetyBalance` の口座を検出し、1口座1件の概算振替提案（移動元の現在残高と `minimumSafetyBalance` / `PaymentFundingRule.minimumReserve` の両立、同一銀行・無料振替優先、未完了振替タスク登録で自動解消）を画面上部の `asset_safety_transfer_suggestions_card` に提示する。
  - 各提案の「振替タスク作成」ボタンから `AssetSafetyTransferWizardDialog` を開き、振替元・金額・振替期限を調整して即座に未完了タスクへ起票・見込み残高再計算できる。
- **入金予定未設定トップバナー・給料日ウィザード・確定前ゲート (#3291)**:
  - `PaymentConfirmationGate.evaluate` により `workbook.incomePlans.isEmpty` のとき画面上部へ警告バナー（`asset_income_plan_missing_banner`）を表示し、給料日・金額・入金先・毎月定期登録を一括入力できる `AssetIncomePlanPaydayWizardDialog`（`AssetLiabilityPlanningService.validateIncomePlan` 検証付き）を起動できる。
  - 既存の即座支払チェック（`debt_paid_checkbox_*`）は妨げず、「この額で確定」「推定額を一括確定」および「請求確認済み」ON 操作の直前に、入金予定未登録または支払後使用可能額がマイナスになる場合はキャンセル可能な確認ダイアログ（`asset_income_missing_confirm_dialog`）で事前確認する。
- **支払原資ルール自動割当・振替バッファ・重複防止・日本語導線統一 (#4059)**:
  - `PaymentFundingRule` により優先順位・最低維持残高・除外対象を満たす支払原資口座を自動解決して未設定負債へ割り当て、`buildWorkbook(transferBufferAmount: ...)` で不足額＋バッファを複数移動元にまたがって提案できるようにする。
  - `AssetLiabilityTransferSuggestion` / `AssetLiabilityTransferTask` に `targetPaymentName` / `targetPaymentDate` / `dedupeKey` を追加して月次状態ストア・メモ化キー・比較関数へ永続化し、同一 `dedupeKey` の重複タスク起票を防止する。
  - 不足バナー・振替セクションの操作ラベルを「振替起票」「振替提案」へ日本語統一し、原資未設定行には「期日優先 / 要確認」バッジと `MissingPaymentSourceGuideDialog`（1タップ原資設定）を追加する。

### 債権者連絡テンプレ・送信ログ・カード明細再取得監視 (#3292 / #3288 / #3299) 仕様

- **債権者連絡テンプレートと連絡・合意記録 (#3292 / #3288)**:
  - `lib/models/contact_log.dart` および `AssetCreditorContactService` により、期限超過・期日接近・高金利（年利15%以上）の負債先に対して `CreditorContactTask`（`pending` / `contacted`）を自動組み立てし、「支払日変更」「最低額減額」「分割・一時猶予」の3種類のテンプレート文面を生成する。
  - 負債行の「連絡・記録」から `CreditorContactTemplateAndLogDialog`、「一括連絡テンプレ」から `BulkCreditorContactDialog` を開き、送信失敗時はエラー表示・再送を提示する。保存成功後は「連絡済み」バッジ・次回フォロー日・上部合意内容リマインダーバナー（`asset_creditor_contact_reminder_banner`）および AI 詳細ペイロード（`creditor_contact_tasks` / `contact_log_ids`）へ反映する。
- **カード明細再取得導線と失敗監視 (#3299)**:
  - `CardStatementRefetchService` により要確認カードグループごとに「明細再取得」を実行し、最終試行時刻・成功/失敗状態・失敗理由（`CardStatementImportStatus`）を UI（`asset_card_statement_import_status_<id>`）および AI 詳細ペイロード（`card_statement_reconciliation.statement_import_status`）へ記録する。
  - 再取得失敗時は失敗理由を表示しつつ「手動で明細を入力」から `CardManualStatementEntryDialog` へ即遷移できるようにし、取込成功時は明細行を取り込んで要確認状態を更新する。

### 複数借入・おまとめローン試算と返済危険度・専門家相談ガイド (#1369 / #2750 / #1370) 仕様

- **複数借入の日割り利息・高金利優先繰り上げ返済シミュレーター (#1369)**:
  - `AssetDebtSimulationService` により複数の借入先（残高・実質年率・毎月返済額・次回返済までの日数）を登録・編集し、日割り利息（`残高 × 実質年率 ÷ 365 × 日数`）および次回元金充当額の内訳を表示する。
  - 一括繰り上げ・毎月上乗せ入力時は高金利順（アバランチ法）に優先充当し、短縮月数と軽減総利息を比較バー表示する。
- **おまとめローン（借り換え）効果シミュレーション (#2750)**:
  - 合計残高・想定年利・返済期間を入力し、元利均等返済ベースで借り換え前後の毎月返済額および総支払利息額の差分を比較バーで可視化する。返済期間の長期化等で総支払利息が増える場合は注意喚起を表示する。
  - 共通コンポーネント `DebtLegalDisclaimerBanner` を用いて、おまとめ利用による過払い金請求権の時効・和解等への中立的な法的注意喚起を併記する。
- **返済危険度判定と専門家相談ガイド (#1370)**:
  - `AssetDebtDangerService` で月次返済予定額の対収入比率および月次スナップショットに基づく負債残高非減少の連続月数を評価し、しきい値超過時に画面上部の控えめな案内バナー（`asset_debt_danger_consultation_banner`）および詳細ガイド（`DebtDangerConsultationGuideDialog`）を表示する。
  - しきい値（比率・連続月数・バナー表示有無）は `AssetDebtDangerSettingsStore` で端末永続化し、任意整理・個人再生・自己破産・特定調停の概要と公的・中立的な相談窓口（法テラス・日弁連・司法書士会・全銀協・国民生活センター）への導線を提供する。

### 自動口座間移動設定・監査履歴と税務控除支援ツール (#3443 / #2490 / #2491) 仕様

- **支払原資不足時の自動口座間移動設定・実行・監査履歴 (#3443)**:
  - `AssetAutoTransferService` および `AssetAutoTransferStore` により、移動元の最低維持残高・安全余裕バッファを下回らない範囲のみを補填候補として抽出し、設定（許可 ON/OFF、実行前に最終確認 vs 検知時に自動起票、画面通知、追加余裕バッファ）と実行監査履歴（`AutoTransferAuditEntry` 最大50件）を永続化する。
  - 安全残高割れカード（`asset_safety_transfer_suggestions_card`）およびツールバーから `AutoTransferSettingsAndAuditDialog` を開き、二重起票を防ぎつつ自動/確認実行した振替タスクを追跡できる。
- **ふるさと納税 控除上限シミュレーター (#2490・OFF-default フラグ)**:
  - `AssetFurusatoTaxCalculator` により国税庁（給与所得控除 No.1410・所得税速算表 No.2260）および総務省の公開計算式にもとづき、給与年収・家族構成・扶養人数・社会保険料から控除上限目安を決定論的に試算する（AI説明文はOFF固定）。
- **医療費控除トラッカー (#2491・OFF-default フラグ)**:
  - `AssetMedicalExpenseService` および `AssetMedicalExpenseStore` により病院・薬局・通院交通費・その他の月次支出と保険補填額を記録し、年累計・基準額（10万円または総所得金額等200万円未満の5%）・200万円上限と近づき/達成アラートを表示する。`#2490` / `#2491` は `AssetTaxToolsFeatureFlagStore`（既定 OFF）により明示有効化時のみツールバーに表示する。
