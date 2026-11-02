# 通常入口と専用入口の起動・Hot Reload比較

`echo-pump-prototype.yml`を手動で`profile=interactive`として実行する。
`expected_head_sha`にはブランチの完全な40文字のSHAを渡す。
通常入口は`lib/main.dart`の`/echo-pump`、専用入口は既存の`test/fixtures/echo_pump_app.dart`。
アプリの本番コード・保存データ・配信先は変更しない。

## 条件と測定範囲

- 同じSHA、Flutter 3.38.x、Ubuntu、Node 22、Chrome、1280×900を用いる。
- 通常・専用は別の新しいランナーで起動する。SDK・依存準備とランナー待ちは測定から除く。
- `flutter run --machine --debug -d chrome`で本物のdebugアプリを起動する。
- プロセス開始から`app.started`までと、ゲームの表示・音量変更を確認するまでを別記録する。
- 通常入口はテスト用のループバック接続先と合成キーを使う。Webエンジンはローカルから取得する。
- 外部接続はローカルHTTPプロキシで制限し、HTTPSの`fonts.gstatic.com:443`と`fonts.googleapis.com:443`だけ許可する。他の外部宛先は拒否し、許可・拒否したトンネル先を記録する。ループバックはChromeの既定バイパスを使う。
- 以前の全外部DNS遮断条件ではフォント取得失敗の後、通常入口の3回目にCanvasKitフォント登録の描画例外を観測した。今回のフォント取得可能条件と以前の測定値は混ぜて集計しない。フォント取得時間は起動測定に含まれる。
- 各入口で起動1回、Hot Reload3回を測る。単回の起動測定から恒常的な短縮率は断定しない。

## Hot Reloadの成功条件

共有UIの`BGM・SE / 音量`という文字列を、一時的にサンプル番号付きへ変更する。
Flutter daemonの`app.restart`に`fullRestart=false`を明示する。
成功応答だけでなく、文字列が実画面へ反映され、変更前に調整したスライダー値が保持され、ページ遷移がないことを確認する。
Flutterのスライダー実値は`aria-valuetext`で読む。ブラウザーのランタイム例外があれば全体を成功としない。
Hot Restart・単なる再ビルド・未変更の再読込をHot Reloadの成功として数えない。

## 証拠と失敗時の扱い

各入口のRESULT.json、Flutterログ、起動と変更後のスクリーンショットを7日間のActions成果物へ保存する。
失敗時も工程名とログを残し、成功したサンプルだけを隠して平均しない。
終了時にFlutter/Chromeと合成HTTPサーバーを停止し、一時変更したソースを元のハッシュへ戻したことを確認する。
ローカルで重い処理を誤実行しないよう、スクリプトはLinuxのGitHub Actions外では起動を拒否する。

PRのfull検証は従来どおり維持する。interactiveは手動の測定専用で、本番配信を行わない。

参考：

- [Flutter 3.38.10のdaemon protocol](https://github.com/flutter/flutter/blob/3.38.10/packages/flutter_tools/doc/daemon.md)
- [FlutterのHot Reload](https://docs.flutter.dev/tools/hot-reload)
- [Flutter公式のWeb計測で使われるChrome起動方法](https://github.com/flutter/flutter/blob/3.38.10/dev/devicelab/lib/tasks/web_benchmarks.dart)
