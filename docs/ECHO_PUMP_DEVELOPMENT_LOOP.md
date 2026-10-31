# 残響ポンプ室の開発中の確認

専用入口は既存の`test/fixtures/echo_pump_app.dart`を使う。
本体の`lib/main.dart`を起動せずゲームを直接開ける。
入口・ゲーム・認証・保存処理・配信先は今回変更しない。

## クラウドで短く確認する

コミット済みブランチと、その完全な40文字のSHAを指定する。
`BRANCH`と`SHA`は実際の値へ置き換える。

```text
gh workflow run echo-pump-prototype.yml --ref BRANCH -f expected_head_sha=SHA -f profile=quick -f check_mode=grouped
```

quickでも、従来と同じ対象の書式・静的解析・VMテスト9ファイル・音声の整合性検査をすべて実行する。
13回あったツール起動を4回にまとめ、各起動と全体の時間をJSONへ記録する。
最初の失敗で停止し、失敗を成功扱いしない。

quickは開発中の手動実行専用。本番用ビルド・PC/mobileブラウザー検証は省くため、リリースの証拠には使わない。
PRでは必ずfullが実行され、既存のビルド・操作・音声回帰検証も残る。
最終確認を手動で行う場合も`profile=full`を指定する。

## 同じ対象で従来方式と比較する

同じブランチ・同じSHA・`profile=quick`で`check_mode=baseline`と`check_mode=grouped`を実行する。
baselineは移行元commit `249da945`の13コマンドを順番どおり再現する。
入力ファイルは同一で、検査対象を減らした比較ではない。
既存の同じモードの実行は新しい実行に置き換わるが、baselineとgroupedは互いをキャンセルしない。

各実行の`echo-pump-evidence-RUN_ID`成果物にある`.ci-logs/echo-pump-dev-checks.json`を比較する。
ツール実行時間と、ランナー待ち・SDK準備を含むworkflow全体時間を分ける。
異なるランナーでの単回測定は変動を含むため、恒常的な短縮率を保証しない。

## 画面を直接触る場合

対話的な実行環境では、専用入口を指定して確認する。

```text
flutter run -d chrome --target=test/fixtures/echo_pump_app.dart
```

ローカルで実行する前には既存の資源判定と共有作業枠を適用する。
資源不足時にこのコマンドを自動実行しない。クラウドのquick/fullを使う。
今回は対話的な起動・Hot Reloadの待ち時間は未測定で、クラウドの検査時間と混同しない。

## 対象を増やすとき

`scripts/echo_pump_dev_commands.json`の検査対象とworkflowの変更パスを更新し、
`python3 scripts/echo_pump_dev_checks_test.py`で統合前後の対象一致を確認する。
未知のコマンド・空の検査分類・音声検査の欠落は失敗する。
全体CIを専用の検査で置き換えず、パッケージ化や独立配信は別段階で判断する。
