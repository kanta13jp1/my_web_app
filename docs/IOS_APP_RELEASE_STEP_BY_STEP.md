# iOS App Release Step-by-Step

AI大学 iOS学科向けに、このFlutterアプリをApp Storeへ公開するための実務手順をまとめる。対象は `my_web_app` の iOS版で、現在のCIは iOS simulator artifact までを自動生成し、App Store提出用の署名済み `.ipa` はMac/Xcode/App Store Connect側で仕上げる前提とする。

## 0. ゴールを決める

- 最初のゴールは TestFlight 内部テストに配布する。
- 次のゴールは App Review を通して App Store で公開する。
- Web版と同じFirebase/Supabase本番環境を使う場合、iOS用のリダイレクトURI、Deep Link、プライバシー説明、通知権限を先に洗い出す。

## 1. Apple Developer Programを準備する

1. Apple AccountでApple Developer Programに登録する。
2. Team IDを確認する。
3. App Store Connectに入れることを確認する。
4. Certificates, Identifiers & ProfilesでBundle IDを作る。
5. Bundle IDは本番公開後に変えにくいため、例として `jp.co.jibun.mywebapp` のように会社/サービス名で固定する。

## 2. Flutter/iOS開発環境を作る

1. macOS上で最新の安定版Xcodeを入れる。
2. Xcodeを1度起動してライセンス同意と追加コンポーネント導入を済ませる。
3. Flutter stableを用意し、`flutter doctor` を通す。
4. CocoaPodsが必要な場合は `sudo gem install cocoapods` またはHomebrew経由で導入する。
5. このリポジトリで `flutter pub get` を実行する。

## 3. iOSターゲットを確認する

1. `ios/Runner.xcworkspace` をXcodeで開く。
2. RunnerターゲットのBundle Identifierを決めたBundle IDに合わせる。
3. Signing & CapabilitiesでTeamを選択する。
4. Deployment Targetを決める。
5. App Icon、Display Name、Launch Screen、権限説明文を確認する。
6. Supabase OAuth、URL Scheme、Universal Links、Push Notificationsなど、このアプリで使うCapabilityを追加する。

## 4. アプリ内設定を本番向けに揃える

1. `lib/main_mobile.dart` をiOSエントリポイントとして確認する。
2. Web専用APIへの直接依存がiOSビルドへ入っていないか確認する。
3. Supabase URL、anon key、Firebase設定などを `--dart-define` または安全な設定経路で渡す。
4. ログ、デバッグUI、開発用バナーが本番ビルドで出ないことを確認する。
5. App Tracking Transparency、写真、通知、マイク等を使う場合はInfo.plistの説明文を実利用に合わせる。

## 5. ローカルでビルドする

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build ios --release --target lib/main_mobile.dart
```

ビルドが通ったら、Xcodeで実機またはSimulator起動を確認する。App Store提出前は実機でログイン、主要画面、AI大学、資産管理、共有、通知、外部リンク遷移を最低1周する。

## 6. Archiveを作成する

1. Xcodeで `ios/Runner.xcworkspace` を開く。
2. SchemeをRunner、Build ConfigurationをReleaseにする。
3. 実機向けDestinationとして `Any iOS Device` を選ぶ。
4. Product > Archiveを実行する。
5. OrganizerでArchiveが作成されたことを確認する。
6. Validate Appで署名、Bundle ID、Entitlementsのエラーを潰す。

## 7. App Store Connectにアプリレコードを作る

1. App Store Connectで新規アプリを作成する。
2. 名前、プライマリ言語、Bundle ID、SKUを入力する。
3. カテゴリ、年齢制限、価格、配信地域を設定する。
4. Privacy Nutrition Labelsを入力する。
5. サインインが必要な場合は審査用アカウントを用意する。

## 8. TestFlightへアップロードする

1. Xcode OrganizerからDistribute Appを選ぶ。
2. App Store Connectを選んでUploadする。
3. App Store ConnectのTestFlightにビルドが出るまで待つ。
4. Export Compliance、暗号化、輸出規制の質問に回答する。
5. Internal Testingへ追加し、自分と関係者で動作確認する。

## 9. App Review提出前チェック

1. クラッシュがない。
2. ログインできる。
3. 課金、外部決済、広告、ユーザー生成コンテンツがガイドラインに沿っている。
4. アプリ説明と実機挙動が一致している。
5. プライバシーポリシーURL、サポートURLが有効。
6. 審査用アカウントでAI大学・Home・WBS・資産管理など主要機能に入れる。
7. Web版への単なる誘導アプリに見えないよう、iOSアプリとして使える体験になっている。

## 10. App Storeへ提出する

1. App Store Connectで提出対象ビルドを選択する。
2. スクリーンショット、説明文、キーワード、サポートURL、プライバシーポリシーを入力する。
3. Review Notesにログイン手順、AI生成機能、外部API利用、テスト観点を書く。
4. Submit for Reviewを押す。
5. リジェクトされた場合はResolution Centerの指摘をIssue化し、修正PR、再ビルド、再提出の順で対応する。

## 11. CI/CDの次の改善

- 現状の `.github/workflows/mobile-release-build.yml` はiOS simulator artifactを作る段階。
- App Store提出用には、GitHub Actions macOS runnerで署名済み`.ipa`を作るために、Apple証明書、provisioning profile、App Store Connect API keyをGitHub Secretsへ入れる。
- Fastlaneを導入すると、`match`、`gym`、`pilot`、`deliver` で証明書管理、ビルド、TestFlightアップロード、メタデータ更新を自動化しやすい。
- 完全自動化する場合も、App Review提出前の人間チェックだけはWBS承認タスクとして残す。

## 参考公式ドキュメント

- Flutter: Build and release an iOS app — https://docs.flutter.dev/deployment/ios
- Apple Developer Program — https://developer.apple.com/programs/
- App Store Connect Help — https://developer.apple.com/help/app-store-connect/
- App Review Guidelines — https://developer.apple.com/app-store/review/guidelines/
