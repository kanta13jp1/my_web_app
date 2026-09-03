# IT セキュリティポリシー v1 — 自分株式会社

> **Win版#132 part 253 (2026-06-10)**: WBS `bd345cfa` (milestone `paying-100` / category business-ops) の成果物。
> タスク定義 = 「パスワード管理 / 端末暗号化 / VPN」。**社内規程 v1 (CEO 承認で発効)**。

## 0. このドキュメントについて

- **目的**: 自分株式会社の情報資産を守る**組織レベルの IT セキュリティ規程**の正本 (SSOT)。[`B2B_PROPOSAL_V1.md`](B2B_PROPOSAL_V1.md) §4 セキュリティ FAQ の「ポリシー文書はあるか」への回答正本であり、SOC 2 準備 (WBS `9a564512` / series-a) の前提文書。
- **適用範囲 (現実の組織形態)**: 役職員 = **CEO 1 名** + AI エージェント (Win Claude / Win Codex の 2 instance 制 + クラウド automation)。対象資産 = 開発端末 (Windows 11 Home) / GitHub リポジトリ・Secrets / Supabase (DB・Auth・Edge Functions) / Firebase Hosting / 利用 SaaS アカウント群。
- **完了の定義 (honest scope)**: 本書は規程の「策定・文書化」が成果物。以下は範囲外 (別タスク): SOC 2 認証準備 (`9a564512`) / インシデント対応の詳細手順 ([`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) が正本) / 法人顧客向け説明資料 ([`B2B_PROPOSAL_V1.md`](B2B_PROPOSAL_V1.md))。
- **既存文書との非重複**: [`MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) は MCP server 公開時の技術 10 原則、[`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) は開発設計原則。**本書は「人と端末とアカウント」の組織運用規程** — 技術設計は両 doc へ委譲し重複記述しない。

## 1. アカウント・パスワード管理

| # | 規程 |
|---|------|
| 1-1 | パスワードは**パスワードマネージャーで生成・保管** (使い回し禁止 / 推測可能文字列禁止) |
| 1-2 | 主要サービス (GitHub / Google / Supabase / Firebase / Anthropic / X 等) は **2FA (多要素認証) 必須** |
| 1-3 | 共有アカウントを作らない (1 アカウント = 1 主体)。AI エージェントには専用の最小権限クレデンシャルを払い出す |
| 1-4 | 退役した instance / 不要になった automation のトークン・PAT は**発見次第失効** (2 instance 制移行で dormant 化した旧 12 instance の残置クレデンシャルは棚卸し対象 / §7) |
| 1-5 | アカウント新規作成・権限変更は CEO のみが行う |

## 2. 秘密情報 (鍵・トークン) の管理

| # | 規程 |
|---|------|
| 2-1 | API キー・トークンの**平文記載を禁止**: リポジトリ / Issue / PR / ブログ / プロンプト / 外部サービスの設定欄 (自動化 routine 含む) のいずれにも貼らない |
| 2-2 | CI/CD で使う鍵は **GitHub Actions Secrets** に保管 (workflow log への echo 禁止) |
| 2-3 | **Supabase `anon` key は公開前提**として扱う (クライアント配布物に含まれる)。保護は RLS (deny-by-default / 有効化 migration 103 件) が担う — anon key の「秘匿」に依存した設計を禁止 |
| 2-4 | **`service_role` 級の鍵は server-side (GHA Secrets / EF 環境変数) のみ**。クライアント・チャット・外部 SaaS 設定欄への投入禁止 |
| 2-5 | 露出 (疑い含む) を検知したら**即ローテーション** → 露出経路の排除 → [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) の手順で記録。「使えているから後回し」を禁止 |
| 2-6 | リポジトリは push 前の secrets スキャン (CI Security Check) を維持する |

## 3. 端末セキュリティ (パスワード管理と同格の最重要領域)

| # | 規程 |
|---|------|
| 3-1 | **端末暗号化必須**: 開発端末 (Windows 11 Home) は**デバイスの暗号化 (Device Encryption / BitLocker 相当)** を有効化する。回復キーは Microsoft アカウント or パスワードマネージャーに保管 |
| 3-2 | OS / ブラウザ / 開発ツールは自動更新を有効に保つ (Windows Update 停止禁止) |
| 3-3 | 画面ロック: 離席時ロック + 自動ロック (数分) を設定 |
| 3-4 | 端末の譲渡・廃棄時はストレージ消去 (暗号化済みであれば回復キー破棄でも可) |
| 3-5 | 不審な実行ファイル・ブラウザ拡張を入れない。Microsoft Defender を無効化しない |

## 4. ネットワーク / VPN

| # | 規程 |
|---|------|
| 4-1 | **公衆 Wi-Fi (カフェ・ホテル等) で業務する場合は VPN 経由またはスマートフォンのテザリング**を使う (平文 Wi-Fi に生で接続しない) |
| 4-2 | VPN 製品の選定は `【CEO確定】` (現時点は固定オフィスなし・自宅回線主体のため、テザリング代替を許容する) |
| 4-3 | 自宅ルーターはファームウェア更新 + 管理画面の初期パスワード変更を済ませる |
| 4-4 | 本番サービスへの管理アクセス (Supabase dashboard / Firebase console / GitHub admin) は信頼できる回線からのみ行う |

## 5. AI エージェント運用のセキュリティ (本組織固有)

| # | 規程 |
|---|------|
| 5-1 | AI エージェントへの権限は **deny-by-default** ([`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md))。production 書込み・secrets アクセスはデフォルト禁止、必要時のみ bounded に許可 ([SUBAGENT-GUARD]) |
| 5-2 | プロンプト・メモリ・ログに秘密鍵を書かない (§2-1 と同一)。鍵が必要な処理は GHA / EF 側で実行する |
| 5-3 | MCP server を外部公開する場合は [`MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) の 10/10 必須 |
| 5-4 | 自動化 (cron / routine / workflow) は実行ログを残し、異常は監視 runbook ([`PRODUCTION_MONITORING_RUNBOOK.md`](PRODUCTION_MONITORING_RUNBOOK.md)) の cadence で点検する |
| 5-5 | AI に渡す差分のマスキング、コンテキスト除外、ベンダー別データ利用設定、四半期確認は [`AI_AGENT_DATA_PROTECTION_STANDARD.md`](AI_AGENT_DATA_PROTECTION_STANDARD.md) を正本とする。未確認のオプトアウト状態を「有効」とみなさない |

## 6. データ・SaaS アクセス管理

| # | 規程 |
|---|------|
| 6-1 | ユーザーデータへのアクセスは業務上必要な範囲のみ (本番 DB の直接操作は migration / 検証目的に限定し、履歴が残る経路で行う) |
| 6-2 | 利用 SaaS は台帳化し (§7 棚卸しで維持)、不要になったら解約・権限剥奪 |
| 6-3 | 顧客 (法人含む) への約束はセキュリティ FAQ ([`B2B_PROPOSAL_V1.md`](B2B_PROPOSAL_V1.md) §4) と本書の範囲内でのみ行う — 規程にない確約をしない |
| 6-4 | Supabase Organization Owner はMFAを有効化した人間のCEOに限定し、AI agent/CI/routine automationへ付与しない |
| 6-5 | Production projectの削除は原則禁止。削除・移管はIssueに対象project ref、理由、実行者、実行時刻、24時間以内のbackup/restore成功証跡を記録し、CEOが明示承認する。詳細は [`SUPABASE_BACKUP_RESTORE_RUNBOOK.md`](SUPABASE_BACKUP_RESTORE_RUNBOOK.md) §7 |
| 6-6 | Database logical backupは暗号化してSupabase外へ保管し、復元可能性を定期drillで検証する。公開repositoryへ平文dumpを保存しない |
| 6-7 | Supabaseプラットフォームログの外部転送は [`SUPABASE_LOG_DRAINS_REQUIREMENTS.md`](SUPABASE_LOG_DRAINS_REQUIREMENTS.md) に従い、費用承認、転送先審査、90日削除、最小権限を満たす場合だけ有効化する |

## 7. 点検・棚卸し (運用 cadence)

| 周期 | 点検 |
|------|------|
| 四半期 | クレデンシャル棚卸し: 発行済み PAT / API key / SaaS アカウント一覧を確認し、不要分を失効 (§1-4) |
| 四半期 | 端末設定確認: 暗号化有効 / OS 更新 / 画面ロック (§3) |
| 四半期 | Supabase Organization Owner一覧と削除・移管権限を確認し、不要なOwnerを削除 (§6-4/6-5) |
| 週次 | 最新の暗号化database backup、restore drill、artifact保持を確認 (§6-6) |
| 随時 | 露出検知時は §2-5 即時対応 (定期を待たない) |
| 年次 | 本書全体の見直し改訂 (SOC 2 準備 `9a564512` 着手時は要求項目との gap 分析で改訂) |

## 8. インシデント対応

- 鍵漏えい・不正アクセス・データ事故は **Sev 判定の上 [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) へ dispatch** (本書は予防規程 / 対応手順は SOP が正本)。
- 法人顧客に影響する事故は契約・FAQ ([`B2B_PROPOSAL_V1.md`](B2B_PROPOSAL_V1.md)) に沿って CEO が通知判断。

## 9. 例外

- 本規程の例外は CEO 承認 + 期限付きでのみ許可し、本書に追記して管理する (恒久例外を作らない)。

## 10. Deferred (v1 では扱わない)

| 項目 | 理由 / 行き先 |
|------|---------------|
| SOC 2 / ISO 27001 準拠の統制設計 | `9a564512` (series-a) で gap 分析から着手 |
| MDM / 資産管理ツール導入 | 端末 1 台規模では過剰 — 従業員採用 (`f849dd2d`) 時に再評価 |
| VPN 製品の指定 | `【CEO確定】` (§4-2) |
| 物理オフィスの入退室管理 | オフィス契約 (`38aeeafc`) 後に追記 |

## 11. Philosophy Alignment ([`PHILOSOPHY.md`](PHILOSOPHY.md) 9 原則)

- **原則 1 (CEO 感)**: 権限変更・例外承認・VPN 選定は CEO 決裁 (§1-5/§4-2/§9) ✅
- **原則 3 (mentor)**: 規程は罰でなく予防の道具 — 例外は隠さず追記で管理 (§9) ✅
- **原則 5 (商品=価値)**: 顧客への安全の約束 (B2B FAQ) を規程で裏付け (§6-3) ✅
- **原則 6 (資本=時間)**: 事故対応時間の最小化 = 予防規程 + 即ローテ原則 (§2-5) ✅
- **原則 7 (資産負債)**: 放置クレデンシャル = 負債 → 棚卸しで返済 (§1-4/§7) ✅
- **原則 8 (KPI)**: paying-100 の法人獲得に必要な信頼基盤 ✅
- **原則 9 (IPO)**: 上場審査で必須となる内部統制 (J-SOX `efe466ca`) への布石 ✅

**7+/9 ✅** (原則 2・4 は本規程の性質上間接整合)。

## Links

- [`B2B_PROPOSAL_V1.md`](B2B_PROPOSAL_V1.md) — §4 セキュリティ FAQ (顧客向け表現 / 本書が正本)
- [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) — インシデント対応 (§8)
- [`PRODUCTION_MONITORING_RUNBOOK.md`](PRODUCTION_MONITORING_RUNBOOK.md) — 監視 cadence (§5-4)
- [`SUPABASE_LOG_DRAINS_REQUIREMENTS.md`](SUPABASE_LOG_DRAINS_REQUIREMENTS.md) — 外部ログ転送、保持、削除、費用統制 (§6-7)
- [`AI_AGENT_DATA_PROTECTION_STANDARD.md`](AI_AGENT_DATA_PROTECTION_STANDARD.md) — AI コンテキスト除外、CI マスキング、ベンダー別データ利用設定 (§5-5)
- [`MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) / [`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) — 技術設計原則 (§5)
- [`OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md) — 運用憲章 (5 正本)
