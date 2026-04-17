---
title: "DB駆動タブで新AIプロバイダーをゼロコード追加 — Flutter × Supabase 動的タブ設計"
tags: Flutter,Supabase,buildinpublic,個人開発,Dart
published: true
---

# DB駆動タブで新AIプロバイダーをゼロコード追加 — Flutter × Supabase 動的タブ設計

## 問題: 新プロバイダーを追加するたびにコードが増える

[自分株式会社](https://my-web-app-b67f4.web.app/) の「AI大学」機能は 66以上の AIプロバイダーを学習できる。LMSYS・Black Forest Labs・Liquid AI のように毎週新しい会社が登場するたびに、タブを1つ追加したい。

ハードコーディングだと:
1. `TabController` の `length` を修正
2. タブヘッダーウィジェットを追加
3. タブボディウィジェットを追加
4. コンテンツを追加
5. analyze → build → deploy

DB駆動なら:
1. `ai_university_content` に1行 INSERT

それだけ。タブが自動的に現れる。

---

## アーキテクチャ: DB をソースオブトゥルースに

```
Supabase: ai_university_content
  provider: 'lmsys'
  category: 'overview'
  content: '## LMSYS / Chatbot Arena\n...'
      ↓
Flutter: distinct providers を取得
      ↓
動的 TabController(length: providers.length)
      ↓
プロバイダーごとのタブ、コンテンツはオンデマンドで読み込み
```

Flutter の `_providerMeta` マップは *オプション* — 表示色と絵文字を追加する。マップにないプロバイダーはデフォルトアイコンで表示される。新プロバイダーは Flutter コード変更なしにタブとして現れる。

---

## Supabase: ai_university_content テーブル

```sql
CREATE TABLE ai_university_content (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  provider     text        NOT NULL,
  category     text        NOT NULL,
    -- 'overview' | 'models' | 'api' | 'news' | 'quiz'
  title        text        NOT NULL,
  content      text        NOT NULL,
  published_at date,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, category)
);
```

`UNIQUE (provider, category)` 制約で重複なしの UPSERT が可能:

```sql
INSERT INTO ai_university_content (provider, category, title, content)
VALUES ('lmsys', 'overview', 'LMSYS / Chatbot Arena', '## What is LMSYS?...')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      updated_at = now();
```

---

## Flutter: 動的 TabController

```dart
class _GeminiUniversityV2PageState extends State<GeminiUniversityV2Page>
    with TickerProviderStateMixin {

  late TabController _tabController;
  List<String> _providers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final data = await Supabase.instance.client
        .from('ai_university_content')
        .select('provider')
        .eq('category', 'overview')
        .order('provider');

    final providers = (data as List)
        .map((e) => (e as Map<String, dynamic>)['provider'] as String)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _providers = providers;
      _tabController.dispose();  // ← 必須
      _tabController = TabController(length: providers.length, vsync: this);
    });
  }
}
```

ポイント: 新しい `TabController` を作る前に `dispose()` を呼ぶこと。省略すると `TickerProvider` リークが発生する。

---

## Flutter: _providerMeta (表示設定・任意)

```dart
final Map<String, _ProviderMeta> _providerMeta = {
  'openai': _ProviderMeta(name: 'OpenAI', emoji: '🤖', color: Color(0xFF10A37F), officialUrl: 'https://openai.com/'),
  'lmsys':  _ProviderMeta(name: 'LMSYS / Chatbot Arena', emoji: '🏆', color: Color(0xFF1E40AF), officialUrl: 'https://lmsys.org/'),
  // ... 60社以上
};

// マップにないプロバイダーのフォールバック
_ProviderMeta _getMeta(String provider) {
  return _providerMeta[provider] ?? _ProviderMeta(
    name: provider.replaceAll('_', ' ').toUpperCase(),
    emoji: '🤖',
    color: Colors.grey.shade600,
    officialUrl: 'https://google.com/search?q=$provider+AI',
  );
}
```

新プロバイダーは `_providerMeta` を更新するまでグレーのロボット絵文字で表示される。タブはすぐに使える状態で現れる。

---

## コンテンツのオンデマンド読み込み

```dart
final Map<String, String> _contentCache = {};

Future<String> _loadContent(String provider, String category) async {
  final cached = _contentCache['$provider:$category'];
  if (cached != null) return cached;

  final data = await Supabase.instance.client
      .from('ai_university_content')
      .select('content')
      .eq('provider', provider)
      .eq('category', category)
      .maybeSingle();

  final content = (data?['content'] as String?) ?? _getFallback(provider);
  _contentCache['$provider:$category'] = content;
  return content;
}
```

`maybeSingle()` は行がない場合に例外ではなく `null` を返す — あるカテゴリが存在しない場合の 406 エラーを防ぐ。

---

## 新プロバイダー追加の完全手順

```bash
# 1. migration ファイルを作成
cat > supabase/migrations/YYYYMMDDXXXXXX_seed_newco_ai_university.sql << 'EOF'
INSERT INTO ai_university_content (provider, category, title, content)
VALUES
  ('newco', 'overview', 'NewCo AI', '## NewCo AI\n\n...'),
  ('newco', 'models',   'NewCo Models', '## モデル\n\n...'),
  ('newco', 'api',      'NewCo API', '## API\n\n...')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content, updated_at = now();
EOF

# 2. 適用 (本番)
git add supabase/migrations/ && git push origin main
# → deploy-prod.yml が supabase db push を自動実行
```

`TabController.length` の変更なし。ウィジェットリストの更新なし。次回 DB フェッチ後にタブが現れる。

---

## まとめ

| パターン | メリット |
|---------|---------|
| DB駆動タブリスト | 新プロバイダー = DB INSERT のみ |
| `_providerMeta` オプション | クラッシュなし・グレースフルデグラデーション |
| 新規前に `dispose()` | TickerProvider リーク防止 |
| `maybeSingle()` | カテゴリ未存在時の 406 エラーなし |
| インメモリコンテンツキャッシュ | 追加依存なし・セッション中有効 |

66社。`TabController.length` のハードコーディングなし。

自分株式会社: [https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)

#buildinpublic #FlutterWeb #Supabase #個人開発 #Dart
