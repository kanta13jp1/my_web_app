---
title: "Flutter Localization Complete Guide — Building Multi-Language Apps with i18n"
tags: flutter,ai,indiedev,dart
published: true
---

# Flutter Localization Complete Guide — Building Multi-Language Apps with i18n

Going global with your Flutter app requires proper localization. In this guide, we'll implement Japanese/English language switching using Flutter's official `flutter_localizations` package and `intl`.

## Why Localization Matters

For indie developers targeting the global market, supporting at least Japanese and English is essential. Flutter has built-in support for `Locale` and `LocalizationsDelegate`, making multi-language support achievable with minimal code.

## Setup

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

## Managing Strings with ARB Files

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

## Integrating with MaterialApp

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const HomePage(),
)
```

## Using Translated Strings

```dart
// In any Widget
Text(AppLocalizations.of(context)!.greeting('kanta'))
```

## Localizing Numbers and Dates

```dart
import 'package:intl/intl.dart';

final formatter = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
print(formatter.format(1980)); // ¥1,980

final dateFormatter = DateFormat.yMMMd('en');
print(dateFormatter.format(DateTime.now())); // Dec 23, 2028
```

## Dynamic Language Switching

Manage Locale with Riverpod to allow switching from a settings screen:

```dart
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

// MaterialApp
MaterialApp(
  locale: ref.watch(localeProvider),
  ...
)

// Settings screen
ElevatedButton(
  onPressed: () => ref.read(localeProvider.notifier).state = const Locale('ja'),
  child: const Text('日本語に切り替え'),
)
```

## Persisting with Supabase

Save the user's language preference in Supabase for cross-device sync:

```dart
// Save language preference
await supabase.from('user_settings')
  .upsert({'user_id': userId, 'locale': 'en'});

// Load on startup
final data = await supabase.from('user_settings')
  .select('locale')
  .eq('user_id', userId)
  .single();
ref.read(localeProvider.notifier).state = Locale(data['locale']);
```

## Summary

Flutter's i18n system uses ARB files with `flutter gen-l10n` for type-safe string management. Combined with Riverpod, dynamic locale switching is straightforward. If you're planning to go global, implement localization early in your project.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
