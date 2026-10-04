# MUSUBI release gates

## Gate 0: safety

- `AGENTS.md` とsession checkを確認する。
- rootがdirtyなら、ユーザー変更へ混ぜず専用worktreeを使う。
- メモリ90%以上ではFlutter/Dart build・test、Docker、worktree追加、pushを開始しない。
- checkpointとGitの現在状態が一致することを確認する。

## Gate 1: implementation

- ユーザー価値、データモデル、権限境界、失敗時挙動を定義する。
- UI、Logic、Dataを分離する。
- RLSを本人・相手・公開範囲・管理者ごとに検証する。
- 楽観更新は失敗時に復元する。

## Gate 2: local proof

- 変更Dartファイルのformatとanalyzeが成功する。
- 変更ロジックのunit/widget testが成功する。
- MUSUBI関連回帰テストが成功する。
- `python scripts/check_migration_timestamps.py` が成功する。
- migration固有テストが成功する。
- Dockerが動く場合だけローカルDB lintを追加する。共有DBをresetしない。

## Gate 3: staging readiness

次のGitHub Actions secretsが存在することを、名前だけで確認する。

- `SUPABASE_PROJECT_ID_STAGING`
- `SUPABASE_URL_STAGING`
- `SUPABASE_ANON_KEY_STAGING`
- `SUPABASE_DB_PASSWORD_STAGING`
- `SUPABASE_ACCESS_TOKEN`
- `FIREBASE_SERVICE_ACCOUNT_STAGING`
- `FIREBASE_PROJECT_ID`

名前の存在だけではProductionとの分離を証明できない。Supabase dashboardでproject refとURLを確認し、Productionと異なることを人間が確認する。値をチャットやログへ貼らない。

`.github/workflows/deploy-staging.yml` を正規経路として使い、次を証拠にする。

- migration step成功
- Flutter web build成功
- Firebase staging channel URL
- staging smoke test結果

## Gate 4: staging validation

- 専用stagingテストユーザーだけを使う。
- JWTを環境変数または一時的なsecret storeへ入れ、コマンド出力や履歴へ残さない。
- 小規模warm-upから開始し、同時数を段階的に上げる。
- 成功率、エラー率、p50/p95/p99、Realtime受信時間を記録する。
- Chromeと別製品ブラウザーで2アカウント検証する。
- DM参加者は読める、第三者は読めない、未認証は読めないことを確認する。

## Gate 5: cohort

- 募集先が指定されている。
- 人数は5〜8名である。
- 検証目的、期間、データの扱い、問い合わせ先が明記されている。
- 外部送信前に宛先と最終文面が承認されている。

## Gate 6: production

次のGitHub Actions secretsが存在することを、名前だけで確認する。

- `SUPABASE_PROJECT_ID_PROD`
- `SUPABASE_URL_PROD`
- `SUPABASE_ANON_KEY_PROD`
- `SUPABASE_DB_PASSWORD_PROD`
- `SUPABASE_ACCESS_TOKEN`
- `FIREBASE_SERVICE_ACCOUNT_PROD`
- `FIREBASE_PROJECT_ID`

さらに次を満たす。

- ユーザーがmainマージ・本番デプロイを明示的に承認した。
- PRレビューと必須CIが成功した。
- staging migration、smoke、負荷試験、2ブラウザー検証の証拠がある。
- `.github/workflows/deploy-prod.yml` を使用する。
- 本番に負荷試験を向けない。

## Gate 7: completion evidence

- merge commitまたはPR URL
- deploy workflow run URLと成功状態
- production URLのsmoke test
- migration適用結果
- 未完了の手動作業と回復手順

どれかが欠ける場合は「本番完了」と報告しない。
