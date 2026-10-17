---
name: musubi-social-release-pipeline
description: MUSUBIのFlutter/Supabase製SNS機能を、既存変更の保護、段階実装、RLS・Realtime・DM検証、staging migration、専用JWT負荷試験、2ブラウザー実機確認、第1ユーザー募集、mainマージ、本番デプロイまで安全に進める。MUSUBIの機能追加・改善・再開、staging復旧、リリース、負荷試験、SNS品質向上を依頼されたときに使用する。
---

# MUSUBI Social Release Pipeline

MUSUBIをXと並ぶSNSへ段階的に近づける。各段階で、ユーザー価値、永続化、安全性、運用可能性、検証証拠を同時に前進させる。

## 1. 開始と再開

1. リポジトリの `AGENTS.md` を読む。
2. `session-start-check` を実行し、ブランチ、dirty paths、近接worktree、並行作業を確認する。
3. 次を実行する。

   ```powershell
   python .agents/skills/musubi-social-release-pipeline/scripts/preflight.py --environment local
   python .agents/skills/musubi-social-release-pipeline/scripts/checkpoint.py show
   ```

4. メモリ使用率が90%以上なら、worktree作成、Flutter/Dartの解析・テスト・ビルド、Docker、Git pushを開始しない。編集内容と再開地点を保存し、負荷低下を待つ。
5. 既存のdirty treeへ混ぜない。通常は `origin/main` から `codex/` 接頭辞の専用worktreeを作る。固有パスへの軽量な新規ファイル作成だけが安全で、かつ資源制約によりworktreeを作れない場合は、その判断を明示する。
6. checkpointの内容を記憶ではなく現在のGit・CI・実行環境と照合してから再開する。

## 2. 次の改善単位を選ぶ

X級SNSへ必要な中核ループを優先する。

1. 投稿作成・閲覧・リンク・メディア
2. 共鳴、返信、再共有、保存、フォローの永続化
3. 検索、通知、DM、Realtime
4. 不正対策、通報、モデレーション、プライバシー
5. オンボーディング、アクセシビリティ、レスポンシブUI
6. 観測性、負荷耐性、継続率、実ユーザー検証

1回の改善単位で少なくとも次を成立させる。

- ユーザーが認識できる価値を追加する。
- FlutterのUI、Logic、Data層を分離する。
- Supabase永続化とRLSを必要に応じて追加する。
- 失敗、二重操作、再読み込み、権限境界を扱う。
- 狭いテストだけで広い完成を主張しない。

Flutter構造変更では `flutter-apply-architecture-best-practices`、リリース全体では `flutter-feature-release-pipeline`、新規ロジックでは該当するDart/Flutterテストスキルを併用する。

## 3. 実装とローカル検証

1. 既存モデル、repository、controller、page、migration、テストを検索してから編集する。
2. UIからSupabaseを直接呼ばない。UI → controller/ViewModel → repository → serviceの方向を保つ。
3. migrationではRLSを有効にし、匿名、認証済み本人、相手ユーザー、管理者の境界を明示する。
4. 楽観更新を使う場合は、失敗時ロールバックと同時操作抑止を実装する。
5. 対象ファイルのformat、analyze、unit/widget testを先に実行する。資源が十分な場合だけ範囲を広げる。
6. migration timestamp衝突とSQL構造テストを実行する。Dockerが利用可能なら共有DBをresetせずローカルDB lintを実行する。
7. ブラウザー表示が変わる場合は、desktopとmobile幅、リンク、キーボード操作、エラー表示を確認する。

検証結果をcheckpointへ保存する。

```powershell
python .agents/skills/musubi-social-release-pipeline/scripts/checkpoint.py set `
  --phase local-validation --status passed `
  --summary "対象解析とMUSUBI回帰テストが成功" `
  --evidence "dart analyze: pass" `
  --evidence "flutter test: pass" `
  --next-action "staging secrets gate"
```

## 4. stagingゲート

外部操作前に [references/release-gates.md](references/release-gates.md) を読む。人間の操作が必要な場合は [references/manual-validation.md](references/manual-validation.md) を読む。

1. GitHub Secretsの名前だけを確認し、値を表示しない。

   ```powershell
   python .agents/skills/musubi-social-release-pipeline/scripts/preflight.py `
     --environment staging --check-github-secrets
   ```

2. staging用Supabase project ref、URL、anon key、DB passwordがProductionと異なることを、人間の確認または値を露出しない検証で証明する。
3. migrationとhosting deployは `.github/workflows/deploy-staging.yml` を正規経路として使う。ローカル端末からProduction projectへlinkしない。
4. stagingサイトのsmoke test後、専用stagingユーザーJWTだけで負荷試験する。Productionまたは実ユーザーJWTを使用しない。
5. 負荷試験は小さな段階から増やし、エラー率、p50/p95/p99、Realtime遅延、DB/Edge Function制限を記録する。
6. Chromeを含む異なる2製品ブラウザーと2テストアカウントでRealtimeとDM RLSを検証する。

## 5. 第1コホート

1. X、Slack、メール、既存コミュニティなど、募集先をユーザーに指定してもらう。
2. 5〜8名向けの短い募集文、検証項目、同意事項、問い合わせ先を準備する。
3. 文案作成までは自動化してよい。外部への投稿・送信・招待は、宛先と最終文面への明示的承認後だけ実行する。
4. 実ユーザー検証では個人情報を最小化し、DM内容やJWTをログ・Issue・checkpointへ保存しない。

## 6. mainマージと本番リリース

1. ユーザーがmainマージまたは本番デプロイを明示的に依頼したことを確認する。
2. PR差分がMUSUBIの改善単位だけであること、レビューと必須CIが成功したこと、staging証拠が揃ったことを確認する。
3. Production secretsを名前だけ確認する。

   ```powershell
   python .agents/skills/musubi-social-release-pipeline/scripts/preflight.py `
     --environment production --check-github-secrets
   ```

4. branch protectionを回避しない。正規PRをmainへマージし、`.github/workflows/deploy-prod.yml` を監視する。
5. Production migrationを手動の `supabase db push` で先行適用しない。
6. 本番smoke testでルート表示、認証、投稿、対象機能、エラーログを確認する。負荷試験を本番へ向けない。
7. 失敗時は新しい破壊的操作を重ねず、workflowログ、適用済みmigration、hosting releaseを確認して回復手順を提示する。

## 7. 証拠と引き渡し

次を区別して報告する。

- 実装済み
- ローカル検証済み
- staging検証済み
- mainへマージ済み
- 本番デプロイ済み
- 人間の手動確認待ち

未検証項目を成功扱いしない。各ゲートのartifact、workflow run、URL、テスト件数、実測値を証拠として示す。終了または中断時はcheckpointへ現在地、証拠、blocker、次の1操作を保存する。

## 安全不変条件

- Secrets、JWT、DB password、service-role keyを出力・コミット・checkpoint保存しない。
- Productionとstagingの識別が曖昧な状態でmigration、負荷試験、募集を進めない。
- `git reset --hard`、ユーザー変更のstash、共有ローカルDBのresetを行わない。
- 実ユーザーや外部チャネルへの送信は明示的承認なしに行わない。
- リソース逼迫時は速度よりデータ保全を優先する。
- 「Xと並ぶSNS」という最終目標を、小さなテストの成功へ縮小しない。
