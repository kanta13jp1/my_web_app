# SPOF リスク評価 & フェイルオーバー戦略 v1 — 自分株式会社

> **Win版#132 part 258 (2026-06-10)**: WBS `aa08e69f` / [Issue #2599](https://github.com/kanta13jp1/my_web_app/issues/2599) の成果物。
> クラウドインフラ・CI/CD の単一障害点 (SPOF) を実在構成に基づいて評価し、フェイルオーバー戦略を**策定**する。

## 0. このドキュメントについて (honest scope)

- **完了の定義**: 本書は「評価と戦略の**策定**」(= Issue タイトルのスコープ) が成果物。Issue #2599 の受入基準との対応:
  - 基準 1 (Supabase リージョン可用性リスク評価 + バックアップ復元手順の文書化) → **本書 §2-§3 で充足**
  - 基準 2 (GHA 障害時の代替ビルド・デプロイ手順の確立) → **本書 §4 で充足** (実 workflow から導出した手動手順)
  - 基準 3 (Flutter 縮退運転モードの**実装**) → **本書 §5 は設計まで**。実装は L2 (Codex) の別アクション — **本書では実装済みを主張しない。Issue #2599 は基準 3 が実装されるまで open 維持**。
- Issue 中の外部事実 (Coinbase の AWS 障害 / GitHub Actions 障害 57 回/12 か月) は NotebookLM 由来の**未検証主張** — 本書の判断は外部数値に依存させず、自社構成の実在 SPOF のみから導出 ([AI-TOOL-VERIFY])。

## 1. 実在構成 (= 評価対象 / fabrication なし)

単一 Supabase プロジェクト `smmkxxavexumewbfaqpy` (PostgreSQL + Auth + Edge Functions) + Firebase Hosting (本番 <https://my-web-app-b67f4.web.app/>) + GitHub (リポジトリ + Actions CI/CD) + Anthropic 等 AI API (AI 機能) + 開発端末 1 台 / CEO 1 名。

## 2. SPOF 台帳とリスク評価

| # | SPOF | 影響 (障害時) | 既存の緩和 | 残リスク評価 |
|---|------|---------------|-----------|--------------|
| S1 | **Supabase 単一プロジェクト/単一リージョン** (リージョン名は dashboard で確認 = `【確認事項】`) | DB/Auth/EF 全停止 = アプリのデータ機能停止 | RLS/migrations = スキーマは repo に SSOT / 監視 ([`PRODUCTION_MONITORING_RUNBOOK.md`](PRODUCTION_MONITORING_RUNBOOK.md)) | **最大の SPOF**。データのバックアップ実効性が plan 依存 (§3) |
| S2 | **GitHub + GitHub Actions** (CI/CD 単一依存) | デプロイ不能 (アプリ自体は稼働継続) | [CONCURRENCY] 順次 deploy / repo は各端末に clone 分散 | 中。**復旧を待てるケースが大半** — 緊急修正時のみ §4 の手動経路 |
| S3 | **Firebase Hosting** | Web 配信停止 | Google CDN 側の冗長性 (マネージド) | 低 (歴史的に高可用 / 代替配信は §6 で defer) |
| S4 | **AI API (Anthropic 等)** | AI 機能のみ劣化 | [`AI_FALLBACK_RUNBOOK.md`](AI_FALLBACK_RUNBOOK.md) (Codex/Gemini/Copilot fallback) + ai-hub の複数 provider | 低-中 (コア記録機能は AI 非依存) |
| S5 | **人的 SPOF (CEO 1 名 / 端末 1 台)** | 全運用停止 | [`IT_SECURITY_POLICY_V1.md`](IT_SECURITY_POLICY_V1.md) (暗号化・回復キー) / repo・secrets はクラウド側に存在 | 中。端末喪失でもデータ喪失なし (repo/GH Secrets/Supabase はクラウド) — 復旧手順 = §4 前提条件で吸収 |

優先順位: **S1 (データ) > S2 (デプロイ) > S5 > S4 > S3**。理由: データだけが「失うと取り返せない」資産 (原則 7)。

## 3. S1 対応 — バックアップ・復元 (基準 1)

**スキーマ**: `supabase/migrations/` が SSOT (repo 内 / GitHub + 各端末に分散済み) → スキーマ喪失リスクは実質ゼロ。

**データ** (= 本丸):
1. **現状 (2026-08-26)**: Production は Free plan。Supabase platformの日次backup/PITRに依存せず、
   [database backup / restore runbook](SUPABASE_BACKUP_RESTORE_RUNBOOK.md) を正本とする。
2. **自動export**: `.github/workflows/supabase-backup-restore.yml` が毎週、roles/schema/dataの
   logical dumpを作り、AES-256暗号化artifactを35日保持する。平文DB dumpはartifactへ保存しない。
3. **restore drill**: 各backup runで暗号化bundleを再展開し、production/stagingから隔離した
   ephemeral Supabase Postgres 17へtransactional restoreする。`public` 全tableのdump行数と
   restore後行数を照合する。初回production-data drillのrun URLはrunbook/Issue #1291へ記録する。
4. **別projectへの実災害復旧**: replacement project作成、Auth/Realtime/Storage/EF再設定、
   client URL/key切替を含むため、Incident Issue上のCEO承認を要する。週次drillは外部projectを
   作成・上書き・削除しない。

## 4. S2 対応 — GHA 障害時の代替デプロイ手順 (基準 2)

通常経路 = `deploy-prod.yml` (main merge → 自動)。GHA 長時間障害 **かつ** 緊急修正が必要な場合のみ、以下の手動経路 (= 実 workflow の steps から導出 / 同 workflow `deploy-prod.yml` L530-705 相当):

```bash
# 前提: ローカルに Flutter SDK / Supabase CLI / Node。鍵は GH Secrets と同等物を CEO が保持
# ⚠️ 既知の罠 (part 244 実証): local Flutter/Dart バージョンが CI (Flutter 3.38.x 系) と
#    不一致だと format/build 差分が出る → 手動 deploy 前に `flutter --version` を CI と合わせる
supabase db push                                  # 1) migrations 適用
supabase functions deploy <function_name>         # 2) EF deploy (EDGE_FUNCTION_LIST.md の対象分)
flutter build web --release                       # 3) Web ビルド
npx -y firebase-tools@latest deploy --only hosting --project <FIREBASE_PROJECT_ID>  # 4) 配信 (service account 認証)
```

- 検証: deploy 後に `version.json` 反映と health-check ([`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) のスモークに従う)。
- **GitHub 自体の長期障害** (repo にも push 不可) の場合: 各端末の clone が full history を保持 — 復旧後 push で同期。コードは Git の分散性で守られている (追加対策不要と評価)。

## 5. S1/S4 対応 — Flutter 縮退運転モード (基準 3 = 設計のみ / 実装は L2)

**現状 verify (2026-06-10)**: エラー報告基盤 (Sentry + `ErrorReporter` / [`lib/main.dart`](../lib/main.dart)) と認証不能時の graceful メッセージ (`LandingPageAuthUnavailableException` → ユーザー向け文言) は**実装済み**。オフラインキャッシュ (Hive 等によるローカル退避) は**未実装**。

**設計 (実装は L2 / 段階制)**:
- **Phase A (小)**: Supabase 接続失敗時の共通エラー UX 統一 — 「読み込めません + 再試行」を主要ページで統一表示 (機能ごとの白画面を排除)。新規依存なし。
- **Phase B (中)**: 読み取りキャッシュ — 最後に取得したダッシュボード/ノート一覧を `shared_preferences` 系に保持し、接続失敗時は「オフライン表示 (最終更新時刻付き)」へ縮退。書き込みは行わない (= 競合・整合性問題を作らない)。
- **Phase C (defer)**: 書き込みキューイング (オフライン入力→復帰時同期) — 競合解決設計が必要なため `paying-100` 後に再評価。
- handoff: Phase A/B の実装は Issue #2599 を open のまま L2 (Codex) が拾う (本書 §5 が設計仕様)。

## 6. マルチリージョン / マルチクラウドの判断 (正直な結論)

**現段階 (無料 MVP / 有料 0 顧客) では常時マルチリージョン構成は採らない。** 理由: コスト・運用負荷が現規模に対して過剰 (原則 6・9) で、§3 の「復元できる」体制の方が費用対効果が高い。再評価トリガ = `paying-100` 達成 or 有償 SLA を顧客と契約するとき ([`B2B_PROPOSAL_V1.md`](B2B_PROPOSAL_V1.md) §4 の回答とも整合)。Issue の「マルチリージョン・フェイルオーバー戦略」への回答 = **「コールドスタンバイ (バックアップ + 別リージョン復元手順) を正とする」が本 v1 の戦略決定**。

## 7. 運用接続

| 何を | どこへ |
|------|--------|
| バックアップ状況 | [backup / restore runbook](SUPABASE_BACKUP_RESTORE_RUNBOOK.md) + `supabase-backup-restore.yml` の週次証跡 |
| restore drill | backup runごとにephemeral targetへ復元。実replacement project drillは別途CEO承認 |
| 障害発生時 | [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) (Sev 判定 → 対応) — 本書は予防/復旧設計 |
| Phase A/B 実装 | Issue #2599 (open 維持) → L2 |

## 8. Philosophy Alignment ([`PHILOSOPHY.md`](PHILOSOPHY.md))

原則 1 (PITR 加入・drill 日程・保管先 = CEO 決裁) / 原則 4 (6 部署 = 全部署のデータを守る土台) / 原則 6 (現規模に過剰な常時冗長を避ける = 時間・資本) / 原則 7 (データ = 取り返せない資産 → バックアップ優先順位 1 位 / 未検証手順を実証済みと言わない = 信頼) / 原則 8 (復旧可能性を KPI 化: drill 成否・バックアップ鮮度) / 原則 9 (持続可能な運用負荷)。**7+/9 ✅**。

## Links

- [Issue #2599](https://github.com/kanta13jp1/my_web_app/issues/2599) — 受入基準 / 基準 3 の実装 handoff (open)
- [`PRODUCTION_MONITORING_RUNBOOK.md`](PRODUCTION_MONITORING_RUNBOOK.md) / [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) / [`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) — ops 三部作 (検知・対応・リリース)
- [`AI_FALLBACK_RUNBOOK.md`](AI_FALLBACK_RUNBOOK.md) — S4 の既存緩和
- [`IT_SECURITY_POLICY_V1.md`](IT_SECURITY_POLICY_V1.md) — S5 / 鍵・端末・棚卸し
