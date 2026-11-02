# Hosting転送量の測定と重複フォント取得の削減

公開ホームのNotoSansJP-Regular.ttfがCSS Font preloadとCanvasKit Fetchで二重取得されていたため、web/index.htmlの当該preloadだけを削除した。フォント本体、pubspecの宣言、収録文字、SEOシェルの描画安定化待ちは維持する。

## 再現条件

専用Hosting Transfer Audit（scripts/hosting-transfer/audit.cjs / proxy.cjs）をGitHub Actionsで実行する。匿名の公開ホームを読み、認証や課金設定を変更しない。Playwright 1.56.1、Chromium、ja-JP / Asia-Tokyo、SwiftShader、serviceWorkers=block。PC1365×900を各3回、mobile390×844を各1回。各contextで初回、about:blankへ離脱後の再訪問を測る。HTTPキャッシュを無効にするrouteは使わない。DOMContentLoaded後30秒の固定窓でCDP Network.loadingFinished.encodedDataLengthを合計する。

同一クラウド内のループバックreverse proxyで、変更前の本番HTMLと、該当preloadだけを除いたHTMLを比較する。他の応答と圧縮ヘッダーは上流から通す。これは本番反映後の結果ではなく、変更の寄与を分離する実験。本番配信は固定スナップショットではないので、配信更新があった実行の比較には使わない。再実行時に上流から当該preloadが既になくなっていれば、明示エラーで停止する。

## 検証結果

固定e157e644、run39125413342で16サンプル成功。各サンプルの初回描画イベントとpageerrorなしを必須にし、日本語フォントのFetchが200、重複CSS Font取得なし、各coldの転送量15%以上削減を検証した。PC/mobileの前後画像で日本語と主要CTAを目視確認した。全体CIの既存SEO試験は旧preload文字列を必須としていたため、その期待だけを除く。SEOシェルの重複防止・安定化待ち・フェード等の既存検証は残す。

| Hosting転送量（MB、10進） | 変更前 | 変更後 | 削減 |
| --- | ---: | ---: | ---: |
| PC初回・3回中央値 | 23.019 | 15.083 | 34.48% |
| PC再訪問・3回中央値 | 19.558 | 11.622 | 40.58% |
| mobile初回・各1回 | 23.020 | 15.083 | 34.48% |
| mobile再訪問・各1回 | 19.557 | 11.621 | 40.58% |

ページ全体（別CDNも含む）のPC中央値は初回25.134→17.198MB、再訪19.565→11.628MB。Hostingの課金への寄与と、別CDNのバイト数は分ける。CDP encodedDataLengthは観測窓内の応答・ヘッダーを含む測定値で、請求明細のGiBそのものではない。日本語TTFの1回分約7.94MBの重複転送を除いた効果であり、月間節約額は算出しない。

3回は小標本で、環境はクラウド・匿名ホームのみ。service workerを許可した訪問、他ブラウザー、認証後画面、実端末の回線は未測定。初回描画時間は待ちがある再訪問で改善していないため、起動時間が速くなるとは主張しない。初期のlocale未指定測定はlocale例外と未描画があり、正常表示の検証として使わない。

## 戻し方と次の判断

実装差分はHTMLのpreload除去。必要なら当該1タグを戻せる。フォント/文字を削るsubset、一律immutable、サービス分割、GPU復旧は行わない。マージと本番配信は別工程とし、承認後の配信では同じ公開画面を再測定して実際の削減を照合する。本番が最適化済みになった後の監視は、未変更HTMLを前提とする今回の比較用proxyとは別の条件で行う。
