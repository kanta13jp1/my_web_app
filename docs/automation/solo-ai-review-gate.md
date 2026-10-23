# 1人開発の AI Review Gate

所有者が2026-10-23に承認した運用変更。PR作者自身の承認を偽装せず、
GitHub Actions app (15368) の `AI Review Gate` 必須checkを技術レビューの条件にする。
人間の承認人数を0へ変更しても、既存4必須CIとstrict更新要件は保持する。
マージ・本番公開の意思決定は所有者にあり、このworkflowはマージもデプロイもしない。
認証、DB/RLS、課金、外部公開、権限、秘密情報、一括実行の変更では、AGENTS.mdの
明示的な人間の確認を引き続き記録する。チャットでの承認をPRへ記録できる。

## 証拠と拒否条件

既存 `claude-agent-review.yml` の通常レビューを置換する。
既存のredactor、high-risk契約、任意ultrareview、レビュー指摘のroutingを再利用する。
Claude/Codexの有料停止設定は変更しない。Gemini APIの構造化応答を独立して検証する。
`AI_REVIEW_MODEL`（初期値 `gemini-3.8-flash`）は実行時ListModelsで
generateContent対応を確認する。未対応なら失敗する。別モデルへの無言の代替はない。

- 全変更ファイルと省略しないdiffを読み、正確なhead SHA、base SHA、入力SHA-256を固定する。
- 40ファイル、240,000バイトを超えたPR、非対応拡張子、バイナリ、symlink/submodule、
  private recordパスを拒否する。分割またはレビュー済みの対応拡張が必要。
- 生diffをartifactやログへ出さない。既存の秘密値redactorと通貨額redactionを通す。
- 各ファイル、correctness/security/testsの評価、指摘、構造化verdictを要求する。
  LGTM文字列、空応答、打切り、API障害、不足coverageは合格にならない。
- high/critical/mediumの指摘は必ずblocking。指摘解消後に新headを再レビューする。
- 成功公開直前にPRを再取得し、head/baseの移動を拒否する。
  main変更後はstrict CI条件を満たす最新ブランチへ更新して再レビューする。
- JSON artifactにモデル、応答ID、usage、応答hash、head/base、ファイル別評価と指摘を保持する。
  check詳細のActions runから確認する。PR reviewのAPPROVEDを捏造しない。

## 実行境界

pull_request_targetはmainのworkflowとスクリプトだけを実行する。
PRのコミットはgit diffのデータとして取得し、checkout/build/install/実行しない。
AIにツールを与えず、diff内の命令はデータとして扱う。GitHub tokenとGemini keyは別stepで渡す。
GitHub権限はcontents/read、pull-requests/read、checks/writeのみ。
同一repoの信頼済み作者のPRは自動レビュー、外部PRはmaintainerの手動dispatchが必要。
check名とworkflow job名を分け、skipされたjobが必須checkを満たさないようにする。
PR契約jobとsecret付きレビューのconcurrencyも分離する。

再実行: `AI Agent PR Review` をmainからdispatchし、pr_numberを指定する。
資格情報、モデル、上限、レビュー指摘の原因を修正してから再実行する。
キャンセルや途中障害でcheckがpendingのままでも、マージは許可されない。

## 初回移行手順と復旧

1. 元のmain保護ルールと個別required_pull_request_reviews endpointをVault外へ保存。
   full protection応答はreview設定を省略することがあるため個別endpointも必須。
2. 専用codex branchの実装を確認し、`AI_REVIEW_BOOTSTRAP_SHA` をその正確なSHAに固定。
   ai-review-production環境へそのbranchだけを一時許可。既存workflowをそのbranchで手動実行。
   この管理者限定の一時設定以外では、main以外の資格情報付きレビューは実行しない。
3. 単体テスト、実モデルレビュー、対象headのAI check、既存CIの成功を確認する。
4. `AI Review Gate` / app15368 を既存必須CIへ追加して読み戻す。
   その後だけ、人間required_approving_review_countを0へ変更する。
   人間承認もAI checkもない隙間を作らない。admin bypassを使わず通常マージする。
5. マージ後にmain由来の実レビューを確認し、bootstrap変数と一時環境branch許可を削除する。
   deploy-prod.ymlのdisabled_manuallyは保持する。

途中で実レビューが失敗した場合は人間承認1を維持し、原因を記録する。
移行後に戻す場合は先に人間承認1を復元してからAI必須checkを外す。
生産物公開とグローバル自動デプロイの再開はこの変更の範囲外。

## 検証

`python -B scripts/ai_review_gate_test.py` はhead/base更新、未完成/矛盾した結果、
不完全coverage、API障害、非対応/非公開入力で成功checkを出さないことを検査する。
モデルを呼び出す実証はActionsで行い、実PRのheadとbaseを記録する。

一次資料: [GitHub pull_request_target security](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target)、
[Checks API](https://docs.github.com/en/rest/checks/runs)、
[Gemini Models](https://ai.google.dev/api/models)、
[Gemini structured outputs](https://ai.google.dev/gemini-api/docs/structured-output)。
