# 外部依存サービス障害のエスカレーション・トラブルシューティング手順書

対象: Issue #2769。公式情報の確認日: 2026-11-26（各 URL は同日に HTTP 200 を確認）。
本書は手順書であり、実アカウントでの設定変更・問い合わせ送信・通知購読・AI 利用を
実施した証拠ではない。画面や提供条件は変わり得るため、使う当日にリンク先を再確認する。

## 位置づけ（既存正本との関係）

本書は既存の運用文書を置き換えず、不足していた「外部依存サービスの障害時の見分け方と相談先の選び方」だけを補う。

| 既存文書 | 担当範囲 | 本書での扱い |
| --- | --- | --- |
| [`ONCALL_INCIDENT_SOP.md`](./ONCALL_INCIDENT_SOP.md) | 重大度（SEV1〜3）・一次対応 6 ステップ・通信規律・Postmortem | 重大度と通信経路はこの文書に従う（再定義しない） |
| [`PRODUCTION_MONITORING_RUNBOOK.md`](./PRODUCTION_MONITORING_RUNBOOK.md) | 自動監視の定常運用 | 検知後に本書へ接続する |
| [`FIREBASE_SUPPORT_GUIDE.md`](./FIREBASE_SUPPORT_GUIDE.md) | Firebase の切り分け・相談先・Gemini in Firebase | Firebase 固有手順はそちらを正本とし、重複記載しない |

## 1. 依存サービスと公式 Status ページ

このリポジトリが障害の影響を受ける外部依存は次の 3 系統。
障害を疑ったら、**自分たちの変更を疑う前に**該当ページを確認する（所要 1〜2 分）。

| 依存 | 影響を受ける機能 | 公式 Status | 確認日の表示内容（要点） |
| --- | --- | --- | --- |
| Supabase | 認証・Postgres・Edge Functions・API | [Supabase Status](https://status.supabase.com/) | Auth などのコンポーネント別稼働率とリージョン別一覧、「Subscribe to updates」「Report a problem」が表示されていた |
| Firebase | Hosting（本番配信）ほか | [Firebase Status Dashboard](https://status.firebase.google.com/) | 手順の詳細は [`FIREBASE_SUPPORT_GUIDE.md`](./FIREBASE_SUPPORT_GUIDE.md) |
| GitHub | Actions（CI・デプロイ）・Issues | [GitHub Status](https://www.githubstatus.com/) | 「Subscribe to Updates」（メール通知・テキストメッセージ通知の案内）が表示されていた |

- 通知の購読方法・対象コンポーネントの選択は各ページの表示に従う。購読の実施有無は本書では保証しない
  （実際に購読したら担当者と日付を Issue に残す。未実施なら「未購読」と書く）。
- Status ページに掲載がないことは正常の証明ではない。掲載が遅れる場合がある前提で、自前の検知結果と照合する。
- 自前の死活監視は `.github/workflows/health-monitor.yml`（結果は `docs/health-status.json` /
  `docs/infra-status.json`）。Status ページと自前監視が食い違う場合は、両方の時刻を Issue に記録する。

### 障害共有と初期対応（チェックリスト）

1. **検知**: 自動監視・Sentry・利用者報告のいずれかで異常を確認し、発生時刻（タイムゾーン付き）を記録する。
2. **Status 確認**: 上表の該当ページを開き、インシデントの有無・影響コンポーネント・更新時刻を控える。
3. **重大度判定**: [`ONCALL_INCIDENT_SOP.md`](./ONCALL_INCIDENT_SOP.md) §1 で SEV1〜3 を決める。迷ったら一段上に倒す。
4. **共有**: SEV1/2 は GitHub Issue を起票する。下記 §2 のカテゴリ別フォームを使う。
   時限アラート・mobile push は SOP §6 の経路に従う。
5. **封じ込め**: 外部障害が原因と見込まれる場合、設定変更・課金変更・IAM/RLS の緩和で「回避」しない。
   データ破壊系の操作（`DELETE` / `DROP` / `TRUNCATE`）は封じ込め中は禁止（SOP §4 Step 3）。
6. **復旧確認**: ベンダーの解消表示だけで完了にしない。元の操作が成功することと影響範囲を確認して Issue に残す。
7. **記録**: SEV1/2 は SOP §7 のテンプレートで [`incident-reports/`](./incident-reports/) に残す。

## 2. 問題カテゴリ別の Issue フォームとラベル規則

Firebase Support の「問題のカテゴリを選ぶ」方式にならい、問題の性質で 4 分類したフォームを用意する。
`.github/ISSUE_TEMPLATE/config.yml` の `blank_issues_enabled: false` は維持する。

| カテゴリ | フォーム | 自動付与ラベル（既存ラベルのみ） | 主な対象 |
| --- | --- | --- | --- |
| 認証 | `incident_auth.yml` | `bug` `supabase` | ログイン・セッション・MFA・OAuth・アカウント操作 |
| データベース | `incident_database.yml` | `bug` `supabase` | クエリエラー・RLS 拒否・マイグレーション・性能 |
| フロントエンド | `incident_frontend.yml` | `bug` `flutter-web` | 画面表示・操作不能・Flutter Web のビルド/配信後の不具合 |
| インフラ | `incident_infra.yml` | `bug` `infra` | Hosting・Edge Functions 配信・CI/CD・ドメイン・クォータ |

ラベル運用の規則:

- フォームが自動付与するのは上表の既存ラベルだけにする。GitHub の公式仕様では、リポジトリに存在しないラベルは
  フォームに書いても自動付与されない（確認日 2026-11-26、[Issue フォームの構文](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)）。
- カテゴリはタイトル接頭辞（`[Incident][Auth]` など）とフォームの本文で判別する。専用ラベル
  （例: `incident:auth`）を作る場合は、リポジトリ設定の変更になるため所有者の承認後に別途行う。
- 重大度ラベルは起票後に担当者が付ける（フォームは条件付きラベル付与に対応しない）。
  既存の `priority:critical` / `priority:high` / `priority:medium` を使い、SEV1→`priority:critical`、
  SEV2→`priority:high`、SEV3→`priority:medium` を目安とする。
  `severity:*` は機能レビュー自動化が使うラベルなので、障害の重大度には使わない。
- 認可・秘密情報に関わる疑いがあれば、担当者が `security` ラベルを追加し、公開 Issue に詳細を書かない
  （SOP §6: token / secret / service_role key の記載禁止）。

## 3. 段階的な調査ガイドライン

調査は **下の段から順に**進め、各段で「何を確認し、何が分からなかったか」を Issue に残す。
時間の目安は本リポジトリの運用上の目安であり、公式の基準ではない。

| 段 | 手段 | 目安 | やること |
| --- | --- | --- | --- |
| 0 | 自前の情報 | 〜15 分 | §1 の Status 確認、直近のデプロイ・CI 結果、Sentry/ログ、既存 Issue・`incident-reports/` の検索 |
| 1 | 公式ドキュメント・ナレッジ | 〜30 分 | Supabase は [Knowledge Base のトラブルシューティング](https://supabase.com/kb/topics/troubleshooting)、Firebase は [`FIREBASE_SUPPORT_GUIDE.md`](./FIREBASE_SUPPORT_GUIDE.md) の導線、GitHub Actions は公式ドキュメント |
| 2 | コミュニティ | 〜1 時間 | Supabase は [Support ページ](https://supabase.com/support)（コード関連は Discord、機能要望は [GitHub Discussions](https://github.com/orgs/supabase/discussions)）。Firebase はガイド記載の Stack Overflow / Reddit。最小再現例を匿名化して投稿する |
| 3 | AI 支援 | 随時（各段と併用可） | Firebase は Gemini in Firebase（有効化条件はガイド参照）。他の AI も使えるが、下記の制約を守る |
| 4 | 外部サポートへの問い合わせ | 下記の基準を満たしたとき | Supabase は [Support ページ](https://supabase.com/support)の「Open support ticket」、Firebase はガイドの「submit a support case」 |

AI 支援の制約:

- 質問には個人情報・鍵・トークン・実ユーザーの記録・内部の識別子を含めない。匿名化した架空データで再現する。
- 回答中の URL・API 名・設定値は公式ドキュメントで必ず裏取りする。AI の回答だけで本番変更や完了判定をしない。
- 認証・権限・RLS・課金に関する変更案は、AI の提案であっても人のレビューを必須にする。
- 各ベンダーの AI 支援機能の提供条件・料金は変わり得るため、使う前に当日の公式案内を確認する
  （Supabase 側の AI 支援機能の有無・条件は本書では未確認）。

### 外部サポートへの問い合わせ（チケット）基準

次のいずれかに該当し、かつ段 0〜2 を実施済みの場合に、チームで内容を確認してから問い合わせる。

1. 公式 Status に該当がなく、自分たちの変更や設定を切り戻しても最小再現手順で再現する（ベンダー側の不具合が疑われる）。
2. データ欠損・予期しない削除・セキュリティ上の懸念・請求や契約に関わる問題（公開の場で相談しない）。
3. プロジェクト固有の状態（停止・制限・クォータ・アカウント権限）で、公開情報やコミュニティでは解決できない。
4. SEV1 が継続し、ベンダー側の操作なしに復旧できない。

問い合わせ前に必要な準備:

- 送信者と送信内容をチームで確認する。ケース番号・回答・次の確認日を元の Issue に戻す。
- 問い合わせメモの項目は [`FIREBASE_SUPPORT_GUIDE.md`](./FIREBASE_SUPPORT_GUIDE.md) のメモを共通で使う
  （対象サービス・発生時刻・期待/実際の動作・最小再現・秘匿情報を除いたログ・Status 確認結果・試した対処）。
- Supabase の Support ページには「サポートチケットの応答時間はプランと重大度によって変わる」との記載がある。
  プラン別の具体的な応答時間は本書では未確認であり、契約中のプランの条件を公式画面で確認する。

## 4. 情報の取り扱い

- 公開 Issue・コミュニティ投稿・AI への質問に、API キー・トークン・JWT・ワンタイムコード・Cookie・
  サービスアカウント鍵・メールアドレス・実ユーザーの健康/金融記録を貼らない。
- ログは秘匿情報を除いた最小限を貼る。証拠は保持し、全文を無条件に転載しない。
- 請求・アカウント情報は公開の場で相談しない。

## 5. 受入条件との対応と未確認事項

| 受入条件（Issue #2769） | 対応箇所 |
| --- | --- |
| Status Dashboard の監視と、障害時の共有・初期対応がマニュアル化されている | §1 |
| 問題の性質に応じたラベル規則と専用のバグ報告テンプレートがある | §2 と `.github/ISSUE_TEMPLATE/incident_*.yml` |
| 公式ドキュメント・コミュニティ・AI 支援を段階的に使う調査ガイドラインがある | §3 |

未確認・未実施（本 PR のスコープ外）:

- Status ページの通知購読、Supabase/Firebase の実アカウントでのサポート画面の操作、チケット送信は実施していない。
- 専用ラベル（`incident:*` など）の作成は行っていない（所有者の承認が必要）。
- GitHub 上での Issue フォームの実表示確認は、マージ後に Issue 作成画面で確認する。

## 6. 改訂履歴

| 日付 | 変更 |
| --- | --- |
| 2026-11-26 | 初版（Issue #2769）。Supabase / Firebase / GitHub の公式 Status 確認、カテゴリ別 Issue フォーム、段階的調査ガイドラインを追加。 |
