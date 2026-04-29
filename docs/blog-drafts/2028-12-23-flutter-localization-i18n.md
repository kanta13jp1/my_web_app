---
title: "Flutter ローカライズ完全ガイド — i18n で多言語対応アプリを作る"
tags: flutter,AI,個人開発,dart
published: true
---

# Flutter ローカライズ完全ガイド — i18n で多言語対応アプリを作る

Flutter アプリをグローバルに展開するには多言語対応が欠かせません。Flutter の公式 `flutter_localizations` パッケージと `intl` を使って、日本語・英語の切り替えを実装する手順を解説します。

## なぜローカライズが必要か

インディー開発者がグローバル市場を狙うなら、最低でも日本語・英語の 2 言語対応は必須です。Flutter はビルトインで `Locale` と `LocalizationsDelegate` をサポートしており、比較的少ないコードで多言語化できます。

## セットアップ

```yaml
# pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

flutter:
  generate: true
```

```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

## ARB ファイルで文字列管理

```json
// lib/l10n/app_en.arb
{
  "@@locale": "en",
  "appTitle": "My App",
  "@appTitle": { "description": "Application title" },
  "greeting": "Hello, {name}!",
  "@greeting": {
    "placeholders": {
      "name": { "type": "String" }
    }
  }
}
```

```json
// lib/l10n/app_ja.arb
{
  "@@locale": "ja",
  "appTitle": "マイアプリ",
  "greeting": "こんにちは、{name}さん！"
}
```

## MaterialApp に組み込む

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const HomePage(),
)
```

## 翻訳文字列の使い方

```dart
// Widget 内で
Text(AppLocalizations.of(context)!.greeting('kanta'))
```

## 数値・日付のローカライズ

```dart
// intl パッケージを使う
import 'package:intl/intl.dart';

final formatter = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
print(formatter.format(1980)); // ¥1,980

final dateFormatter = DateFormat.yMMMd('ja');
print(dateFormatter.format(DateTime.now())); // 2028年12月23日
```

## 動的な言語切り替え

Riverpod で Locale を管理して、設定画面から切り替え可能にします:

```dart
final localeProvider = StateProvider<Locale>((ref) => const Locale('ja'));

// MaterialApp
MaterialApp(
  locale: ref.watch(localeProvider),
  ...
)

// 設定画面
ElevatedButton(
  onPressed: () => ref.read(localeProvider.notifier).state = const Locale('en'),
  child: const Text('Switch to English'),
)
```

## Supabase との連携

ユーザーの言語設定を Supabase に保存して、デバイスをまたいで同期します:

```dart
// 言語設定を保存
await supabase.from('user_settings')
  .upsert({'user_id': userId, 'locale': 'ja'});

// 起動時に読み込み
final data = await supabase.from('user_settings')
  .select('locale')
  .eq('user_id', userId)
  .single();
ref.read(localeProvider.notifier).state = Locale(data['locale']);
```

## まとめ

Flutter の i18n は ARB ファイルと `flutter gen-l10n` で型安全に管理できます。Riverpod と組み合わせれば動的切り替えも簡単。グローバル展開を目指すなら早めに対応しておくのがおすすめです。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
