---
title: "Flutter Webで比較ページからの流入をSupabase Edge Functionで計測するCVRトラッキング実装"
tags: Flutter,Supabase,EdgeFunction,buildinpublic,個人開発
published: true
---

# Flutter Webで比較ページからの流入をSupabase Edge Functionで計測するCVRトラッキング実装

## タイトル案
1. Flutter Webで「どの比較ページから登録したか」を追跡するCVRトラッキングを実装した話
2. 21競合比較ページの流入をSupabase Edge Functionで計測する — route-level acquisition signal
3. StatelessWidget→StatefulWidgetへの安全な移行と獲得シグナル記録パターン

## 投稿先候補
- [x] Zenn
- [x] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article

## 本文下書き

### はじめに

自分株式会社 (https://my-web-app-b67f4.web.app/) はNotion・Evernote・Slack・MoneyForwardなど21の競合SaaSを代替するAI統合プラットフォームです。

各競合に対して `/vs-notion`、`/vs-slack` のような比較ページを21本用意しています。しかし「このページを見た人が実際に登録したのか？」を計測できていませんでした。

今回、**比較ページ経由の CVR トラッキング** を実装しました。

### 課題

比較ページ (`ComparisonPage`) は `StatelessWidget` で実装されていました。ページ閲覧時に何かを記録するには `initState` が必要なため、`StatefulWidget` への移行が必要です。

また、既存の `GrowthAcquisitionService` は `/`（LP）・`/import`・`/public-memo`・`/referral` の4経路しか対応していませんでした。

### 実装方法

#### 1. GrowthAcquisitionService に比較ページ対応を追加

```dart
// 新しいシグナル定数
static const String touchComparison = 'touch_comparison';
static const String signupSubmitComparison = 'signup_submit_comparison';

// signalForPagePath を /vs-* に対応
static String? signalForPagePath(String pagePath) {
  if (pagePath.startsWith('/vs-')) {
    return touchComparison;
  }
  // ... 既存のswitch
}

// resolveSignupSubmitSignal に比較ページ経由を追加
case touchComparison:
  return signupSubmitComparison;

// 比較ページ訪問を記録するメソッド
Future<void> recordComparisonTouch(String competitorKey) async {
  await _persistLatestTouchpoint(touchComparison);
  await _recordSignal('touch_comparison_$competitorKey');
}
```

ポイントは `touch_comparison_notion`、`touch_comparison_slack` のように **競合キーごとに個別シグナルを記録** する点。これにより「どの比較ページが最もCVRに貢献しているか」をグラニュラーに分析できます。

#### 2. _ComparisonShell を StatelessWidget → StatefulWidget へ移行

```dart
// Before
class _ComparisonShell extends StatelessWidget {
  final _CompetitorInfo info;
  const _ComparisonShell({required this.info});
  ...
}

// After
class _ComparisonShell extends StatefulWidget {
  final _CompetitorInfo info;
  final String competitorKey;  // 追加
  const _ComparisonShell({required this.info, required this.competitorKey});

  @override
  State<_ComparisonShell> createState() => _ComparisonShellState();
}

class _ComparisonShellState extends State<_ComparisonShell> {
  static const _acquisitionService = GrowthAcquisitionService();

  @override
  void initState() {
    super.initState();
    // ページ表示時に即座にシグナル記録（fire-and-forget）
    unawaited(_acquisitionService.recordComparisonTouch(widget.competitorKey));
  }

  _CompetitorInfo get _info => widget.info;

  @override
  Widget build(BuildContext context) { ... }
}
```

`unawaited()` を使うことで、ネットワークリクエストがUIをブロックしません。

#### 3. ComparisonPage からキーを渡す

```dart
class ComparisonPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final info = _competitorInfo[competitorKey.toLowerCase()] ?? _defaultInfo;
    return _ComparisonShell(
      info: info,
      competitorKey: competitorKey.toLowerCase(),  // 追加
    );
  }
}
```

### 詰まったポイント

`StatelessWidget` から `StatefulWidget` への移行時、元のウィジェットが持っていた `info` フィールドへのアクセスがすべて `widget.info`（または `_info` ゲッター）に変わります。見落としがちなのでgrepで確認が必要です。

```bash
grep -n "^\s*\bininfo\b\|[^_]info\." lib/pages/comparison_page.dart
```

### flutter analyze 0件維持

変更後は必ず `flutter analyze` を実行：

```bash
flutter analyze
# → No issues found!
```

### まとめ

- `/vs-*` の14比較ページすべてで訪問シグナルが記録されるようになりました
- どの競合比較ページ経由で登録が多いかを `signup_submit_comparison` シグナルで計測可能
- この情報をもとに、CVRが高い比較ページに投資を集中できます

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #CVR #グロース
