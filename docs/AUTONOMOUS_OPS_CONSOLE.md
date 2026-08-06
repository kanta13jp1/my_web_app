# OMOCHA WORKS 自律オペレーションコンソール — 実データ設定

`/autonomous-ops`(自律オペレーションコンソール)は、既定では演出用の
シミュレーションを表示する。**ログイン済みオーナー**に対しては、GitHub
Actions の実行状況を実データとして表示できる。本書はその有効化手順。

## アーキテクチャ

```
Flutter (page)  ──invoke──▶  Edge Function: autonomous-ops  ──▶  GitHub REST
  owner のみ                   (owner 認証 + 30s cache)            list workflow runs
  ~20s poll                    GH_ACTIONS_READ_TOKEN (server-side)
```

- 実データは **オーナー限定**(EF が `user_profiles.is_admin` を検証)。
  未ログイン / 非オーナー / 通信失敗時はシミュレーションにフォールバックする
  ため、公開訪問者に run 情報は出ない。
- GitHub トークンは Function Secret からサーバ側でのみ使用し、レスポンスや
  クライアントには一切含めない。
- EF は GitHub 応答を約 30 秒キャッシュし、Flutter は約 20 秒間隔でポーリング
  する(タブ非アクティブや一時停止中はポーリングを止める)。フェッチ間は
  スパークラインのアニメで"動き"を維持する。

## セットアップ(オーナーが実施)

### 1. fine-grained PAT を発行

GitHub → Settings → Developer settings → **Fine-grained personal access tokens**

- **Repository access**: `kanta13jp1/my_web_app` のみ
- **Permissions**:
  - `Actions` → **Read-only**
  - `Metadata` → **Read-only**(必須の既定)
- 有効期限は最長 1 年。切れたら再発行して Secret を更新する。

> read-only + 単一リポジトリの最小権限。書き込み権限は付与しない。

### 2. Supabase Function Secret に登録

```bash
supabase secrets set GH_ACTIONS_READ_TOKEN=github_pat_xxxxx
```

- 既存の `GITHUB_PAT` があればフォールバックとして利用されるが、最小権限の
  専用トークン `GH_ACTIONS_READ_TOKEN` の利用を推奨。
- 対象リポジトリを変える場合は `GITHUB_REPO`(既定 `kanta13jp1/my_web_app`)
  も設定する。

### 3. EF をデプロイ

`autonomous-ops` は `deploy-prod.yml` のデプロイ一覧に含まれる
(`--no-verify-jwt` で配信し、認証は本体で実施)。通常の本番デプロイで反映される。

## 挙動の確認

1. オーナーアカウントでログインして `/autonomous-ops` を開く。
2. ステータスバーが **「実データ · GitHub Actions」** になれば成功。
3. トークン未設定の場合は「シミュレーション · トークン未設定」と表示され、
   演出モードのまま動作する(壊れない)。

## レーン写像(実データ時)

run に「レビュー」状態は無いため、レビュー列は **queued(実行キュー待ち)** を
読み替えて表示する。

| カンバン列 | GitHub run |
| --- | --- |
| バックログ | requested / waiting |
| レビュー | queued(キュー待ち) |
| 進行中 | in_progress |
| 完了 | completed(直近) |

- エージェント(HAYATE/KANNA/MIYA/BOLT/SHIORI)は固定の 5 体。各 run を
  ワークフロー名のキーワード、非該当時は名前ハッシュで決定的に割り当てる。
- KPI の「完了タスク数 / 自動化実行時間 / SLA(成功率)/ スループット」は実データ
  由来。「売上インパクト」は GitHub に相当データが無いため、完了数に基づく
  **演出値**(実売上ではない)。
- 「システム状態(CPU / メモリ / クォータ)」は相当データが無いため当面
  シミュレーションのまま。

## 関連ファイル

- EF: `supabase/functions/autonomous-ops/`(`index.ts` / `transform.ts` / `transform_test.ts`)
- サービス: `lib/services/autonomous_ops_service.dart`
- ページ: `lib/pages/autonomous_ops_console_page.dart`
- テスト: `test/services/autonomous_ops_service_test.dart`
