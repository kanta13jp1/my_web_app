---
title: "Flutter Web で旅行プランナー・リアルタイムホワイトボード・レシピ管理を同時実装した話"
tags: Flutter,Supabase,個人開発,buildinpublic,EdgeFunctions
published: true
---

# ブログ下書き 2026-04-03 — 2026-04-03-travel-whiteboard-recipe

## タイトル案

1. **Flutter Webで旅行プランナー・ホワイトボード・レシピ管理を同時実装 — 3競合SaaSを1アプリで超える方法**
2. **Edge Function Firstで旅行・ホワイトボード・料理管理を実装した話 — Google Travel/Miro/クックパッドに挑む**
3. **1日3機能追加 — Flutter WebとSupabase Edge Functionで21競合SaaSを超えるAI統合アプリの開発記録**

## 投稿先候補

- [x] Zenn
- [x] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article

## 本文下書き (約2000字)

### はじめに

自分株式会社 は「Notion・Evernote・MoneyForward・Slack など21の競合SaaSを1つに統合する」をビジョンに掲げた Flutter Web + Supabase のライフマネジメントアプリです。

2026-04-03 の daily-development セッションでは、以下の3機能を一気に実装しました:

1. **旅行プランナー** (`/travel-itinerary`) — Google Travel / TripAdvisor 競合
2. **バーチャルホワイトボード** (`/virtual-whiteboard`) — Miro / Microsoft Whiteboard 競合
3. **レシピ・食事プランナー** (`/recipe-meal-planner`) — Amazon Fresh / クックパッド競合

それぞれ対応する Supabase Edge Function がすでに存在していたので、Flutter 側の UI を実装するだけで完成させることができました。この「Edge Function First」パターンが今回のポイントです。

---

### 実装方法

#### 1. Edge Function First パターン

自分株式会社の開発原則は「複雑な処理はバックエンドへ」です。今回の3機能はすべて、以下のように Edge Function がすでに存在していました:

- `travel-itinerary-planner` — 旅行プラン・日程・予約・パッキング・予算管理
- `virtual-whiteboard` — ボード・付箋・図形・テンプレート管理
- `recipe-meal-planner` — レシピ・献立・買い物リスト自動生成・栄養計算

Flutter 側は Edge Function を呼び出すだけでよく、ビジネスロジックをフロントエンドに持ち込まずに済みます。

```dart
// 旅行プランナーの例: Edge Function 呼び出し
final response = await _supabase.functions.invoke(
  'travel-itinerary-planner',
  queryParameters: {'view': 'itinerary', 'trip_id': tripId},
);
final data = response.data;
if (data is Map<String, dynamic> && data['itinerary'] is Map) {
  final raw = data['itinerary'] as Map;
  setState(() {
    _itinerary = raw.map(
      (k, v) => MapEntry(
        k.toString(),
        (v as List).cast<Map<String, dynamic>>(),
      ),
    );
  });
}
```

#### 2. TabController で多機能 UI を整理

旅行プランナーは4タブ(日程/予約/持ち物/予算)、ホワイトボードは2タブ(マイボード/テンプレート)、レシピは3タブ(レシピ/献立/買い物)という構成です。`SingleTickerProviderStateMixin` + `TabController` でシンプルに管理できます。

```dart
class _TravelItineraryPageState extends State<TravelItineraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchTrips();
  }
```

#### 3. deprecated API の回避 — RadioListTile → Icon + ListTile

Flutter 3.32.0 以降、`RadioListTile` の `groupValue`/`onChanged` が deprecated になりました。`RadioGroup` に移行するのが正式ですが、シンプルなダイアログでは以下のようにアイコンで代替できます:

```dart
// before (deprecated)
RadioListTile<String>(
  value: tmplId,
  groupValue: _selectedTemplateId,
  onChanged: (v) => setState(() => _selectedTemplateId = v),
)

// after (flutter 3.32.0+ 対応)
ListTile(
  leading: Icon(
    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
    color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
    size: 20,
  ),
  selected: isSelected,
  onTap: () => setState(() => _selectedTemplateId = tmplId),
)
```

#### 4. require_trailing_commas の一括対応

Dart の `require_trailing_commas` lint ルールは、関数呼び出しの最後の引数にカンマを要求します。長い引数を複数行に分けることで自然に対応できます:

```dart
// before: trailing comma missing
_budgetStat('残高', '¥${_formatNum(remaining)}',
    remaining >= 0 ? Colors.green : Colors.red),

// after: trailing comma added
_budgetStat(
  '残高',
  '¥${_formatNum(remaining)}',
  remaining >= 0 ? Colors.green : Colors.red,
),
```

---

### 詰まったポイント

#### ホームカタログの `HomeTool` vs `HomeToolEntry`

ツールカタログへのエントリ追加時に `HomeTool` と書いてしまい、コンパイルエラーが出ました。正しいクラス名は `HomeToolEntry` です。この種のミスはすぐに `flutter analyze` で検出できるので、実装後は必ず analyze を実行するのがルールです。

#### `const` コンストラクタの最適化

Flutter の `prefer_const_constructors` と `prefer_const_literals_to_create_immutables` は、ウィジェットが変更されない場合に `const` を付けることを要求します。特に `Column` の `children` など `const` リストにできる場合は外側の `Center` や `Column` ごと `const` にする必要があります:

```dart
// before
return Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.flight_takeoff, size: 64, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('旅行プランがありません'),
    ],
  ),
);

// after: 外側から const に
return const Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.flight_takeoff, size: 64, color: Colors.grey),
      SizedBox(height: 16),
      Text('旅行プランがありません'),
    ],
  ),
);
```

---

### まとめ

- Edge Function First パターンにより、UI 実装に集中できる
- `flutter analyze 0件` を常に維持することで、deprecated API や lint ミスを即座に検出
- 3機能を1セッションで実装でき、21競合SaaSへの機能パリティが着実に向上

自分株式会社は現在 241 Edge Functions、160+ ページを実装しており、毎日機能を追加し続けています。

→ サービスURL: https://my-web-app-b67f4.web.app/

#FlutterWeb #Supabase #buildinpublic #EdgeFunction
