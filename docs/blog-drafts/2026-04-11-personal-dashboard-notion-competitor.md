---
title: "Flutter Web でNotion 3.4対抗「パーソナルダッシュボード」を実装した話 — KPIチャートをゼロから作る"
tags: Flutter,Supabase,buildinpublic,Notion
topics: ["Flutter", "Supabase", "buildinpublic", "個人開発"]
published: true
---

# ブログ下書き 2026-04-11 — 2026-04-11-personal-dashboard-notion-competitor

## タイトル案

1. Flutter Web でNotion 3.4対抗「パーソナルダッシュボード」を実装した話 — KPIチャートをゼロから作る
2. Notion Dashboard対抗機能をFlutter Webで実装 — LinearProgressIndicatorとCustomBarChartで週次分析
3. 自分株式会社の全56機能をランディングページで訴求するLP戦略と個人KPIダッシュボード実装

## 投稿先候補

- [ ] Zenn
- [ ] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] dev.to

---

## 本文下書き (約2000字)

### はじめに

Notionが2024年末から2025年にかけて「ダッシュボードビュー」を強化し、KPIカードや棒グラフを Notion Agent が自動ビルドする機能 (Notion 3.4) をリリースしました。

これを受けて、自分株式会社でも **「パーソナルダッシュボード」** ページを実装しました。ノート数・タスク完了数・習慣ストリーク・集中時間を可視化する個人KPIダッシュボードです。

Flutter Web 特有の制約 (グラフライブラリなし・Canvas 描画コスト) の中で、どのように実装したかを紹介します。

---

### なぜグラフライブラリを使わないのか

Flutter でグラフを描くと言えば `fl_chart` や `charts_flutter` が定番ですが、自分株式会社では **パッケージ追加を最小限に抑える** 方針を採っています。理由は 2 つ:

1. **ビルドサイズ**: Flutter Web は初回ロードが重い。ライブラリ追加のたびに JS バンドルが増える
2. **Flutter analyze 0件維持**: 外部パッケージの deprecated API に引きずられるリスクを避ける

代わりに使うのが `LinearProgressIndicator` と `FractionallySizedBox` を組み合わせた **標準ウィジェットバーチャート** です。

### 実装: 棒グラフをゼロから作る

```dart
Widget _barChartSection(
  String title, IconData icon, Color color,
  List<Map<String, dynamic>> data, String key, int maxVal,
) {
  return Column(
    children: [
      // タイトル行
      Row(children: [Icon(icon, color: color), Text(title)]),
      SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((day) {
            final val = (day[key] as num?)?.toInt() ?? 0;
            final heightRatio = maxVal > 0 ? val / maxVal : 0.0;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 値ラベル
                  if (val > 0) Text(val.toString(), style: TextStyle(color: color)),
                  // バー本体: FractionallySizedBox で高さを割合指定
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightRatio.clamp(0.02, 1.0),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 日付ラベル
                  Text(day['date'] as String? ?? '', style: const TextStyle(fontSize: 9)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
}
```

ポイントは `FractionallySizedBox(heightFactor: heightRatio)` で最大値に対する割合を高さに変換すること。`clamp(0.02, 1.0)` で 0件の日もわずかに表示します。

### KPI カードグリッド

```dart
GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(), // スクロール競合を防ぐ
  childAspectRatio: 1.5,
  children: [
    _kpiCard('総ノート数', totalNotes.toString(), Icons.note_alt, Color(0xFF7C3AED), ...),
    _kpiCard('タスク完了', tasksCompleted.toString(), Icons.task_alt, Color(0xFF059669), ...),
    _kpiCard('集中時間', '${focusHours}h', Icons.timer, Color(0xFFDC2626), ...),
    _kpiCard('習慣ストリーク', '${habitStreak}日', Icons.local_fire_department, Color(0xFFF59E0B), ...),
  ],
)
```

`GridView.count` + `shrinkWrap: true` + `NeverScrollableScrollPhysics` の組み合わせは、`SingleChildScrollView` の中にグリッドを埋め込む定番パターンです。`physics: NeverScrollableScrollPhysics()` を忘れると GridView 内でスクロールが止まり、外側の ScrollView が動かなくなります。

### Edge Function 連携とフォールバック

```dart
try {
  final res = await _supabase.functions.invoke(
    'personal-dashboard',
    body: {'action': 'get_overview', 'user_id': userId},
  );
  // データ読み込み
} catch (_) {
  // Edge Function 未デプロイ時はフォールバックデータを使用
  setState(() {
    _kpiData = _buildFallbackKpi();
    _weeklyActivity = _buildFallbackWeekly();
  });
}
```

Edge Function (`personal-dashboard`) はまだコードのみ存在 (Tier2) の状態でも、フォールバックで 0 件表示します。**「UI を先に作り、バックエンドをあとから接続する」** Edge Function First パターンです。

### LP への追加: 52→56のこと

今回の実装と同時に、LP の `_buildUniqueValueSection()` に 4 機能を追加しました:

- アクセス制御・権限管理 (`/access-control`)
- 在庫・バーコード管理 (`/inventory-barcode`)
- テンプレート広場 (`/templates`)
- パーソナルダッシュボード (`/personal-dashboard`)

既存の 52 から **56のこと** に更新。ランディングページのタイトルも「自分株式会社でしかできない56のこと」に変更しました。

### 詰まったポイント

**withValues(alpha:) と withOpacity の違い**

`color.withOpacity(0.1)` は Flutter 3.26.0 以降 deprecated になっています。代わりに:

```dart
// NG
color: color.withOpacity(0.12),

// OK
color: color.withValues(alpha: 0.12),
```

`flutter analyze` で `deprecated_member_use` 警告が出たら一括置換します。

**GridView 内の childAspectRatio 調整**

KPI カードの `childAspectRatio` は縦横比に直接影響します。カードのコンテンツが縦に長い場合は `1.5` → `1.3` に下げる必要があります。`flutter analyze` では検出できないので視覚確認が必要です。

### まとめ

- グラフライブラリなしで `FractionallySizedBox` を使って棒グラフを実装
- `GridView.count` + `shrinkWrap` + `NeverScrollableScrollPhysics` の定番パターン
- Edge Function フォールバックで UI を先行リリース可能
- LP の機能数を 52 → 56 に拡張

自分株式会社は Notion・Evernote・MoneyForward・Slack を超える統合プラットフォームを目指して毎日実装を続けています。

サービス URL: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #Notion代替
