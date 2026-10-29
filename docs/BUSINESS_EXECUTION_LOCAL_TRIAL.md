# 経営の実行記録：端末内の試行

## 利用できること

仮想AI組織のタスクタブで、課題・担当者メモ・成果指標(KPI)・成果目標・毎日の行動(KDI)・単位・開始日と期限を設定する。1計画は同じ月に収まる期間、1担当、1行動を扱う。目標は保存後に固定し、日次実績と月次の振り返りを更新する。

実績0と未入力は別に扱う。対象日は開始日から今日または期限までの暦日（休日を含む）。未来の実績は保存できない。行動は日別値を合計し、成果は最新の入力値を表示する。成果の未入力を0に変換したり、日別の累計値を加算したりしない。成果指標は大きいほどよい指標のみを想定する。

日次記録は同じ日を更新すると1件のまま訂正する。月次欄には続けること・変えること・次月の行動を残せる。終了した月も確認できる。

## 保存範囲と限界

SharedPreferences の新しい本人ID別キーに保存する。既存の資産管理用ミラーは使用しない。新規DB、マイグレーション、RLS、通知送信、エージェント実行、AI呼び出しは追加しない。

このブラウザー・端末内の個人向け試行であり、会社の共同運営・サーバー同期・バックアップ・厳密な権限管理の完成を意味しない。端末データの削除で失われる。暗号化ストレージではないため、機密情報の保存には使わない。アプリ上では本人ID別キーとアカウント切替時のフォーム破棄により別アカウントへの混入を防ぐ。

同一タブ内の二重送信を止める。ブラウザーのWeb Locksをオリジン/本人ID単位で取得し、排他区間内で保存前の直前読込内容との一致・保存・読み戻し一致を確認する。別タブの待機した保存は更新後の値と照合し、不一致なら拒否する。コールバックの成功/例外/タブ終了でブラウザーがロックを開放する。API非対応・HTTPSでない等、安全な排他を利用できない環境では保存を拒否して入力を保持する。SharedPreferencesだけのread-compare-writeをCASとは呼ばない。破損・未知バージョン・上限超過の保存データは空データに置換せず、読込失敗を表示して書込を止める。

実行中は最大24計画、アーカイブを含め1000計画・保存JSON100万文字。1計画31日。古い実績を自動で削除しない。アーカイブは記録を保持して閲覧専用にし、実行中の枠を空ける。24件ずつ履歴を表示し、枠に余裕があれば再開できる。記録全体の容量上限やブラウザーquotaでは保存を拒否する。無制限の永続的な会社運営ではない。計画の編集・削除・エクスポート、曜日別予定、複数担当やチーム共有は次の設計範囲。

## 動画から採用した範囲

依頼元動画 https://www.youtube.com/watch?v=cLm8pxV1ceg の親担当による字幕確認に基づく。21:10の担当者別/日別行動と報告、48:50の課題整理→KPI/KDI→実績、49:47の未入力確認を、手動で使える最小単位にした。自律AI経営や90%/80%自動化の達成を主張しない。動画内の将来目標と現在の製品能力を分ける。

## 検査とレビュー

追加テスト：

- 純粋モデル：0/未入力、最新KPI、閏日と年境界、同日訂正、保存往復、形式・文字数・件数・非有限数値の拒否。
- コントローラー/実ストア：失敗→再試行、未来日拒否、遅延読込とアカウント切替、破損データ保持、本人別キーと競合拒否。
- 実画面widget：計画作成→実績0→月次振り返り→再オープン、保存失敗入力保持、アカウント切替、320px/文字2倍。

初回保存時点ではテスト・formatter・analyzerは未実行。ローカル空き容量が30GiB未満のためローカルFlutter/Dart・worktree作成を行わずGitHub APIで実装を保存。親担当が共有CI順番を管理する。CI結果はそのhead SHAに限った証拠として追記する。

実認証・本番UIの検査は別の未完了ゲート。実ブラウザー再読み込みと2タブ競合のPlaywrightテストを追加したが、実行はCI枠待ち。widgetテストを実ブラウザーE2Eや本番の保存証拠とみなさない。新しいアカウント境界の取り扱いはリリース前に人間レビューを必要とする。

## 作業範囲

Lead: Codex。モデルルーティングで選択された実装workerが上記の機能・検証ファイルを担当。remote scratch branchで保存し、既存ローカルworktreeや金融開発ファイルは変更しない。重複調査ではvirtual関連のopen PRなし。既存目標階層・月次KPI機能を確認し、既存の人生目標画面への導線を残した。

ロールバック時はこのUI導線の追加を戻し、端末に保存された記録を自動削除しない。

## 独立レビューへの修正

ロック内の照合と保存、保存失敗後の再読み込みでフォームを保持、開始日を跨ぐ再描画で日付を選択、24実行計画上限から履歴を残してアーカイブする経路を追加。テストも追加した。Web Lockのブラウザーテストは `flutter test --platform chrome test/web/business_execution_lock_test.dart` をクラウドで明示実行する必要がある。標準VMテストでブラウザー排他を検証したとは扱わない。

検査配線：標準CIのVM shardは `test/widgets/business_execution_panel_test.dart` を含む通常テストを列挙する。標準CIの独立したbusiness_execution条件のChrome stepで `test/web/business_execution_lock_test.dart` を実行する。lock test単独変更でweb=falseでも省略しない。web import smokeと専用E2Eの成否をロック単体の証拠に代用しない。整形はcloud-developmentのformat profile artifactから対象ファイルをGitHub APIで反映する。Minimal E2E Gate向けに後述のPlaywright業務フローを追加した。追加ファイルの存在とE2E成功は別であり、実行結果は未取得。Web Lock単体Chrome検査を業務フローE2Eとは呼ばない。

同日実績・月次文章の別タブ更新は編集開始時の元値と比較する。再読込で最新の保存値と保持下書きが食い違った場合は保存を止め、最新値を表示し、利用者の明示的な上書き確認を受けた後でのみ再保存できる。別タブでアーカイブされても下書きを退避表示し、再開後に復旧する。Web Lock待ち中の本人切替は実書込前のowner再確認で拒否する。

## 実ブラウザーの最小業務E2E（追加・実行待ち）

既存Playwright依存・desktop/mobile Chrome設定を専用 `playwright.business-execution.config.ts` で再利用する。通常 `playwright.config.ts` はこのfixture用specをtestIgnoreし、専用configがこの1本だけを明示収集する。テスト専用entrypoint `test/fixtures/business_execution_app.dart` は本物のパネル・SharedPreferences・Web Locksを使用し、架空ownerと固定時計だけを渡す。保存済みJSONの注入・mock store・アプリ内部メソッドの直接呼出しはしない。

通常の `lib/main.dart` からfixtureを読み込まない。明示ビルドフラグとloopbackホストの両方がなければfixture自体も起動を拒否する。Playwrightもloopback以外へのナビゲーションを拒否する。実認証・本番ルーティング・他端末同期の検証ではない。

`test/e2e/business_execution.spec.ts` の業務3シナリオと通信境界1ケース：

1. 課題とKPI/KDI計画を画面から作成し、日次実績と月次文章を保存。ページ遷移でDart runtimeを破棄し、翌月の固定時計で期間終了・保存済み実績・月次文章を復元確認。
2. 実績の空欄を拒否。再読み込みで未入力のままと確認し、0を保存して再読み込み。0の記録、残る未入力日、成果の未入力を区別。
3. 同一BrowserContextに実際の2タブを開く。先にタブAが日次/月次を保存し、古いタブBの保存を拒否。再照合後もBの下書きを保持し、最新値を表示、明示上書き確認まで保存不可。確認後に保存し、Aの再読み込みでBの記録を確認。

4. 専用loopbackサーバーの試験用302経路から予約済み.invalid宛のredirectを返す。Playwrightが拒否し、移動先要求を出さず、拒否理由を記録したことを確認。その後に正規fixtureへ再移動できることを確認する。

クラウド実行用の準備コマンド（この時点では未実行）：

~~~sh
flutter pub get
flutter build web --release --pwa-strategy=none --no-web-resources-cdn --target=test/fixtures/business_execution_app.dart --dart-define=BUSINESS_EXECUTION_E2E=true --dart-define=ENVIRONMENT=visual-test
npm ci
npx playwright install --with-deps chromium
~~~

同じクラウド環境で専用サーバーを起動・識別してから実行する（CIは同じ手順を自動実行）：

~~~sh
set -euo pipefail
ready_dir="$(mktemp -d)"
ready_file="$ready_dir/ready.json"
source_sha="$(git rev-parse HEAD)"
python3 scripts/serve_business_execution_fixture.py serve build/web --ready-file "$ready_file" --source-sha "$source_sha" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
for _ in {1..20}; do
  kill -0 "$server_pid"
  if [ -s "$ready_file" ]; then break; fi
  sleep 1
done
E2E_BASE_URL="$(python3 scripts/serve_business_execution_fixture.py verify --ready-file "$ready_file" --pid "$server_pid" --source-sha "$source_sha")"
BUSINESS_EXECUTION_FIXTURE_TOKEN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$ready_file")"
export E2E_BASE_URL BUSINESS_EXECUTION_FIXTURE_TOKEN
npm run e2e:business-execution -- --forbid-only
python3 scripts/serve_business_execution_fixture.py verify --ready-file "$ready_file" --pid "$server_pid" --source-sha "$source_sha"
~~~

desktop/mobileで合計8ケースになる。専用configのHTML/JSON report、失敗時trace/videoと代表状態のスクリーンショットを証拠にする。起動したサーバーは実行担当が終了させる。新規workflow・job・依存は追加しない。既存CIのStatic checks and webジョブに、この専用fixtureのbuild/Playwright呼出しを追加した。専用business_execution分類がtrueのとき実行し、失敗はジョブを失敗させる。通常のbuild/webを上書きしない別出力先を使用する。CI担当が順番を確保した後に実行し、head SHA・結果・desktop/mobile画像を確認する必要がある。未実行のファイル追加をgate成功とは報告しない。

通常 `npm run e2e` はfixture specを自動収集しない。専用 `npm run e2e:business-execution` はE2E_BASE_URL未指定・非loopback・資格情報付きURL・fixture token未指定を設定読込時に拒否し、失敗をskipへ置換しない。専用configは通常configのtestIgnoreを明示的に解除し、この4ケースだけをdesktop/mobileで実行する。

専用/通常Playwright config・npm manifest/lock・ci.yml・分類器と専用サーバースクリプトの単独変更もbusiness_execution検査側に分類し、必要なFlutter準備を有効にする。これによりテスト設定だけのPRでも専用E2Eを省略しない。web/deployableの分類は変えず、テスト設定変更を本番配信の理由にしない。classifier回帰テストを追加した。workflow配線を含め実行はまだ行っていない。

## サーバー識別とブラウザー通信境界

固定ポートの事前探索は行わず、専用サーバーが127.0.0.1のport 0へbindして割り当てを保持する。bind後にPID・実port・ランダムnonce・チェックアウトSHAを新規readyファイルへ保存し、HTTP identity応答と完全一致すること、起動したPIDが検査前後に生存することを検証する。古いreadyファイル、別PID/別SHA/別nonce、identity応答のredirectは拒否する。サーバー起動失敗を他プロセスの200応答で補わない。正常・失敗いずれでも起動PIDだけを終了する。

PlaywrightのBrowserContextに通信制限を設定し、両タブ・popup・frame・資産要求を同一fixture originに限定する。HTTPはredirectを追わず、3xxとidentity header不一致を拒否する。Service Workerは無効化し、不要なWebSocketも拒否。操作直前にも現在の最終URLを確認する。ブロックされた要求は記録し、テスト失敗にする。外部CDN例外は設けず、--no-web-resources-cdnでエンジンも同梱する。これにより初期URLだけloopbackでredirect後は本番という経路を許可しない。

新しいserver helperのOS port割当・PID/nonce/SHA照合・stale ready拒否・redirect拒否の回帰を既存Python検査に追加した。専用分類は無関係なFlutterソース/テスト変更でfixture buildを増やさない。workflow_dispatchとdeployのworkflow_callは既存のforce-all契約を維持するため専用検査も実行し、その追加時間はクラウド実測待ち。元のジョブtimeoutは延長していない。必要チェックを省略して配信を早める変更はしていない。

検査範囲の判断：fixture buildが利用する `.github/actions/setup-flutter-sdk/**` と `assets/**` の単独変更も専用ブラウザー検査を要求する。既存のtiger生成データ除外は維持する。無関係なFlutter画面/テストは専用E2Eを増やさない。非PRのpush/workflow_dispatch/workflow_callは変更一覧を収集せずforce-allを使う既存契約のため、この検査だけ常時省略する変更はしない。配信呼出にもfixture build・Chromium準備・8ケースの追加時間が生じる。30分のStatic checks枠で完走するかは実測待ちで、未検証のまま配信可能とは扱わない。差分ベースの配信ゲート最適化は、今回の小変更で欠落を作らず別途設計する。

CI summaryにもロック単体と専用E2Eを別行で記録し、E2E成功時でもロック失敗/skipを成功表示しない。分類と実workflow条件を合わせた回帰、SDK/assetの分類回帰、summaryの独立した結果表示を追加した。すべて実行待ち。

## 初回PR CIの診断（e27e0e0）

PR #5931、CI run 40947972686 / Static checks and web job 123708238536では、scope classifier 19件とfixture server 5件は成功した。2026-10-29 20:19:36 UTCに、同じ「Test CI scope classifier」step内のci_job_summary_testが失敗。workflowのstep IDを抽出する正規表現[a-z_]+がbusiness_execution_e2e内の数字を認識せず、実在するstepを0件と誤判定した。英数字・underscore・hyphenを扱う抽出へ修正し、数字/ハイフンを含むIDと不正IDの回帰を追加した。workflow条件や本物のE2Eを省略する修正はしていない。

直前のHTTPError 504/ResourceWarningは、既存kg_index_common_testのurlopen mockが作る失敗・再試行ケースの出力と一致し、該当13件は成功している。これを本番接続障害やfixture server失敗の証拠にしない。この別機能の警告修正は本差分に含めない。

後続のFlutter準備・analyzer・formatter・Chrome lock・fixture build・Playwrightは先行step失敗によってskipされた。ここまでのPython成功をそれらの成功とは扱わない。修正は元PR headを動かさず、別scratchに保存する。修正後の再実行は共有CI順番の管理担当による許可待ち。

CI summary回帰のID抽出は汎用YAMLパーサーではなく、現ci.ymlのblock形式（stepのlist itemは6スペース、後続キーは8スペース）を対象にする。IDのplain/単引用符/二重引用符、末尾コメント、先頭の `- id:` は扱い、job-levelやshell本文のidを除く回帰を追加した。flow mapping・alias・escapeを使う別形式へ変更する場合は構造パーサーへの移行が必要。既存PyYAMLはagent-skill-contractの別jobにのみ明示導入されており、この早期CI stepで使える保証がないため、今回新しいインストール工程は追加していない。
