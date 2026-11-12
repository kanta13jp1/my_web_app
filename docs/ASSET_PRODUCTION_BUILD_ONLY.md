# 資産UI修正のproduction構成 BUILD ONLY

このpackageはレビュー用の未実行候補です。workflowのdefault branch登録、通常PR必須CI、コード・実行枠の具体的な本人確認は未完了です。登録・承認前に新workflowを実行しないでください。package作成時はGitHubへの登録、認証、SDK起動、production build、artifact uploadを行っていません。

製品sourceは `fa36e621ea0e445cdfb3b8d145c85184e874685a`、treeは `81d247963dd8e1fd6df0543e3adc2e5acf0caca3`、既存非本番fullはrun `43176832528` / attempt1です。公開基点はcommit `399586d0eeda65f157819e21a5b2e47409b7e2ba` / version `1.0.2278` / build `5836`。新sourceは本番未反映です。非本番CI成功をproduction構成のbuildや配信成功とは扱いません。

## 構成と実行前の条件

- `.github/workflows/asset-production-config-build-only.yml` はworkflow_dispatchだけ。contents/actionsはreadのみ、45分、concurrencyのcancelはfalseです。既存deployやholdを変更しません。
- `scripts/asset_production_build_guard.py` はowner/source/controller/CI検査、生成ファイル準備、bundle sealを担当します。controllerのapproved assets参照は `control/docs/asset-release-build-only/approved-assets/` です。
- 同approved-assetsのcatalog、release-notesは固定bytesで同梱します。preflightはCRLFをLFへ正規化し、元コードとのAST一致を確認した版を固定します。元SHA256は `97dd66c482b2130b49f0740247aeabc37460f0067a1ebb47a2776f94cba9d24e`、同梱版は `48ffae2687b5f65b8df914cb645a45c326f5d019f4db8e8c7b3c2da926a49055` です。実行時には同梱版のhashへ厳密照合します。catalogはprovider count368の保存snapshotで、provider DB fetch helperは実行しません。release-notesは既存公開JSONの保持で、新releaseの履歴承認ではありません。
- `scripts/asset_production_build_guard_test.py` は標準unittestのみのofflineテストです。Git/API/auth/build subprocessを実行せず、tiny temporary filesとvirtual sizes、mockで境界を確認します。テストは実行結果JSONをrepoへ保存しません。既存ci.ymlのPython policy検査へ `python -m unittest scripts/asset_production_build_guard_test.py` を1行追加し、通常CIから実行する構成です。

製品をworkspaceルートへ固定sourceで先にcheckoutし、controllerをcontrol/へ固定workflow SHAでcheckoutします。sourceにcontrol pathがないことを検査します。controller本人性はGitHubのworkflow SHAとexpected_controller_shaの一致に結合し、入力はenv経由で渡します。product local actionは既存のままで、Flutter3.38.10とarena内包Node22の手順を保持します。SDK/cache/dependency全体のsupply-chain証明ではありません。

guardのverifyがowner recordと固定CI/public基点を検証するまで、production secretを参照するstepへ進みません。許可する既存設定はブラウザー向けSupabase URL/public publishableまたはanon keyとPostHog token/hostだけです。Firebaseサービスアカウント、service_role、DB access token、Hosting権限は含めません。DB/Auth/RLS/Edge、通知、tag/releaseを変更しません。production-writes flagをcompileすることはDB操作や公開を実施することではありません。

## owner記録の信頼境界

owner_record_jsonはraw UTF-8 SHA256、exact schemaと型、source/tree/controller/CI/version/buildへ結合します。approved_for_buildはtrue、approved_for_publishはfalseを要求します。このhashはtrusted operatorが入力した記録に固定するだけで、本物の人間の承認・本人性を暗号的に証明しません。

以下はschema説明専用の**無効placeholder**です。controller_commit等が有効なhashではないため実行には使えず、owner receiptを作成したことを意味しません。

```json
{
  "schema_version": 1,
  "repo": "kanta13jp1/my_web_app",
  "source": "UNAPPROVED_SOURCE_PLACEHOLDER",
  "source_tree": "UNAPPROVED_TREE_PLACEHOLDER",
  "controller_commit": "UNAPPROVED_CONTROLLER_PLACEHOLDER",
  "ci_run": 43176832528,
  "ci_attempt": 1,
  "app_version": "UNSELECTED_VERSION",
  "build_number": "UNSELECTED_BUILD",
  "approved_for_build": false,
  "approved_for_publish": false
}
```

PR5967・PR6020等の未回答の具体的本人確認を、このschema、別件の承認、paid-review免除、CI成功で代替しません。BUILD ONLYの具体的な対象・副作用とコード/実行枠をレビューして本人確認する必要があります。新versionは保守的3成分SemVerで1.0.2278より大きく、新buildは5836より大きい正数字列かつ2**31未満です。

## 容量、hidden files、証跡

bundleの上限は合計192MiB、1file32MiB、2000files。safe ASCII pathのregular filesだけを受け付け、symlink/hardlink/特殊file、危険pathを拒否します。根拠となる既存sourceの非本番CI archive metadataは522files、展開合計148,183,878bytes（約141.3MiB）、最大file27,462,394bytesで、旧128MiB上限では拒否されます。GitHub metadataとZIP digest一致は保存済みですが、内容を再展開した証明やproduction構成artifactのサイズ証明ではありません。

`include-hidden-files: true` は公開bundle `build/web` の `.well-known` 等を落とさないためです。workspace全体やcontrol/credentialをuploadせず、明示したbuild/webと外側のbuild/asset-build-evidence.json、BUILD_ONLY_VERIFIED.jsonだけを1日保持します。GitHub artifact保持はHosting公開ではありません。生configuration値やsecretは証跡へ出力・保存せず、path/hash/bytesとbinding/digestを記録します。生成Web bundleには通常のブラウザー向けpublic-client構成が含まれるため、その性質を前提に扱います。

artifact_sha256はsorted path→rawSHA256のcanonical JSON digest。`build_configuration_sha256` はcompile入力のdigestで、Hosting Version.configのdigestとは別物です。publisher/controllerへこの2つを取り違えて渡してはいけません。sealはpublication_allowed=false、approved_for_publish=false、verification_pending=true、hosting_config_attested=false、live_preservation_pending=trueを保持します。

## 残る確認

このpackageの登録だけで実publisherは完成しません。実production構成、認証/IAM、レビュー済みbuilder、SDK/cache/dependency、本人回答、実build・artifact検査、live全file/config保全、永続nonce/ref保護、公開gate、公開後manifest/bytes/desktop/mobile非金融UI、復旧は別工程です。unknown結果を新run/新operationで再送しません。

将来mainへ新たな非docs変更が入れば、preflightの最新main非docs全一致が停止する可能性があります。固定sourceや例外を黙って緩めず、新変更を保持する候補・CI・binding・本人確認範囲を再レビューしてください。現在同梱のpreflightは7path（UI5＋固定main公式data2）の由来と最新main一致を維持しますが、このbuild-only verifyはpinned preflightのleaves/full_run/manifestだけを明示使用し、observe全体・nonce予約・公開は呼びません。
