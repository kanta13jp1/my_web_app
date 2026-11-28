# クラウドインフラ利用枠・課金事前アラート運用ガイド

Status: 運用ベースライン (Issue #2767)

Owner: リポジトリオーナー / 予算責任者

ベンダー公式ページの最終確認日: 2026-11-26

## 1. 目的と範囲

Supabase と Firebase Hosting の無料枠・上限超過による「意図しない課金」「機能制限・サイト停止」を、超過前に検知するための運用手順です。上限値の一覧、閾値評価、月次レビューを定義します。

このガイドは **プラン変更・課金設定の変更・Spend Cap の変更・認証情報の作成を承認しません**。それらは `docs/SUPABASE_CAPACITY_PLAN.md` §6 の承認手順に従い、予算責任者が人手で実施します。

### 既存の仕組みとの関係 (重複定義しない)

| 既存資産 | 担当範囲 | 本ガイドでの扱い |
| --- | --- | --- |
| [Supabase capacity plan](SUPABASE_CAPACITY_PLAN.md) | DB 容量・物理 disk・compute・接続数の閾値と承認手順 | 参照のみ。閾値は再定義しない |
| `quota-monitor.yml` + `scripts/evaluate_quota_thresholds.py` | AI ツール等の API クォータ (80% 警告 / 100% 自動停止) | 連携 API の監視はこちらを継続利用 |
| `ai-compute-cost-alert.yml` / `ai_cost_monitor` | AI 計算コスト・トークンコスト | 同上 |
| `monthly-capacity-report.yml` | アプリ側の利用状況 (アクセス数・バッチ数・エラー率) | 同上 |

本ガイドが埋めるギャップ: **Supabase の egress / storage / MAU / Edge Function 呼び出し / Realtime / ログ、Firebase Hosting の storage / 転送量** の上限一覧と、閾値超過・予測超過の自動アラート、従量課金の試算。

## 2. 契約プランの確認状況

- 現在の Supabase / Firebase のプランは **未確認** です。Issue の記述や過去メモから推測しません。
- プランが不明な間は、保守的に **Supabase = Free、Firebase Hosting = Spark** の上限で評価します (`docs/infra-usage-snapshot.json` の `plans` が `unknown` の場合)。
- 実プランは Supabase の Organization 設定 / Firebase console の Usage and billing で確認し、スナップショットの `plans` を更新します。

## 3. Supabase の利用上限 (一次情報)

出典: [Pricing](https://supabase.com/pricing) (2026-11-26 に本文を直接取得して確認)、[Control your costs / Spend Cap](https://supabase.com/docs/guides/platform/cost-control)、[About billing](https://supabase.com/docs/guides/platform/billing-on-supabase)、[Manage your usage](https://supabase.com/docs/guides/platform/manage-your-usage)。

| 項目 | Free | Pro | Pro の超過単価 |
| --- | --- | --- | --- |
| API リクエスト数 | 無制限 (Unlimited API requests) | 同左 | - (上限なしのため監視対象外。転送量は egress に計上) |
| データベースサイズ | 500 MB | Pro は disk 8 GB (下行) | - |
| Disk (プロジェクトあたり) | 未確認 (§3 注記参照) | 8 GB | $0.125 / GB |
| Egress | 5 GB | 250 GB | $0.09 / GB |
| Cached egress | 5 GB | 250 GB | $0.03 / GB |
| File storage | 1 GB | 100 GB | $0.0213 / GB |
| Monthly active users | 50,000 | 100,000 | $0.00325 / MAU |
| Edge Function 呼び出し | 500,000 | 2,000,000 | $2 / 100 万回 |
| Realtime メッセージ | 200 万 / 月 | 500 万 / 月 | $2.50 / 100 万 |
| Realtime 同時接続ピーク | 200 | 500 | $10 / 1,000 |
| ログ取り込み | 1 GB | 20 GB | $0.50 / GB |
| プラン基本料 | $0 | $25 / 月 (compute クレジット $10 を含む) | - |

注記:

- **スコープ差異 (未解決)**: Pricing ページは Free の "500 MB database size per project" と記載し、`SUPABASE_CAPACITY_PLAN.md` は 500 MB を organization quota として記載しています。どちらが当該契約に適用されるかは未確認です。承認前に両方の一次情報を再確認し、評価は保守的に 500 MB を使用します。
- Free の物理 disk (2 GB 固定等) は capacity plan 側の記載を正本とし、本ガイドでは再確認していないため `docs/infra-quota-limits.json` では `null` (未確認) としています。
- Free プランは超過しても課金されませんが、Fair Use Policy に基づく制限・プロジェクト停止の対象になります (Free は 1 週間無操作で一時停止)。
- Pro では Spend Cap が既定で有効です。有効時は上限超過後その項目の利用が次の請求サイクルまで不可になり、無効時は単価で課金されます。Spend Cap の対象は一部の項目のみです。
- 価格・上限は変更され得るため、**値は日付付きスナップショット**です。変更承認時は必ず一次情報を再確認してください。

## 4. Firebase の利用上限 (一次情報)

出典: [Hosting の使用量・クォータ・料金](https://firebase.google.com/docs/hosting/usage-quotas-pricing) (2026-11-26 取得、最終更新 2026-11-18 UTC)、[Firebase Pricing](https://firebase.google.com/pricing)。

| 項目 | Spark (無料) | Blaze (従量課金) 超過単価 | 超過時の挙動 |
| --- | --- | --- | --- |
| Hosting storage | 10 GB | $0.026 / GB | Spark: 新規デプロイ不可 (古いリリース削除かアップグレードが必要) |
| Hosting データ転送 | 10 GB / 月 | $0.15 / GB | Spark: 短い猶予の後サイトが無効化され、翌月初まで復旧しない |

- Hosting のクォータは **プロジェクト単位**です。CDN キャッシュヒット/ミスの両方が転送量に計上されます。
- Budget alert は Blaze のみで設定でき、**利用や課金を止めません** (通知のみ)。

参考 (Pricing ページ記載の Spark 無料枠。当プロジェクトでの利用は **未確認** のため自動評価の対象外): Cloud Firestore (Standard) は stored data 1 GiB、egress 10 GiB/月、書き込み 20K/日、読み取り 50K/日、削除 20K/日。Firestore 等を使用している場合は `services_in_use` と limits を拡張してください。

## 5. 連携 API の利用上限

AI API (Gemini / OpenAI / Anthropic / Hedra) と GitHub Actions minutes は、既存の `quota-monitor.yml` と `scripts/evaluate_quota_thresholds.py` が 80% 警告 / 100% 自動停止を担当します。本ガイドの自動評価には含めません。各ベンダーの上限は変動が大きいため、そちらの設定を正本とします。

## 6. 自動アラートの仕組み

- 上限と単価: `docs/infra-quota-limits.json` (項目ごとに出典キーと確認日を保持。未確認は `null`)
- 利用量スナップショット: `docs/infra-usage-snapshot.json` (オーナーがダッシュボードの値を転記。初期値は全て未計測 = `null`)
- 評価: `scripts/infra_quota_estimator.py` (オフライン・決定的。ベンダー API は呼ばず、特権認証情報も不要)
- 実行: `.github/workflows/infra-quota-alert.yml` — 毎週月曜 (閾値評価) と毎月 1 日 (月次レビュー)。`permissions` は `contents: read` と、Issue 作成用ジョブのみ `issues: write`。Service role key 等のシークレットは使用しません。

| 状態 | 条件 |
| --- | --- |
| `NORMAL` | 70% 未満 |
| `WATCH` | 70% 以上 |
| `ACTION` | 既定 80% 以上 (閾値は `--alert-threshold-pct` / dispatch 入力で変更可) → **アラート** |
| `CRITICAL` | 90% 以上 → アラート |
| `EXCEEDED` | 100% 以上 → アラート |
| `UNMEASURED` | 値が未記録、またはスナップショットが 35 日より古い (**正常扱いにしない**) |
| `LIMIT_UNVERIFIED` | 当該プランの上限が一次情報で未確認 |
| `NOT_APPLICABLE` | `services_in_use` に含まれないサービス |

- 月間累計の項目 (egress / invocations / メッセージ / ログ) は、`period_start` からの経過日数で月末値を線形予測し、**予測が 100% 以上ならアラート**にします (MAU・ピーク接続・保存量は線形予測しません)。
- 通知は GitHub Issue (`[infra-quota-alert]`) です。状態の署名が変わったときだけ本文を更新しコメントするため、同じ状態で毎週 Issue が増えることはありません。
- 初期状態 (全項目未計測) では `owner_action_required` として Issue が作成されます。これは「計測が未実施である」ことの正しい通知です。
- **使用量の自動収集は未実装**です。Supabase Management API / Google Cloud Billing の読み取りには特権トークンが必要で、本変更では認証情報を作成・保管しないためです。自動化する場合は予算責任者の承認を得て別 Issue で扱います。

## 7. 月次の利用状況・予測コスト確認

毎月 1 日に `[infra-quota-monthly-review] YYYY-MM` Issue が自動作成されます。オーナーは次を実施します。

1. Supabase Dashboard の Usage ページ、Firebase console の Hosting Usage / Usage and billing から当月値を確認する。
2. `docs/infra-usage-snapshot.json` に値を転記し、`collected_at` (UTC, YYYY-MM-DD)・`period_start` (請求期間開始日)・実プランを更新して PR を出す。
3. 試算表 (+0% / +50% / +100% の利用増加シナリオ) で、有料プランに移行した場合の月額見積りを確認する。金額は公開価格表に基づく **見積りであり請求額ではなく**、Compute add-on・Spend Cap・割引・クレジットは含みません。
4. `docs/infra-quota-limits.json` の上限と単価を一次情報で再確認し、`verified_on` を更新する。
5. 予測が上限を超える項目は、最適化・保持期間設定・アーカイブ・プラン変更の順で検討し、課金を伴う変更は予算責任者の承認を得る。

## 8. 検証

```text
python -B test/scripts/test_infra_quota_estimator.py -v
python -B scripts/infra_quota_estimator.py
python -B scripts/infra_quota_estimator.py --alert-threshold-pct 70 --growth-scenarios 0,100,300
```

## 9. 更新ルール

- ベンダーの上限・価格を変更するときは、一次情報の URL と確認日を同じ変更に含めます。値を読み取れなかった項目は推測せず `null` (未確認) にします。
- 新しいサービスを監視対象に加える場合は、limits の `dimensions`、スナップショットの `usage` / `services_in_use`、本ガイドの表を同時に更新します。
