# Android App Release Step-by-Step

AI大学 Android学科向けに、このFlutterアプリをAndroidアプリとしてGoogle Playへ公開するための手順をまとめる。対象は `my_web_app` のモバイル版で、最初のゴールはGoogle Playの内部テストへ配布すること、次のゴールは審査を通して本番公開すること。

## 0. ゴールを決める

- 最初はGoogle Play Internal testingで、実機に配布してログイン、Home、AI大学、WBS、資産管理、共有機能を確認する。
- 次にClosed testingまたはOpen testingで、クラッシュと主要導線を確認する。
- 最後にProduction releaseへ段階的に公開する。
- Web版と同じSupabase/Firebase本番環境を使う場合は、Android用のOAuthリダイレクト、Deep Link、プライバシー説明、通知権限を先に整理する。

## 1. Google Play Developerアカウントを準備する

1. Google Play Consoleに登録する。
2. 開発者名、住所、連絡先、本人確認、支払いプロファイルを完了する。
3. 組織として公開する場合は、組織名、D-U-N-S番号、連絡先メール、Webサイトを整理する。
4. Play Consoleで新規アプリを作る前に、アプリ名、既定言語、アプリ/ゲーム区分、無料/有料区分を決める。
5. 本番公開前に、プライバシーポリシーURLとサポートURLを用意する。

## 2. Android開発環境を準備する

1. Android Studioの安定版をインストールする。
2. Android SDK、Platform Tools、Build Tools、Android Emulatorを入れる。
3. Flutter stableを用意し、`flutter doctor` を通す。
4. このリポジトリで依存関係を取得する。

```bash
flutter pub get
flutter doctor
```

5. Windowsでビルドする場合は、JDKとAndroid SDKのパスがFlutterから認識されていることを確認する。

## 3. AndroidアプリIDと基本設定を決める

1. `android/app/build.gradle` または `android/app/build.gradle.kts` の `applicationId` を確認する。
2. 公開後に変更しにくいため、例として `jp.co.jibun.mywebapp` のような会社/サービス名ベースのIDに固定する。
3. `versionCode` はGoogle Playへアップロードするたびに必ず増やす。
4. `versionName` はユーザー向けの表示バージョンとして、ヘッダー表示やリリースノートと揃える。
5. `minSdk`、`targetSdk`、`compileSdk` をFlutter/Android/Google Play要件に合わせて更新する。

## 4. アプリ内設定を本番向けに整える

1. モバイル版のエントリーポイントとして `lib/main_mobile.dart` を使う。
2. Supabase URL、Anon key、Firebase設定などは `--dart-define` または安全な設定経路で渡す。
3. Web専用API、ブラウザ専用import、開発用バナー、デバッグログがAndroidリリースに混ざらないことを確認する。
4. OAuth、Deep Link、外部リンク遷移をAndroid実機で確認する。
5. 通知、カメラ、マイク、写真、位置情報など、使う権限だけを `AndroidManifest.xml` に残す。
6. Data safetyフォームに回答できるよう、収集するデータ、共有するデータ、暗号化、削除リクエスト導線を棚卸しする。

## 5. 署名鍵を作る

Google Playへ出すAndroidアプリは署名が必要。Play App Signingを使う場合でも、アップロード用の鍵を安全に管理する。

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

1. `upload-keystore.jks` はリポジトリへコミットしない。
2. `android/key.properties` などにパスワードを書く場合もコミットしない。
3. CIで署名する場合は、keystoreをBase64化してGitHub Secretsへ保存する。
4. 鍵を紛失すると更新が止まるため、バックアップ場所と復旧手順をWBSに残す。

GitHub Actionsで配布前のstrict gateを通すには、少なくとも次のSecretsを登録する。

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

登録後、`mobile-distribution-readiness.yml` を `require_distribution_secrets=true` で手動実行し、Androidのsecret presenceがgreenであることを確認する。レポートartifactにはsecret値ではなく存在有無だけが記録される。

## 6. ローカルでリリースビルドを作る

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --target lib/main_mobile.dart
```

生成物は通常 `build/app/outputs/bundle/release/app-release.aab` に出る。Google PlayへはAPKではなくAABをアップロードする。

実機で先に見る場合はAPKも作る。

```bash
flutter build apk --release --target lib/main_mobile.dart
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 7. 実機テストをする

1. Android 13以降と、最低対応に近い古いAndroid端末またはエミュレータで確認する。
2. 初回起動、ログイン、AI大学、WBS、資産管理、共有モーダル、外部ブラウザ遷移を確認する。
3. 画面回転、戻るボタン、ダークモード、フォントサイズ拡大、低速回線を確認する。
4. Play ConsoleのPre-launch reportでクラッシュ、ANR、アクセシビリティ警告を確認する。
5. Sentry/Firebase Crashlyticsなどを使う場合は、リリースビルドでイベントが記録されることを確認する。

## 8. Play Consoleにアプリを作る

1. Play ConsoleでCreate appを選ぶ。
2. アプリ名、既定言語、アプリ/ゲーム、無料/有料を選ぶ。
3. Store listingに短い説明、詳しい説明、アイコン、Feature graphic、スクリーンショットを入れる。
4. App accessでログイン要否と審査用アカウントを登録する。
5. Ads、Content rating、Target audience、News apps、Data safety、Financial featuresなどの質問に回答する。
6. Privacy policy URLとサポート連絡先を設定する。

## 9. Internal testingへ配布する

1. Testing > Internal testingで新しいリリースを作る。
2. `app-release.aab` をアップロードする。
3. リリースノートに、今回確認してほしい導線を書く。
4. テスターのメールリストまたはGoogle Groupを登録する。
5. Review releaseでエラーや警告を確認し、Start rollout to Internal testingを実行する。
6. テスター用リンクから実機へインストールし、主要導線を確認する。

## 10. Closed/Open testingへ進める

1. Internal testingでクラッシュがないことを確認する。
2. Closed testingへ進め、少人数で本番に近い運用確認をする。
3. 課金、外部API、通知、共有、AI生成など、審査で誤解されやすい機能はリリースノートと審査メモに説明を入れる。
4. 必要ならOpen testingで追加の端末互換性とUXを確認する。
5. テスト結果をWBSに記録し、未解決のクラッシュや審査懸念はGitHub Issue化する。

## 11. Productionへ公開する

1. Production trackで新しいリリースを作る。
2. Internal/Closedで検証済みのAABを選ぶ。
3. リリースノート、審査メモ、審査用アカウントを最終確認する。
4. Review releaseでPlay Consoleの必須項目が全て完了していることを確認する。
5. 段階的公開を使い、最初は少ない割合でロールアウトする。
6. クラッシュ率、ANR、レビュー、問い合わせを監視し、問題があれば停止または修正版を出す。

## 12. 更新リリースの運用

- `versionCode` は毎回増やす。
- `versionName`、Webヘッダーのバージョン、リリースノートを揃える。
- Supabase migration、Edge Functions、Flutterアプリを同時に変える場合は、互換性のある順番でデプロイする。
- リリース前にAI大学/WBS/Home/資産管理/共有/ログインのスモークテストをチェックリスト化する。
- 審査落ちやPre-launch reportの警告はGitHub Issueにし、WBSの遅延タスクへ反映する。

## 13. CI/CDの次の改善

- GitHub Actionsで `flutter build appbundle --release --target lib/main_mobile.dart` を定期実行する。
- keystoreとPlay Console service accountをGitHub Secretsに入れ、AABアップロードを自動化する。
- Fastlaneを導入すると、`supply` で内部テスト配布、リリースノート、メタデータ更新を自動化できる。
- 完全自動化しても、Production rollout前の人間確認はWBS承認タスクとして残す。

## 公式ドキュメント

- Flutter: Build and release an Android app - https://docs.flutter.dev/deployment/android
- Android app signing - https://developer.android.com/studio/publish/app-signing
- Google Play Console Help - https://support.google.com/googleplay/android-developer/
- Create and set up your app - https://support.google.com/googleplay/android-developer/answer/9859152
