---
title: "Flutter Webで13競合の比較SEOページを量産した話 — 自分株式会社 ビルド・イン・パブリック #4"
emoji: "🔍"
type: "idea"
topics: ["Flutter", "SEO", "Supabase", "個人開発", "マーケティング"]
published: true
---

# Flutter Webで13競合の比較SEOページを量産した話

「Notion代替」「Evernote代替」で検索してくるユーザーは、すでに移行意欲が高い最良のターゲットだ。

自分株式会社は「Notion・Evernote・MoneyForward・X・Animaworks・Claude Code・Codex・netkeiba・OpenClaw・Claude Cowork・Chatwork・Slack・ジョブカン」の13競合を超えることを目標に開発している個人プロダクトです。

今回は、この13競合に対応する比較SEOページをFlutter Webで量産した実装をまとめます。

## なぜ比較SEOページが重要なのか

「Notion 代替 無料」「Evernote 移行先」のような検索クエリは購買意欲（=登録意欲）が最も高いキーワードです。

検索者はすでに「今使っているツールに不満がある」状態であり、代替を探しています。このユーザーに刺さるランディングページを競合名ごとに用意するのが比較SEOページ戦略です。

## 実装方針

Flutter Webでは各URLに対してページを生成できます。今回は共通のウィジェット `ComparisonPage` を作り、`competitorKey` パラメータで切り替える設計にしました。

### ルート設計

```dart
// main.dart
case '/vs-notion':
case '/vs-evernote':
case '/vs-moneyforward':
case '/vs-slack':
case '/vs-chatwork':
case '/vs-x':
case '/vs-animaworks':
case '/vs-claude-code':
case '/vs-codex':
case '/vs-netkeiba':
case '/vs-openclaw':
case '/vs-claude-cowork':
case '/vs-jobcan':
  return MaterialPageRoute(
    builder: (_) => ComparisonPage(
      competitorKey: uri.path.replaceFirst('/vs-', ''),
    ),
  );
```

13競合すべてを1つの `switch` ブロックで処理するため、ルート追加のコストがほぼゼロです。

### ComparisonPage の構造

```dart
class ComparisonPage extends StatelessWidget {
  final String competitorKey;
  const ComparisonPage({super.key, required this.competitorKey});

  @override
  Widget build(BuildContext context) {
    final info = _competitorInfo[competitorKey.toLowerCase()] ?? _defaultInfo;
    return _ComparisonShell(info: info);
  }
}
```

各競合のデータは `_competitorInfo` マップで管理します。

```dart
final _competitorInfo = <String, _CompetitorInfo>{
  'notion': const _CompetitorInfo(
    name: 'Notion',
    emoji: '📝',
    tagline: 'Notion のすべての機能を、完全無料で。AIが自動整理まで。',
    searchKeyword: 'Notion代替',
    accentColor: Color(0xFF1F2937),
    painPoints: [
      'Notionの無料プランはページ数に制限がある',
      'AI機能（Notion AI）は月額追加料金が必要',
      'データベースの設定が複雑で学習コストが高い',
    ],
    features: [
      _FeatureComparison(feature: 'メモ・ノート作成', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'AI 自動整理', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '完全無料（制限なし）', competitorHas: false, weHave: true),
      // ...
    ],
  ),
  // 13競合分続く...
};
```

### ページ構成（_ComparisonShell）

各比較ページは4セクションで構成しています。

1. **ヒーロー** — 競合名・tagline・無料登録CTA
2. **ペインポイント** — 競合の痛点3つ
3. **機能比較表** — ✅/❌で直感的に比較
4. **CTA** — 「無料で始める（30秒）」ボタン

```dart
class _ComparisonShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHero(context),
            _buildPainPoints(),
            _buildFeatureTable(),
            _buildCta(context),
          ],
        ),
      ),
    );
  }
}
```

## sitemap.xml へのURL追加

比較ページはクロールされなければ意味がありません。sitemap.xml に全13競合のURLを追加しました。

```xml
<url>
  <loc>https://my-web-app-b67f4.web.app/vs-notion</loc>
  <lastmod>2026-03-26</lastmod>
  <changefreq>weekly</changefreq>
  <priority>0.9</priority>
</url>
<!-- /vs-evernote /vs-moneyforward ... /vs-jobcan まで13URL -->
```

合計21URLのsitemapになりました。

## ランディングページへの内部リンク

比較ページを作っても、ランディングページから内部リンクされていないと検索エンジンの評価が低くなります。LP に `_buildComparisonLinksSection()` を追加し、全13競合へのリンクをChipスタイルで表示しました。

```dart
Widget _buildComparisonLinksSection() {
  const competitors = [
    (key: 'notion', name: 'Notion', emoji: '📝', color: Color(0xFF1F2937)),
    // 13競合分...
  ];

  return Card(
    child: Wrap(
      children: competitors.map((c) => InkWell(
        onTap: () => Navigator.of(context).pushNamed('/vs-${c.key}'),
        child: Container(/* 競合名チップ */),
      )).toList(),
    ),
  );
}
```

## SEOメタタグの更新

`web/index.html` の `<meta name="keywords">` に13競合の代替キーワードをすべて追加しました。

```html
<meta name="keywords" content="
  自分株式会社,Notion代替,Evernote代替,MoneyForward代替,
  Slack代替,Chatwork代替,X代替,Twitter代替,
  Animaworks代替,Claude Code代替,Codex代替,
  netkeiba代替,OpenClaw代替,Claude Cowork代替,ジョブカン代替,
  AIライフマネジメント,タスク管理,資産管理,習慣化,メモアプリ
">
```

## flutter analyze 0件を維持

Flutter の比較ページ実装では、`const` コンストラクタのネストでトレーリングカンマが必要です。deno lint と合わせて CI でブロックしています。

```yaml
# .github/workflows/ci.yml
- name: Flutter analyze
  run: flutter analyze --fatal-infos --fatal-warnings
```

## 現在の成果

- 比較SEOページ: 13競合 × 1ページ = 13ページ
- sitemap.xml: 21 URL
- 登録ユーザー数: 21人（auth.admin.listUsersで正確に計測）

## 次のステップ

- 各比較ページへの個別OGP画像生成
- 競合キーワードでのGoogle Search Console インデックス登録確認
- 比較ページ経由の登録CVRトラッキング

---

ビルド・イン・パブリックで開発を公開しながら成長を続けています。フィードバック・スターお待ちしています！

https://my-web-app-b67f4.web.app/
