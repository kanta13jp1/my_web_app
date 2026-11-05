# 議員単独観測と統合選挙履歴の分離契約案

状態: ローカル調査・設計モデル検証。DB保存、API action追加、workflow変更、投稿送信は未実施。

## 既存契約から分かったこと

| 境界 | 現在の挙動 | 分離するときの危険 |
| --- | --- | --- |
| `snapshot_history.ts:canonicalizeLocalElectionSnapshot` | `upcomingSchedules`がないと`[]`にする。候補者は日程内の配列に正規化される | 「今回は未観測」が「観測して0人」と同じになる |
| `computeLocalElectionDiff` | 日程キーは都道府県・自治体・選挙名・投票日。候補キーはそれと氏名。前回だけにあるキーを`removed`にする | 議員情報だけ渡すと前回の日程・候補が削除差分になる。投票日の訂正も別キーになる |
| `buildLocalElectionPostCandidates` | `candidate_delta`で「掲載終了」の投稿候補、`schedule_delta`で日程の掲載終了候補を作る | 未確認・未収集を掲載終了と誤通知する。コードが直接「取り下げ」と断定しているわけではないが、その根拠にもできない |
| `persistLocalElectionSnapshot` | 統合dataset、schema version 2、内容ハッシュ、実際の前観測IDを使う。`collectionQuality.complete=false`なら書き込み前に拒否 | 別種の部分観測を同じ履歴チェーンへ入れてはいけない |
| `index.ts:createLocalElectionHubStore` | `hub_data.source`と`metadata.dataset`で最新履歴を限定する | 分離するならsourceとdatasetの両方を別にする。既存store/composerをそのまま再利用しない |
| `.github/workflows/local-election-snapshot-queue.yml` | 統合用の`snapshotAndQueue`を呼ぶ | 議員専用処理へ黙って付け替えない。今回変更していない |
| `LocalElectionRealityService` | remote payloadをモデルに変換してメモリ・SharedPreferencesへ保存する | モデル化前に品質を確認しないと部分観測がフルデータ扱いになる |
| `LocalElectionRealitySnapshot` | `hasData`は地方議員数>0で真。品質メタデータを保持しない。日程・候補ゼロのアラートがある | 議員数だけで予定候補も確認できたとはいえない |
| `ElectionVictoryPage` | 取得モデルでplan同期、表示、共有メモを行う。共有入口も`hasData`を使う | 部分観測をここへ渡すと公開情報へ波及し得る |
| `LocalElectionRealityService`内の端末履歴 | 日時・議員数・不足数だけの日別ポイント | これは端末内の表示履歴であり、サーバー統合履歴の代替や承認ではない |
| `admin_x_candidate_queue.dart` | 統合処理が作る議員・候補者・日程variantを表示する | 新しい議員観測に既存候補者variantを流用しない |

調査基点はローカル`origin/main`の`f2644a785408e2944c204fafc56d465e74bee349`。リポジトリ内ソースの読み取り結果であり、本番DBや実デプロイの検査結果ではない。

## 今回の利用側修正

`LocalElectionRealityService.validateRemoteSnapshotPayload`をモデル化より前に呼ぶ。
`collectionQuality.complete=true`かつ`issues=[]`が明示されていない応答は拒否する。
これにより、既存のエラー時キャッシュへのフォールバックを利用し、未確認候補を含む新しい部分観測をキャッシュ・アラート・plan同期・共有へ渡さない。

この修正は過去キャッシュを消去・書き換えない。既存キャッシュには品質メタデータが残っていないため、過去に保存されたデータの完全性を遡って証明できない。移行時のキャッシュ版管理と「最後に確認済み」の表示は残課題。

## 議員単独観測の提案契約

- 新dataset案: `kokumin_local_members_observation_v1`。
- 新hub source案: `local_election_member_observation`。
- `record_type`も将来は`member_observation`とし、既存`dataset_snapshot`の読者へ流さない。
- 初回は独立基点。統合履歴の前観測ID・hashを前任として参照しない。監査用の別参照を残すとしても、差分チェーンにはしない。
- `coverage.members=observed_complete`、`coverage.candidates=not_observed`、`coverage.schedules=not_observed`を必須にする。
- 候補・日程・統合snapshotの配列を議員観測へ入れない。空配列を補わない。
- 議員の品質は既存しきい値170人、都道府県リンク10以上、取得失敗なしを維持。名簿件数と全国数の一致、プロフィールIDの一意性も検査する。
- 新観測の品質を理由に既存統合snapshotの`complete`を真へ変えない。既存の候補・日程・目標・公認情報ゲートはそのまま維持。
- 表示を合成する場合は議員・日程・候補それぞれの基準日と品質を保持する。「新しい議員数」と「最後に確認した候補日程」を一つの新しい取得日時へ丸めない。
- 議員専用の公開・投稿処理は今回作らない。設計モデルは常に`mayPersist=false`、`mayPublish=false`。

既存統合snapshotへ議員だけを差し込み、残りを`[]`にする方法、古い日程を更新済みと装ってコピーする方法、品質ゲートをcatchして保存する方法は採用しない。

## 候補者側の独立した状態

候補者の観測と特定選挙への出馬確認は別にする。公式プロフィールURLを人物の根拠にし、対象選挙・都道府県・確認済み投票日・出典をそろえたときだけ選挙との関係を作る。

`pending`、`not_observed`、`confirmed_for_specific_election`は別の状態。候補者がPDF/HTMLから欠落したこと、過去に当選したこと、投票日を確認できないことから、次回選挙の取り下げを推論しない。将来「取り下げ」を扱う場合は、対象選挙を特定できる明示的な発表と確認記録を必要とする。

括弧付きPDF日付は任期満了日。通常表記の投票日欄も、2027年4月などは法成立・個別選管確認なしに確定扱いにしない。

## 実行した検証と限界

`tools/local_election_contract_lab/`はDB・ネットワーク・キャッシュ・投稿機能のないPython設計モデル。12件の契約テストが成功した。

検証項目: 独立基点、旧dataset/sourceの拒否、未観測と空配列の区別、他ストリームの配列拒否、候補削除通知の不生成、既存しきい値の維持、空/部分/不整合名簿の拒否、重複ID拒否、順序と観測日時によらない内容hash、入力非破壊、保存権限を生まないこと。

これは本番TypeScriptの実行検証ではない。実際の`canonicalizeLocalElectionSnapshot`が欠落日程を空配列へ変える危険を記録するDenoテストと、未確認品質で永続化/投稿候補が作られないDenoテストの2件を追加したが未実行。

画面側の品質チェックはFlutterテスト4件を追加したが未実行。残りはパーサー/候補分離のDeno追加31件、RepositoryのFlutter対象6件、既存の履歴・サービス・共有・キュー関連の回帰スイート、型検査・lint・format・ブラウザー確認。

資源診断では空き容量29.03GiB、メモリ86%でAGENTS.mdのcloud-required条件に該当したため、Deno/Flutterテスト・ビルド・依存導入は行っていない。クラウド実行のdispatchも未許可のため行っていない。

## 実装を有効にする前の条件

独立datasetを読むstore、独立canonical schema、基点/再試行/競合/旧履歴非接触のテスト、画面の部分更新と個別品質表示、キャッシュ移行、公開メモや投稿からの隔離を実装・実行検証すること。既存統合履歴の欠落を削除扱いにしないことが確認できるまで、議員単独保存は有効化しない。
