---
title: 21競合の比較ページCVRをFlutter+Supabaseで計測・可視化した話
emoji: 📊
type: tech
topics: [flutter, supabase, analytics, growth, dart]
published: false
---

# 21競合の比較ページCVRをFlutter+Supabaseで計測・可視化した話

自分株式会社というAI統合ライフマネジメントアプリを個人開発しています。
Notion・Evernote・Slack・MoneyForward・Discord・LINEなど21競合を意識した比較ページ（`/vs-notion`、`/vs-slack` etc.）を実装しているのですが、「どの競合ページからユーザーが実際に登録しているのか」がわからない問題がありました。

今回はその**比較ページ経由のCVR計測・可視化**を実装した話を紹介します。

## 解決したい課題

- 21社の比較ページ（`/vs-notion`〜`/vs-github`）を実装済み
- 各ページへの到達は追跡できていたが、**どのページから登録が生まれているか**が不明
- 管理者ダッシュボードに比較ページ別CVRの表示が存在しなかった

## 実装したこと

### 1. シグナルタイプの定義

`growth_acquisition_service.dart` にシグナル定数を追加：

```dart
static const String touchComparison = 'touch_comparison';
static const String signupSubmitComparison = 'signup_submit_comparison';
```

比較ページ訪問時は `touch_comparison_{competitor}` (例: `touch_comparison_notion`) を記録し、
最新タッチポイントとして `touch_comparison` を保存。
登録時にタッチポイントを解決して `signup_submit_comparison` を記録する設計です。

```dart
static String resolveSignupSubmitSignal(String? latestTouchpoint) {
  switch (latestTouchpoint) {
    case touchComparison:
      return signupSubmitComparison;
    // ...その他のチャネル
    default:
      return signupSubmitLanding;
  }
}
```

### 2. シグナルのストレージ設計

全シグナルは `app_analytics` テーブルの `source_details` JSONB カラムに日次集計します：

```json
{
  "touch_comparison_notion": 42,
  "touch_comparison_slack": 18,
  "signup_submit_comparison": 3
}
```

Edge Function (`growth-acquisition-signal`) 経由で書き込み、フロントエンドのフォールバックもあります。

### 3. 管理者ダッシュボードへの可視化

`AdminAnalyticsPage` に `_buildComparisonCvrCard()` を追加。
`app_analytics` の全日付の `source_details` を集計して表示します：

```dart
Future<void> _loadComparisonCvr() async {
  final rows = await _supabase.from('app_analytics').select('source_details');
  final touches = <String, int>{};
  var signups = 0;
  for (final row in rows) {
    final sd = row['source_details'];
    if (sd is! Map) continue;
    sd.forEach((key, value) {
      final k = key.toString();
      final v = (value is num) ? value.toInt() : 0;
      if (k.startsWith('touch_comparison_')) {
        final competitor = k.replaceFirst('touch_comparison_', '');
        touches.update(competitor, (c) => c + v, ifAbsent: () => v);
      } else if (k == 'signup_submit_comparison') {
        signups += v;
      }
    });
  }
  // setState...
}
```

UIはLinearProgressIndicatorで各競合の相対的な到達数を棒グラフ風に可視化：

```
notion  ████████████████ 42
slack   ████████         18
discord ████             11
...
CVR: 比較到達71件 → 登録3件 = 4.2%
```

## ハマったポイント

**IDEがファイルを自動リバートする問題**

`flutter analyze` を実行したタイミングで、編集したファイルが元のバージョンに戻ってしまうことがありました。
これはDartの自動フォーマッタとIDEのインテグレーションが競合したケースです。
対策として、`flutter analyze` 実行後に対象ファイルの内容を確認し、必要なら再適用するようにしました。

**JSONB集計の設計**

シグナルを個別テーブルにするか JSONB にするかで迷いましたが、
- 日次集計はバッチ更新が多い
- キー名が動的（`touch_comparison_{competitor_key}`）
- 管理コストを下げたい

の理由でJSONBのまま使う設計を選択しました。競合が増えてもスキーマ変更不要です。

## 今後の改善

現在の実装では「どの比較ページから登録した」という **per-competitorの登録CVR** は計測できません。
タッチポイントは最後に訪問した比較ページを保存するため、
「notion → slack → 登録」の場合は `signup_submit_comparison` のみ記録されます。

今後は登録フォームに hidden field で直前の比較ページ（`last_comparison`）を付与し、
`signup_submit_comparison_notion` のような競合別登録シグナルを記録する改善を検討中です。

## まとめ

- 21社の比較ページ経由のCVR計測を `app_analytics.source_details` JSONB で実装
- 管理者ダッシュボードに `_buildComparisonCvrCard()` で可視化
- `touch_comparison` → `signup_submit_comparison` のファネルを確立
- `flutter analyze` 0件を維持

シンプルな設計でもデータドリブンなグロース改善の第一歩として機能します。

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #Growth #Analytics #buildinpublic
