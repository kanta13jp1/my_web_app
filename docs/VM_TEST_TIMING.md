# VMテスト配分の再計測

2026-10-19、Flutter VM試験を実行した直近成功8件で、作成から必須集約までの中央値は513秒だった。サービスのみ等の範囲外ジョブは除外した。同一SHA/runnerの前後比較ではないため、過去中央値1053秒との差を並列化の因果効果とは扱わない。

準備のInstall dependenciesは両分割とも中央値2秒。VM試験本体は分割0が400秒、分割1が469秒、静的/Webジョブ全体は中央値331.5秒。次の対象はテスト配分であり、キャッシュ・準備の再実装は優先しない。

## 取得方法

`run_vm_test_shard.py`は従来のcoverage/concurrency=2/ファイルの交互分割・標準コンソール出力と終了コードを保持し、追加のJSON file reporterだけを有効にする。成功した各分割のvm-coverage成果物へ `.ci-logs/vm-events.jsonl` をmanifest/coverageと一緒に保存する。Flutter/Dartの公開JSON reporter形式を利用し、テストの省略や成功判定の置換は行わない。

- Flutterのfile reporter: https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/test.dart
- JSONイベント仕様: https://github.com/dart-lang/test/blob/master/pkgs/test/doc/json_reporter.md

suiteのpathとtestStart/testDoneのID・単調経過time(ms)を結び付ける。hiddenのロード/セットアップ、skipped、エラー/中断の観測を区別する。複数テストが重なるため、個々の時間の合計はジョブwall timeにならない。ロード・コンパイル・coverage等の時間も別に扱う。異なるSHAの値を混ぜて短縮率を作らない。

## 次の採否条件

固定SHAの両分割の実イベントを取得してから、遅いファイル候補を調べる。配分変更はファイル漏れ・重複0と全体成功を必須とし、同じSHA/条件で現在の2分割と候補を比較する。最大wall timeと合計runner時間を両方確認し、未実行を高速化として数えない。本差分では分割数・並列度・本番配信・GPU設定を変えない。
