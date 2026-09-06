# 本番監視 & 定常運用 Runbook — 自分株式会社

Status: v1 (Accepted baseline / 反復運用ドキュメント / **本番運用で更新し続ける living doc**)
Date: 2026-06-09
Owner: Win Claude (L3 設計レーン / architect / ops docs lane / [DYNAMIC-CLAIM] で codex→win claim)
WBS: `2e8be6a7-6741-4e38-a910-e96267caa018` 「[運用] 本番監視・インシデント対応 runbook」(cs-check / ci-cd-audit / incident report を定常運用として WBS に接続 + escalation paths + recurring health-check evidence)
Sources: 実 `.github/workflows/*.yml` (監視 cron 群) / claude.ai Routines (cs-check / ci-cd-cost-audit) / [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) (障害対応=赤の道) / [`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) (リリース) / [`SUPABASE_CAPACITY_PLAN.md`](SUPABASE_CAPACITY_PLAN.md) (DB/compute capacity) / [`OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md) (5 正本)

---

## 0. このドキュメントについて

- **目的**: タスクどおり、**本番監視の定常運用**(cs-check / ci-cd-audit / infra health-check 等)を**何を・いつ・どう確認し、異常をどう WBS/Issue に接続するか**の SSOT。「緑の道」(平常時に健全を確認する反復運用) を担う。
- **ops 三部作での位置 (重複しない)**:
  - **本書 = 監視 (Monitor / 緑の道)** … 平常運用・健全確認・定常レビューの cadence。
  - [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) **= 対応 (Respond / 赤の道)** … 異常検知**後**の Sev 分類・封じ込め・復旧・postmortem。本書 §4 はそこへの**入口**のみ。
  - [`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) **= リリース** … デプロイ前後の手順・rollback。
  - 三者は **Monitor → (異常) → Respond / (変更) → Release** で循環する。検知 source の表は SOP §3 が初出 → 本書はそれを**運用 cadence の視点**で展開し重複記述を避ける。
- **前提 (現状の真実 / [REAL-DATA])**: 専任 SRE はいない (1 人 CEO + AI fleet)。監視は **GHA cron 群 + claude.ai Routines + Sentry** の「機械の目」が担い、人 (kanta) と AI fleet (Win Claude triage / Win Codex 実装) はセッション時に**証跡を確認 → 異常のみ WBS/Issue 化**する。

## 1. 監視サーフェス一覧 (What watches production)

各監視の **cadence / 何を見るか / 健全 vs 異常 / 出力先**。詳細な Sev 既定は [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) §3。

| 監視 | 種別 / cadence | 何を見るか | 健全 (緑) | 異常 (→ §4) |
|------|---------------|-----------|----------|-------------|
| `health-monitor.yml` | GHA cron (毎時) | 本番 endpoint / 主要 EF 死活 | 200 応答 | 5xx / タイムアウト |
| `infra-health-check.yml` | GHA cron (日次) | インフラ全体整合 | green run | 不整合検出 |
| `quota-monitor.yml` | GHA cron | Anthropic quota 残 | 余裕あり | 超過 → AI 機能 fallback |
| `daily-report-freshness-monitor.yml` | GHA cron | 日次レポート鮮度 | 当日分生成済 | 未生成 / 鮮度劣化 |
| `config-size-monitor.yml` | GHA cron | 設定肥大 (bloat) | 閾値内 | 肥大 → 整理 |
| `mcp-audit-anomaly-cron.yml` | GHA cron | MCP 公開面の異常呼び出し | 異常なし | 不正利用パターン |
| `wbs-staleness-audit.yml` | GHA cron | WBS 停滞 / [WBS-SYNC] 違反 | stale 0 | stale task / cross-instance-pr |
| `edge-function-audit.yml` | GHA cron | EF 本数 ([EF-CAP-50]) | ≤ 50 | 超過 |
| `competitor-monitoring.yml` | GHA cron (日次 07:00) | 競合 21+ 社の変化 | 差分記録 | (情報のみ) |
| **cs-check** (`cs-check.yml` / claude.ai Routine) | 定期 | カスタマーサクセス健全性 (サポート/フィードバック滞留) | 滞留なし | 未対応 ticket |
| **ci-cd-cost-audit** (claude.ai Routine / 日次 23:00 JST) | 定期 | CI/CD 冗長・コスト | 最適 | 冗長検出 → 低リスク改善 PR / 高リスクは Issue 提案 |
| Sentry + `ErrorReporter` (lib/main.dart) | realtime | Flutter/Dart 実行時エラー | 新規エラーなし | エラー急増 |
| deploy-prod 状態 | event | 本番デプロイ可否 | green | RED 継続 |
| Supabase capacity review | 週次 + 大規模 release/import 前後 | plan/compute、DB size と増加率、CPU/memory、connection、disk I/O | capacity plan の `NORMAL` | `WATCH` 以上 → [`SUPABASE_CAPACITY_PLAN.md`](SUPABASE_CAPACITY_PLAN.md) |

> **監視の過剰増殖も負債** ([OPERATIONS_CHARTER.md](OPERATIONS_CHARTER.md) §4.5 の逆)。新規監視を足す前に、既存 source で捕まえられないかを先に確認する。

## 2. 定常運用の cadence (Routine operations)

タスクの核心「cs-check / ci-cd-audit / incident report を**定常運用として WBS に接続**」。**機械が回し、人/AI は証跡を確認して異常のみ WBS 化**する。

| 頻度 | 運用 | アクション | WBS/Issue 接続 |
|------|------|-----------|----------------|
| **毎セッション開始** | 監視証跡レビュー | 直近の health-monitor / infra-health-check / deploy-prod 状態 / Sentry を確認 ([UI-VERIFY] と併せ home/AI 大学/LP/ranking 目視) | 異常 → §4 escalation |
| **毎セッション開始** | [WBS-SYNC] | `wbs.priority_for_instance` で TOP5 + 自タスク更新 | WBS 直結 |
| **日次 (機械)** | infra-health-check / daily-report-freshness / ci-cd-cost-audit / competitor-monitoring | cron 自動実行 → 結果は run log + 自動 commit | freshness 劣化や cost 冗長は Issue/PR |
| **定期 (機械)** | cs-check / quota-monitor / mcp-audit-anomaly | cron 自動 → 異常時 Slack/Issue | 未対応 ticket / quota / MCP 異常 → §4 |
| **障害発生時** | incident report | [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) §7 postmortem を `docs/incident-reports/` に記録 | SEV1/2 は GitHub Issue 恒久記録 |
| **週次** | 監視棚卸し | 形骸化した通知 / 過剰監視 / 取りこぼしを点検 | 不要監視は削減提案 |
| **週次 + 大規模 release/import 前後** | Supabase capacity review | plan/compute と容量・増加率・負荷を読み取り専用で記録 | `WATCH` 以上は [`SUPABASE_CAPACITY_PLAN.md`](SUPABASE_CAPACITY_PLAN.md) の単一 Issue / 承認フローへ |

- **WBS 接続の原則**: 定常運用そのものは WBS task 化しない (cron で回る)。**異常・改善・恒久対応のみ**を Issue/WBS 化し、定常運用と一過性タスクを混同しない。

## 3. 健全性の証跡 (Health-check evidence)

「緑である」ことの確認可能な証跡。迷ったら一次情報を見る。

- **本番が現行 commit か**: `https://my-web-app-b67f4.web.app/version.json` の `commit` が main HEAD と一致 (リリース検証と同じ / [`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) §6)。
- **liveness**: `health-check` EF (public / no-verify-jwt) が 200。
- **cron 健全**: GitHub Actions の各監視 workflow が直近 green (`gh run list --workflow=<name>.yml`)。
- **エラー**: Sentry に新規 critical なし。
- **WBS 健全**: `wbs-staleness-audit` が stale 0 / cross-instance-pr 未発生。
- 証跡は基本 **GitHub Actions run log + 自動 commit + Issue** に残る (恒久) / Slack は時限通知のみ ([OPERATIONS_CHARTER.md](OPERATIONS_CHARTER.md) §1)。

## 4. Escalation (緑 → 赤の入口)

監視が異常を示したら、本書の役目はここで終わり、**対応は [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) に dispatch** する。

1. 異常を検知 (§1 の source) → SOP §1 で **Sev 30 秒判定** (迷ったら一段上)。
2. SEV1 (本番停止 / データ毀損 / 秘密露出) → 即 SOP §4 一次対応 (検知次第 / 夜間は mobile push)。
3. SEV2 (主要機能劣化 / 自動化停止 / deploy 不能) → 当日中 / GitHub Issue 起票。
4. SEV3 (軽微 / 回避策あり) → 次セッション / Issue or memory。
- 起票前に `gh issue list --search "<keyword>"` で重複確認 ([ISSUE-PRECHECK])。**token/secret/service_role を通知に載せない**。
- 具体手順は SOP §5 dispatch 表 (MCP auth / AI fallback / disk / asset QA / blog-news / deploy-prod RED) の正本 runbook へ。

## 5. 役割 (Roles)

- **機械 (GHA cron + claude.ai Routine + Sentry)**: 24h 検知・自動記録。
- **Win Claude (L3)**: 本書 (監視運用 SOP) の設計・維持 / セッション時の証跡 triage / 異常の WBS・Issue 化。
- **Win Codex (L2)**: 監視 workflow / Sentry 連携 / EF の実装・修正。
- **CEO (User)**: 夜間 SEV1 の最終判断 / 監視方針の承認。

## 6. Deferred / 非スコープ

- **Sentry 連携の深掘り実装** (WBS `120afbf8 エラー監視強化` / milestone v1 / コード = L2 Codex)。
- **合成監視 (synthetic) / 外形監視の冗長化 / SLA 数値化 / status page** ([`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) §8 と同じく paying-100 へ deferred)。
- **監視 workflow 自体の実装変更** (本書は運用手順の正本 / 実装は L2)。
- **障害対応の詳細フロー** ([`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) が正本) / **一度きりの GA 可否** ([`GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md))。

## 7. 原則整合 (Philosophy Alignment)

[`PHILOSOPHY.md`](PHILOSOPHY.md) 9 原則で **7+/9 ✅**: 原則 1 (夜間 SEV1 のみ人=CEO へ) · 原則 3-4 (mentor / チェックリストで負荷軽減 / 本社=運用即応性) · 原則 6 (時間 = 自動監視で人の確認時間を最小化) · 原則 7 (安定運用 = 資産 / 監視の過剰増殖 = 負債) · 原則 8 (KPI = 健全率・検知遅延を昨日の自分基準で改善) · 原則 9 (夜間の人的負荷を抑制)。[`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) (circuit-breaker / DLQ / trace_id) + [`OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md) (5 正本 / 通知規律) に整合。

## 8. 運用 (Living Document) / Links

- 監視を足す/減らすたびに §1 表を更新 (薄く保つ)。Sentry 連携が深化したら §1/§3 を更新。
- ops 三部作: 本書 (監視) / [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) (対応) / [`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) (リリース) / capacity: [`SUPABASE_CAPACITY_PLAN.md`](SUPABASE_CAPACITY_PLAN.md) / 憲章: [`OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md)
- 実行計画: WBS (project-gantt) / task `2e8be6a7-6741-4e38-a910-e96267caa018`
