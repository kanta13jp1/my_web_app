-- AI University iOS department content:
-- Step-by-step playbook for releasing this Flutter app as an iOS app.

WITH mobile_faculty AS (
  SELECT id
  FROM university_faculties
  WHERE faculty_code = 'mobile'
  LIMIT 1
),
ios_department AS (
  SELECT d.id
  FROM university_departments d
  JOIN mobile_faculty f ON d.faculty_id = f.id
  WHERE d.department_code = 'ios'
  LIMIT 1
)
INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active,
  faculty_id,
  department_id
)
SELECT
  'jibun-ios-release',
  'tutorial',
  'iOSアプリ公開手順: 自分株式会社アプリをTestFlightからApp Storeへ出す',
  $ios_release$
## この教材のゴール

このFlutterアプリをiOSアプリとしてリリースするために、TestFlight配布からApp Store公開までを順番に進められる状態にします。対象は `lib/main_mobile.dart` を入口にしたモバイル版です。

## 1. Apple側の準備

1. Apple Developer Programに登録する。
2. App Store Connectへ入れることを確認する。
3. Certificates, Identifiers & ProfilesでBundle IDを作る。
4. Bundle IDは公開後に変えにくいため、例: `jp.co.jibun.mywebapp` のように固定する。
5. Push通知、Sign in with Apple、Universal Linksなど必要なCapabilityを先に洗い出す。

## 2. MacとXcodeを準備

1. 最新の安定版Xcodeをインストールする。
2. Xcodeを1度起動し、ライセンス同意と追加コンポーネント導入を済ませる。
3. Flutter stableを用意して `flutter doctor` を通す。
4. リポジトリで `flutter pub get` を実行する。
5. 必要ならCocoaPodsを導入する。

## 3. XcodeでiOSターゲットを設定

1. `ios/Runner.xcworkspace` を開く。
2. RunnerターゲットのBundle IdentifierをApple Developerで作ったBundle IDに合わせる。
3. Signing & CapabilitiesでTeamを選ぶ。
4. Display Name、App Icon、Launch Screen、Deployment Targetを確認する。
5. Info.plistの権限説明文を、実際に使う写真、通知、マイク、カメラ等に合わせる。

## 4. 本番ビルド前チェック

1. Web専用APIがiOSビルドに混ざっていないか確認する。
2. Supabase/Firebase等の本番設定を `--dart-define` や安全な設定経路で渡す。
3. デバッグバナー、開発用ログ、テスト用URLを外す。
4. OAuthリダイレクトURI、Deep Link、外部リンク遷移をiOS実機で確認する。

## 5. Flutterでローカル検証

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build ios --release --target lib/main_mobile.dart
```

この段階で落ちたら、Dart/Flutter側の問題です。Xcode署名前に直します。

## 6. Archiveを作る

1. XcodeでRunner schemeを選ぶ。
2. Destinationを `Any iOS Device` にする。
3. Product > Archiveを実行する。
4. OrganizerでValidate Appを実行し、署名、Bundle ID、Entitlementsを確認する。

## 7. App Store Connectにアプリを作る

1. App Store Connectで新規アプリを作成する。
2. 名前、言語、Bundle ID、SKUを入力する。
3. カテゴリ、年齢制限、価格、配信地域を設定する。
4. Privacy Nutrition Labelsを入力する。
5. サインインが必要な場合は審査用アカウントを用意する。

## 8. TestFlightへ配布

1. Xcode OrganizerからDistribute Appを選ぶ。
2. App Store ConnectへUploadする。
3. TestFlightにビルドが出るまで待つ。
4. Export Complianceの質問に回答する。
5. Internal Testingで、Home、AI大学、WBS、資産管理、共有、ログインを実機確認する。

## 9. App Review提出

1. スクリーンショット、説明文、キーワード、サポートURL、プライバシーポリシーURLを入力する。
2. Review Notesにログイン手順、AI生成機能、外部API利用、審査用アカウントを書く。
3. 提出前に「Web版への単なる誘導」ではなく、iOSアプリとして主要機能が使えることを確認する。
4. Submit for Reviewを押す。
5. リジェクトされた場合はResolution Centerの指摘をGitHub Issue化し、修正PR、再ビルド、再提出の順で進める。

## 10. 自動化ロードマップ

- 現在の `mobile-release-build.yml` はiOS simulator artifactを作る段階。
- App Store提出用には、署名済み `.ipa` を作るmacOS CI、Apple証明書、provisioning profile、App Store Connect API keyが必要です。
- Fastlaneを導入すると、証明書管理、Archive、TestFlightアップロード、メタデータ更新を自動化できます。
- ただしApp Review提出前の最終確認は、WBSのユーザー承認タスクとして残すのが安全です。

## 公式参照

- Flutter iOS deployment: https://docs.flutter.dev/deployment/ios
- Apple Developer Program: https://developer.apple.com/programs/
- App Store Connect Help: https://developer.apple.com/help/app-store-connect/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
$ios_release$,
  'https://docs.flutter.dev/deployment/ios',
  DATE '2026-05-01',
  10,
  true,
  mobile_faculty.id,
  ios_department.id
FROM mobile_faculty, ios_department
ON CONFLICT (provider, category) DO UPDATE
SET title = EXCLUDED.title,
    content = EXCLUDED.content,
    source_url = EXCLUDED.source_url,
    published_at = EXCLUDED.published_at,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active,
    faculty_id = EXCLUDED.faculty_id,
    department_id = EXCLUDED.department_id,
    updated_at = now();

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 iOS学科: App Store公開手順教材を追加',
  'iOS学科に、このFlutterアプリをTestFlightからApp Storeへ公開するためのステップバイステップ教材を追加。Apple Developer Program、Xcode署名、flutter build ios、Archive、App Store Connect、TestFlight、App Review、Fastlane自動化までを整理。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
