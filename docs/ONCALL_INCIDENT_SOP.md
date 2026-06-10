# On-call / インシデント対応 SOP — MVP ローンチ版 v1

> **WBS task**: `8830188a-db00-44bc-b8c6-2adc51af6b68` (On-call / インシデント対応 SOP / milestone `mvp-launch`)
> **採択日**: 2026-06-09 (Win版#132 part 245 / Win Claude architect lane)
> **対象マイルストーン**: MVP ローンチ (2026-09-30 / 1,000 users 目標)
> **位置づけ**: 本書は「本番障害が起きたとき誰が何をどの順でやるか」を規定する **umbrella SOP (front door)**。
> 個別障害クラスの具体手順は既存の domain runbook へ dispatch する (§5)。
>
> **canonical 関係**:
> - [`OPERATIONS_CHARTER.md`](./OPERATIONS_CHARTER.md) — 運用憲章 (5 正本 / 6 AI 役割)。本書は §6「通信」で憲章 §1 (Source of Truth) に従う。
> - [`AI_DEV_PRINCIPLES.md`](./AI_DEV_PRINCIPLES.md) — circuit-breaker / DLQ / trace_id (= 障害一次対応のプリミティブ)。
> - 個別 runbook 群 (§5 dispatch 表) — MCP auth / AI fallback / disk / asset QA / blog-news。
>
> **scope の線引き**: 本 v1 は MVP ローンチに必要な最小の運用即応性を確立する。
> 成熟版 (RACI マトリクス / 正式 postmortem プロセス / PagerDuty 実席 / SLA 公開) は
> paying-100 マイルストーンの WBS task `3cb3aa46 インシデント対応プロセス` へ **意図的に deferred** (§8)。

---

## 1. 重大度分類 (Severity)

障害を検知したら、まず重大度を 30 秒で判定する。重大度が一次対応の速度と通知経路 (§6) を決める。

| Sev | 定義 | 例 | 一次応答目標 | 通知経路 |
| --- | --- | --- | --- | --- |
| **SEV1** | 本番が広範に停止 / データ毀損リスク / 秘密情報の露出 | 本番サイト 5xx / Supabase 障害 / DB データ破壊 / service_role key 漏洩 / MCP 公開面の不正利用 | 即時 (検知次第) | mobile push + GitHub Issue + Slack |
| **SEV2** | 主要機能の一部が劣化 / 自動化パイプライン停止 / deploy 不能 | deploy-prod RED 継続 / 特定 EF の 5xx / 日次レポート未生成 / quota 超過で AI 機能停止 | 当日中 (営業時間内) | GitHub Issue + Slack |
| **SEV3** | 軽微 / 回避策あり / ユーザー影響なし | 単発 workflow flake / lint 警告 / docs リンク切れ / 非クリティカル cron の 1 回失敗 | 次セッション | GitHub Issue (or memory) |

判定に迷ったら **一段上**に倒す (under-triage より over-triage が安全)。SEV1 は「いま顧客が困っているか / 取り返しがつくか」で判断する。

---

## 2. On-call モデル (solo founder + AI fleet)

自分株式会社は 1 人 CEO (kanta) + AI fleet (Win Claude = 設計/triage / Win Codex = 実装) の構成。
専任オンコール要員を置けないため、MVP 期の "pager" は **人ではなく自動検知 → 通知の多段化**で代替する。

```text
[GHA cron 監視群 + Sentry]  ← 機械の "目" (24h 稼働)
        ↓ 異常検知
[Slack webhook / GitHub Issue 自動起票]  ← 機械の " pager"
        ↓ ユーザー不在時
[mobile push (actionable イベントのみ)]  ← 人 (kanta) への最終エスカレーション
        ↓ セッション開始時
[Win Claude triage → Win Codex 実装]  ← AI fleet が一次対応
```

- **営業時間 (kanta 起動中)**: 検知 → Win Claude が triage → SEV1/2 は即対応、SEV3 は WBS/Issue 化。
- **オフ時間 (深夜 JST 02:00–06:00)**: [SCHEDULE-WAKEUP] により AI fleet の自律 wakeup は禁止。
  この帯の SEV1 のみ mobile push で kanta を起こす。SEV2/3 は翌朝 06:00+ のセッションで対応する
  (= 機械監視は止めない / 人の介入だけ夜間抑制)。
- **"pager" の実体**: 専用 PagerDuty 席は MVP では持たない (§8 で deferred)。
  代替は repository `SLACK_WEBHOOK_URL` (時限アラート) + GitHub Issue (恒久記録) + mobile push。

---

## 3. 検知ソース (Detection)

「機械の目」の実体。各 source が何を捕まえるかを把握しておくと、誤検知と取りこぼしの両方を減らせる。

| Source | 種別 | 捕捉する事象 | 既定 Sev |
| --- | --- | --- | --- |
| `.github/workflows/health-monitor.yml` | cron (毎時) | 本番 endpoint / 主要 EF の死活 | SEV1–2 |
| `.github/workflows/infra-health-check.yml` | cron (日次 01:00) | インフラ全体の整合 | SEV2 |
| `.github/workflows/workflow-failure-handler.yml` | event | GHA workflow 失敗 → AI digest 要約 | SEV2–3 |
| `.github/workflows/quota-monitor.yml` | cron | Anthropic quota 超過 (→ AI 機能停止) | SEV2 |
| `.github/workflows/daily-report-freshness-monitor.yml` | cron | 日次レポート未生成 / 鮮度劣化 | SEV3 |
| `.github/workflows/config-size-monitor.yml` | cron | 設定肥大 (config bloat) | SEV3 |
| `.github/workflows/mcp-audit-anomaly-cron.yml` | cron | MCP 公開面の異常呼び出し | SEV1–2 |
| Sentry + `ErrorReporter` (lib/main.dart) | realtime | Flutter/Dart 実行時エラー → feedback EF | SEV2–3 |
| deploy-prod RED 継続 | event | 本番デプロイ不能 | SEV2 |

> 検知のたびに新しい監視を足す前に、**既存 source で捕まえられないか**を先に確認する
> (OPERATIONS_CHARTER §4.5「形骸化した通知」の逆 — 監視の過剰増殖も負債)。

---

## 4. 一次対応フロー (6 ステップ)

既存の [`mcp-auth-incident-runbook.md`](./mcp-auth-incident-runbook.md) と同じ骨格を全障害クラスの標準とする。

1. **Detect / Classify** — §3 の source で検知 → §1 で Sev 判定。
2. **Triage** — 該当する障害クラスを特定し、§5 dispatch 表で具体 runbook を引く。Win Claude lane。
3. **Contain (封じ込め)** — 被害の拡大を止める。**復旧より封じ込めが先**。
   - circuit-breaker を効かせる / 該当 EF や cron を一時停止 / 不正 client を `suspended=true` (削除はしない)。
   - データ毀損系は「書き込みを止める」を最優先。`DELETE`/`DROP` は封じ込め中は禁止 (監査相関を保持)。
4. **Communicate** — §6 の経路で第一報。SEV1/2 は GitHub Issue を恒久記録として起票。
5. **Recover (復旧)** — root cause 特定 or 確実に benign を確認してから 1 単位ずつ復旧。
   - credential 漏洩疑いは復旧前に **rotation 完了**が必須。
   - 復旧後は検知 source で正常化を確認 (dry-run → 期待値の観測)。
6. **Postmortem** — §7 テンプレで記録。memory/ + NotebookLM Master Brain に「なぜ」を残す。

各ステップは [`AI_DEV_PRINCIPLES.md`](./AI_DEV_PRINCIPLES.md) のプリミティブに対応する:
circuit-breaker (Step 3) / DLQ = 失敗イベントの退避先 (Step 3,5) / trace_id = 相関の鍵 (Step 2,5)。

---

## 5. Runbook dispatch 表 (front door)

本 SOP の中核価値。障害クラスごとに**既存の具体手順書**へ振り分ける。重複手順はここに書かず、正本 runbook を参照する。

| 障害クラス | 一次 runbook | 主な封じ込め操作 |
| --- | --- | --- |
| MCP auth / 公開面の不正利用 | [`mcp-auth-incident-runbook.md`](./mcp-auth-incident-runbook.md) | `mcp_oauth_clients.suspended=true` |
| Anthropic quota 超過 / AI 機能停止 | [`AI_FALLBACK_RUNBOOK.md`](./AI_FALLBACK_RUNBOOK.md) | Codex / Gemini / Copilot へ fallback |
| ディスク逼迫 (C: < 25GB) | [`DISK_HYGIENE_RUNBOOK.md`](./DISK_HYGIENE_RUNBOOK.md) | worktree prune / git gc / cache 削除 |
| 資産管理機能の品質障害 | [`ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md`](./ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md) | 該当機能の feature flag off |
| ブログ/ニュース自動配信の停止 | [`BLOG_NEWS_AUTOMATION_RUNBOOK.md`](./BLOG_NEWS_AUTOMATION_RUNBOOK.md) | dispatch 一時停止 / 再投稿 gate |
| deploy-prod RED 継続 | (本 SOP §4 + Issue handoff) | 原因 commit を特定 → Codex へ修正 PR handoff |
| 上記に該当しない新規クラス | (本 SOP §4 で対応) | 対応後 §8 に従い新 runbook を follow-up |

> dispatch 先が無い障害は §4 の汎用フローで対応し、**事後に runbook を 1 本起票**する
> (= front door は塞がない / 知識を runbook に蓄積)。

---

## 6. 通信プロトコル (Communication)

OPERATIONS_CHARTER §1 の 5 正本に従う。**恒久記録は GitHub Issue、揮発の即時通知は Slack**。

- **GitHub Issue (恒久 / 正本)**: SEV1/2 は必ず起票。記載 = 影響範囲 / 影響時間窓 / 現在のユーザー影響 / 次の検証ステップ / 復旧オーナー。
- **Slack `SLACK_WEBHOOK_URL` (時限のみ)**: 時間に追われるアラートだけ。1 週間で揮発する前提。
- **mobile push (人へのエスカレーション)**: actionable な SEV1、または夜間帯に kanta の判断が必要な事象のみ。
- **禁止**: token / secret / 生 bearer header / service_role key を Issue・Slack・push のいずれにも載せない。
- **二重起票防止**: 起票前に `gh issue list --search "<keyword>"` で重複確認 ([ISSUE-PRECHECK] 準拠)。

---

## 7. Postmortem テンプレート (blameless)

SEV1/2 は復旧後 1 営業日以内に記録する。保存先は [`docs/incident-reports/`](./incident-reports/)。**人を責めず仕組みを直す**。

```markdown
# Postmortem: <短い表題> (<YYYY-MM-DD>)

- **Sev**: SEV1 | SEV2
- **影響時間窓**: <検知 → 復旧>
- **ユーザー影響**: <何が / どれだけ>
- **検知経路**: <§3 のどの source か / 検知遅延はあったか>
- **Root cause**: <なぜ起きたか — 仕組みの欠陥として>
- **対応タイムライン**: Detect → Contain → Communicate → Recover の各時刻
- **再発防止 (action items)**: <検知 source 追加 / runbook 追記 / circuit-breaker 調整 など / 担当 instance>
- **学び (→ memory + NotebookLM)**: <「なぜそうしたか」を Master Brain source へ>
```

- 「なぜ」は OPERATIONS_CHARTER §4.2 に従い NotebookLM Master Brain へ蓄積する。
- 同種の障害を 2 回以上経験したら、共通原則として該当 `docs/<軸>_PRINCIPLES.md` に蒸留する。

---

## 8. MVP scope と deferred

| 項目 | MVP ローンチ (本 v1) | paying-100 へ deferred |
| --- | --- | --- |
| Sev 分類 | ✅ SEV1–3 (§1) | SLA 数値化 / 顧客向け status page |
| On-call | ✅ AI fleet + mobile push (§2) | PagerDuty 実席 / ローテーション |
| 検知 | ✅ 既存 cron + Sentry (§3) | 合成監視 (synthetic) / 外形監視の冗長化 |
| 対応フロー | ✅ 6 ステップ (§4) | 正式 RACI マトリクス |
| Postmortem | ✅ blameless テンプレ (§7) | 定例 postmortem レビュー会 / 指標 (MTTR) 集計 |

> 成熟版は WBS task `3cb3aa46 インシデント対応プロセス` (milestone `paying-100`) が担う。
> 本 v1 と重複させず、本書を前提に**上積み**する。

---

## 9. 原則アラインメント

- **PHILOSOPHY** — 原則 1 (CEO 感: 夜間 SEV1 のみ人を起こし最終判断を CEO に残す) / 原則 4 (6 部署: 本社=運用即応性) / 原則 8 (KPI: MTTR を将来の North-Star 候補に)。
- **AI_DEV_PRINCIPLES** — circuit-breaker / DLQ / trace_id を一次対応の標準操作に組み込み (§4)。
- **OPERATIONS_CHARTER** — 5 正本の通信規律を §6 で継承 / 監視の過剰増殖を §3 で抑制。

---

## 10. 改訂履歴

| 日付 | 変更 |
| --- | --- |
| 2026-06-09 | 初版 v1 (Win版#132 part 245 / Win Claude)。MVP ローンチ版 umbrella SOP として Sev 分類・solo founder + AI fleet on-call モデル・検知 source 表・6 ステップフロー・既存 runbook dispatch 表・通信プロトコル・blameless postmortem テンプレを確立。成熟版は paying-100 task `3cb3aa46` へ deferred。 |
