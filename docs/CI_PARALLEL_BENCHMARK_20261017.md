# CI並列化の実測記録（2026-10-17）

## 変更前

GitHub Actionsの成功した直近4件について、Jobs APIのstarted_at/completed_atを比較。
以下は実行時間で、キュー待ちとPRの他ワークフローは含めない。

| Run | 主要ジョブ | VMテスト | Web import | Webビルド |
| --- | ---: | ---: | ---: | ---: |
| [39031878054](https://github.com/kanta13jp1/my_web_app/actions/runs/39031878054) | 1,015秒 | 734秒 | 70秒 | 105秒 |
| [39031765358](https://github.com/kanta13jp1/my_web_app/actions/runs/39031765358) | 1,091秒 | 794秒 | 71秒 | 110秒 |
| [39027734424](https://github.com/kanta13jp1/my_web_app/actions/runs/39027734424) | 833秒 | 603秒 | 53秒 | 92秒 |
| [39027019669](https://github.com/kanta13jp1/my_web_app/actions/runs/39027019669) | 1,179秒 | 858秒 | 85秒 | 125秒 |

主要ジョブ中央値は1,053秒（17分33秒）、VM中央値764秒（12分44秒）。
最大の工程であるVM全体テストを先に分割する。

## 実装

- Flutter標準の`--total-shards=2 --shard-index=0/1`で全体テストを2分割。
- 各ジョブの`--coverage --concurrency=2`を維持し、別名でLCOVを保存する。
- 静的解析・Web import・本番用Webビルドは従来のジョブに保持し、VMと並行する。
- 両VM shardはfail-fastを無効にし、片方の失敗でも他方の証拠を残す。
- 全ジョブは同じPR merge refまたは固定イベントSHAを取得し、manual dispatchのSHA一致検査を維持。
- パス分類によるFlutter/Web処理の省略とworkflow_callでのWebビルド省略を維持。
- 保護対象の`Lint, Format, and Test`は集約ジョブに移し、静的/WebとVMの両方が成功した場合だけ成功。
- ブランチ保護・テスト対象・本番配信・認証・DB・アプリ本体は変更しない。

## 検証と限界

失敗・キャンセル・スキップを含む16組合せで実際の集約シェルを検査する。
コード配置だけを変更して省略するテストはない。LCOVは各shardの部分カバレッジであり、
単独ファイルを全体カバレッジと扱わない。

本変更はランナー台数を増やして待ち時間を減らす。合計ランナー分数が減るとは限らない。
2分割に限定し、実行待ちと分割の偏りを変更後の実測で確認する。
過去4件はアプリソースが異なるため、比較値を同一ソースの厳密な因果効果とは断定しない。
変更後のクラウド検証結果はPRに追記する。
