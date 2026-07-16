# NotebookLM 由来 Issue 氾濫 トリアージ戦略 (2026-07-16)

> 策定: Win Claude (L3)。契機: ユーザー要請「NotebookLM 由来 Issue の氾濫を同じ棚卸し手法で
> トリアージし、次の集約候補を作る」。
> 手法: GitHub 検索でテーマ別・ラベル別の件数分布を定量化し、既存実装システムとの重なりを判定。

## エグゼクティブサマリ

`label:notebooklm` の **open Issue = 352 件**。これが WBS 肥大の最大要因です。しかし個別価値の
問題ではなく **供給過剰と未トリアージ**が本質でした:

- **triage 済み: 1 / 352**(`triage:done`)。**priority:high: 1 / 352**(= #2967 = 抽出 pipeline 自体の修理 meta)。
- 生成源は `scripts/notebooklm_requirements_to_issues.py` が **114 notebook × 3 要望 = 342 slot** を
  自動抽出したもの(`docs/asset-management-wbs-plan.md` 記載)。
- **source notebook がアプリと無関係なケースが多発**: 実サンプルで確認した source =
  「CATS System Planned Outage Notification」「Cursor Product Updates Changelog」
  「ENEOS Acquisition of Chevron Subsidiaries」等 → AI が無関係資料からアプリ要望を外挿。
- **強いテーマ重複**: 承認/approval **20** / Notion **17** / コスト・モデルルーティング **54** 等。

→ 個別に 352 件の verdict を付けるのは非現実的。**テーマ集約 + source 信号フィルタ + 供給の throttle**
の 3 本立てが正解です。そして重複テーマの多くは**既に実装済みシステム**に対応します。

## 定量分布 (open / label:notebooklm = 352)

| 指標 | 件数 | メモ |
|---|---:|---|
| 全 open | 352 | |
| triage:done | 1 | ほぼ未トリアージ |
| priority:high | 1 | #2967(pipeline 修理 meta)のみ |
| テーマ: コスト/モデルルーティング (`コスト`) | 54 | 既存実装と重複(下記 B) |
| テーマ: 承認/ステージゲート (`承認`) | 20 | 既存実装と重複(下記 B) |
| テーマ: Notion 連携 (`Notion`) | 17 | 一部実装済 + triage epic #1840 既存 |

## トリアージ分類 (4 バケット)

### A. off-topic source(低信号の自動外挿)→ `not_planned` で close 候補
source notebook がアプリと無関係(企業買収 / システム障害通知 / 他社製品 changelog 等)の Issue。
受け入れ条件がアプリ機能に接続していない外挿要望。**最大の削減余地**。
- 判定基準: body の `Notebook title` がアプリ(自分株式会社 SaaS)と無関係。
- 推奨: source notebook の allowlist に無いものを `not_planned` で一括 close。

### B. 実装済みシステムのテーマ重複 → `duplicate` / `completed` で close 候補
NotebookLM が繰り返し抽出するテーマの多くは**既に実装済み**:

| テーマ | 概算 | 既存実装エビデンス |
|---|---:|---|
| 承認 / ステージゲート / Human-in-the-loop | ~20 | `ai_review_status`(pending→requested→approved/rejected/manual_override)+ `wbs_guard_open_github_issue_completion` トリガー + `.github/workflows/wbs-ai-review.yml` + `supabase/functions/_shared/multi_step_approval_workflow.ts` / `saas_human_approval.ts` |
| モデルルーティング / 推論コスト最適化 | ~54(一部) | `supabase/functions/_shared/ai_router_cost_optimization.ts` + migration `20260610140000_wbs_complete_model_routing.sql` + AI tool monitoring |
| GitHub Issue 自動起票 / WBS 同期 | 複数 | `tools-hub:wbs.sync_github_issues` + `issue-to-wbs.yml` + `wbs-progress-update.yml`(本セッションの stale 修復もこの系) |
| MCP / secret / 認証ガード | 複数 | `mcp_auth_guard.ts` + `mcp_client_registration.ts` + `internal_hmac.ts` |

→ 各テーマ 1 本を canonical epic に残し、残りは実装エビデンス付きコメントで close。

### C. テーマ集約(重複だが未実装)→ canonical epic 1 本 + 残り duplicate close
実装はまだだが同テーマ多数のクラスタ(Notion 同期の細分 / dashboards / 抽出 pipeline 派生 等)。
資産管理クラスタと同じ「親 epic + 残差分」方式。Notion は既に triage epic **#1840** が存在。

### D. 真に actionable な singleton → open 維持 / route
アプリ機能に直結し、実装済みでも重複でもない少数。これだけを実装バックログに残す。

## 推奨アクション

### 1. 供給を止める(最優先 / これをやらないと再氾濫)
**#2967**(pipeline auth 修理)は「復旧して**さらに 3件/notebook 抽出を回す**」内容 = 氾濫を増やす方向。
推奨: 復旧の前に pipeline に **relevance gate** を追加 —
- source notebook の allowlist(アプリ関連のみ)を導入、
- 既存の 9件/日 cap を維持、
- 抽出前に「アプリ機能に接続するか」の判定を挟む。
→ #2967 を「認証復旧」から「**relevance gate + cap 付き復旧**」に再定義するのが正しい。

### 2. バックログを drain(352 → 目標 < 50)
352 件は手作業 close 非現実的 → **スクリプト方式**を推奨(資産クラスタの手法を scale):
- `scripts/` に triage スクリプト(source notebook title + タイトル keyword でバケット分類)、
- **A(off-topic)** と **B(実装済み重複)** を標準コメント付きで一括 close、
- **C** はテーマごとに canonical epic を選定し残りを duplicate close、
- WBS 側は closed issue → sync が completed 追随(本セッションの stale 修復と同経路)。

### 3. 本セッションで実行可能な高信頼 first batch(要承認)
最も安全 = **B の「承認/ステージゲート」20 件**(既存 `ai_review_status` stage-gate を verify 済み)。
canonical epic を 1 本立て、20 件を実装エビデンス付き `duplicate` で close。資産クラスタと同じ手順・
同じ reversibility。承認あれば即実行します。

## 承認のお願い

以下のどれで進めますか(いずれも close は reversible):
1. **B「承認」20 件を first batch で集約 close**(canonical epic + duplicate close)— 最も安全・即実行可
2. **B 全体(承認 + モデルルーティング等)を集約 close** — より大きい削減、各テーマ epic 化
3. **A(off-topic source)も含めた本格 drain のスクリプト設計** — 最大削減だが設計工数あり
4. **戦略だけ確認**(この doc)、実行はユーザー判断

> 根本解決は #2967 を「relevance gate 付き復旧」に再定義して**供給を止める**こと。drain と throttle を
> 両輪で回さないと、close しても再び 3件/notebook で埋まります。
