# ブランチ保護設定ガイド

対象要件: [#1284](https://github.com/kanta13jp1/my_web_app/issues/1284) と
[#1286](https://github.com/kanta13jp1/my_web_app/issues/1286)。
この文書は設定変更の承認ではない。以下の目標と観測値を混同しない。

## 現在の観測値（2026-09-06、読み取り専用監査）

mainのAPI状態は承認要件未設定、admin強制・署名必須・リニア履歴が無効。
rulesetsは空、CODEOWNERSは未配置、collaboratorはowner/admin 1名のみ。
必須status checksはstrict=trueで、次の実際のcheck名を参照している。

| Check名 | 意味 |
| --- | --- |
| Lint, Format, and Test | 変更範囲に応じたCI |
| Security Check | セキュリティ方針検証 |
| PR minimal E2E declaration | E2E宣言のゲート |
| Public E2E stability smoke | 条件付きpublic E2E |

これは監査時点の値であり、設定実施済みという宣言ではない。
ジョブIDをcheck名として登録しない。存在を確認していないbuild-matrix等を
必須化するとマージ待ちが解消しない。check成功やskipだけで未実行の
Flutter解析・認証E2E・ビルドが通ったとは判断しない。

## 要求される最終状態

- mainへの直接pushを拒否し、PR経由の統合を必須にする。
- 独立レビュアーの承認を1件以上必須にする。重要ファイルとCODEOWNERS自身を
  所有者に割り当て、Code Ownerの承認も必須にする。
- 管理者や自動処理も要件を迂回できないようにする。
- 検証済み署名を要求し、リニア履歴を強制する。
- force-pushとブランチ削除を禁止し、必要な品質ゲートを維持する。

個人プロジェクトだから承認0件でよい、署名は任意でよい、という旧案は
これらのIssueを満たさない。main以外の維持対象ブランチはownerが先に確定する。
staging/develop/masterの保護状態をmainから推測しない。

## 有効化前の必須条件

1. ownerが独立したwrite権限レビュアーまたは適切なチームを指定する。
   PR作成者自身の承認を代替にしない。招待・権限付与は別途承認を得る。
2. CODEOWNERSの対象・所有者・可視性と実効アクセスを確認する。
3. 人間・bot・Actions・外部APIを含む全publisherを棚卸しする。
   [署名付きリモートコミット手順](REMOTE_SIGNED_COMMITS.md)は候補の一つ。
   一つの検証済みコミットだけで全経路の互換性を証明したとは扱わない。
4. unsignedな既存PR、squash/rebaseの署名挙動、必須checkの実名と発火条件を検証する。
   他者の履歴を書き換えて署名要件を満たしたことにしない。
5. 非本番の検証対象で直接push拒否、未承認・未署名PR拒否、
   承認済み署名付き変更の取り込み、リニア履歴を実証する。
6. 現在の設定を保存し、復旧担当・復旧条件を記録する。
   ownerの明示レビュー後に本番設定を適用し、API状態と拒否/成功例を再確認する。

## 自動処理との関係

workflow_dispatchは起動方法であり、ブランチ保護の例外や人手承認の代わりではない。
生成物の更新も、適切な署名付きブランチ・PR・承認・CIの経路へ移す。
自動処理を動かすためだけにadminやbotのバイパスを追加しない。
既存publisherが対応できない場合は、設定を黙って弱めず未達条件として報告する。

## 公式資料と関連文書

- [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [CI/CD Setup Guide](../CICD_SETUP_GUIDE.md)
- [CI/CD Pipeline Guide](CI_CD_GUIDE.md)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)
