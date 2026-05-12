-- AI University Android department content:
-- Step-by-step playbook for releasing this Flutter app as an Android app.

WITH mobile_faculty AS (
  SELECT id
  FROM university_faculties
  WHERE faculty_code = 'mobile'
  LIMIT 1
),
android_department AS (
  SELECT d.id
  FROM university_departments d
  JOIN mobile_faculty f ON d.faculty_id = f.id
  WHERE d.department_code = 'android'
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
  'jibun-android-release',
  'tutorial',
  'Androidアプリ公開手順: 自分株式会社アプリをInternal testingからGoogle Playへ出す',
  $android_release$
## この教材のゴール

このFlutterアプリをAndroidアプリとしてリリースするために、Google Play Internal testingへの配布からProduction公開までを順番に進められる状態にします。対象は `lib/main_mobile.dart` を入口にしたモバイル版です。

## 1. Google Play Developer側の準備

1. Google Play Consoleに登録します。
2. 開発者名、連絡先、本人確認、支払いプロファイルを完了します。
3. アプリ名、既定言語、無料/有料、アプリ/ゲーム区分を決めます。
4. プライバシーポリシーURL、サポートURL、審査用ログインアカウントを用意します。
5. Data safetyフォームに回答できるよう、収集データと共有データを棚卸しします。

## 2. Android開発環境を整える

1. Android Studioの安定版をインストールします。
2. Android SDK、Platform Tools、Build Tools、Emulatorを入れます。
3. Flutter stableで `flutter doctor` を通します。
4. リポジトリで `flutter pub get` を実行します。
5. WindowsではJDKとAndroid SDKのパスがFlutterから見えることを確認します。

## 3. アプリIDとリリース設定を決める

1. `android/app/build.gradle` または `android/app/build.gradle.kts` の `applicationId` を確認します。
2. 例として `jp.co.jibun.mywebapp` のような、公開後に変えないIDへ固定します。
3. Google Playへアップロードするたびに `versionCode` を増やします。
4. `versionName` はヘッダー表示やリリースノートと揃えます。
5. `minSdk`、`targetSdk`、`compileSdk` をFlutterとGoogle Play要件に合わせます。

## 4. 本番ビルド前チェック

1. Supabase URL、Anon key、Firebase設定を `--dart-define` など安全な経路で渡します。
2. Web専用importやブラウザ専用APIがAndroidリリースに混ざっていないか確認します。
3. OAuthリダイレクト、Deep Link、外部リンク遷移を実機で確認します。
4. 通知、カメラ、マイク、写真、位置情報など、使う権限だけを `AndroidManifest.xml` に残します。
5. 開発用ログ、デバッグバナー、テスト用URLを外します。

## 5. 署名鍵を用意する

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

1. `upload-keystore.jks` はGitへコミットしません。
2. `android/key.properties` もコミットしません。
3. CIで署名する場合は、keystoreをBase64化してGitHub Secretsへ保存します。
4. 鍵の保管場所と復旧手順をWBSに残します。

## 6. リリースビルドを作る

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --target lib/main_mobile.dart
```

Google Playへは通常 `build/app/outputs/bundle/release/app-release.aab` をアップロードします。実機確認用にはAPKも作れます。

```bash
flutter build apk --release --target lib/main_mobile.dart
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 7. Internal testingへ配布する

1. Play Consoleで新規アプリを作ります。
2. Store listing、App access、Content rating、Data safety、Privacy policyを入力します。
3. Testing > Internal testingでリリースを作成します。
4. `app-release.aab` をアップロードします。
5. テスターを追加し、Start rollout to Internal testingを実行します。
6. 実機でHome、AI大学、WBS、資産管理、共有、ログインを確認します。

## 8. Closed/Open testingへ進める

1. Internal testingでクラッシュとANRがないことを確認します。
2. Closed testingで少人数に配布し、主要導線と端末互換性を確認します。
3. 必要ならOpen testingで追加検証します。
4. Play ConsoleのPre-launch reportでクラッシュ、アクセシビリティ、セキュリティ警告を確認します。
5. 未解決の問題はGitHub Issue化し、WBSの遅延タスクへ反映します。

## 9. Productionへ公開する

1. Production trackで新しいリリースを作ります。
2. テスト済みのAABを選びます。
3. リリースノート、審査用アカウント、審査メモを最終確認します。
4. Review releaseで警告を確認し、Productionへ送信します。
5. 最初は段階的公開にして、クラッシュ率、ANR、レビュー、問い合わせを監視します。

## 10. 自動化ロードマップ

- GitHub Actionsで `flutter build appbundle --release --target lib/main_mobile.dart` を定期実行します。
- keystoreとPlay Console service accountをGitHub Secretsに登録し、内部テスト配布を自動化します。
- Fastlane `supply` を使うと、AABアップロード、リリースノート、メタデータ更新を自動化できます。
- Production rollout前だけはWBS承認タスクとして人間確認を残します。

## 公式参照

- Flutter Android deployment: https://docs.flutter.dev/deployment/android
- Android app signing: https://developer.android.com/studio/publish/app-signing
- Google Play Console Help: https://support.google.com/googleplay/android-developer/
- Create and set up your app: https://support.google.com/googleplay/android-developer/answer/9859152
$android_release$,
  'https://docs.flutter.dev/deployment/android',
  DATE '2026-05-01',
  11,
  true,
  mobile_faculty.id,
  android_department.id
FROM mobile_faculty, android_department
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
  'AI大学 Android学科: Google Play公開手順教材を追加',
  'Android学科に、このFlutterアプリをInternal testingからGoogle Play Productionへ公開するためのステップバイステップ教材を追加。Google Play Developer準備、Android Studio環境、applicationId/versionCode、署名鍵、AABビルド、Internal/Closed/Open testing、Production rollout、Fastlane/CI自動化までを整理。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
