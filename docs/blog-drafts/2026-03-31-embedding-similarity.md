---
title: "Gemini Embeddings × Flutter Web で「Embedding Lab」テキスト類似度ツールを実装した話"
tags: Flutter,Supabase,個人開発,buildinpublic,GeminiAPI
published: true
---

# ブログ下書き 2026-03-31 — 2026-03-31-embedding-similarity

## タイトル案

1. Flutter WebでGemini Embeddingsを使ったテキスト類似度比較ツールを作った話
2. Gemini-embedding-001でコサイン類似度を可視化——自分株式会社のEmbedding Labを実装した
3. テキスト埋め込みを体験できる「Embedding Lab」をFlutterで実装した理由と方法

## 投稿先候補

- [x] Zenn
- [ ] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] dev.to (英語版)

## 本文下書き (約2000字)

### はじめに

「このノートとあのノートって、内容が似てるかな？」

そんな疑問に答えるため、自分株式会社アプリに **Embedding Lab** というページを追加しました。

Gemini の `gemini-embedding-001` モデルを使ってテキストをベクトル化し、**コサイン類似度** をリアルタイムで計算・可視化する開発者向けツールです。

### 実装内容

#### 機能

1. **テキスト埋め込みモード**: 任意のテキストを768次元ベクトルに変換し、先頭10次元を確認できる
2. **類似度比較モード**: 2つのテキストのコサイン類似度を -1.0〜1.0 のスコアで表示し、「非常に似ている / 関連あり / 異なるトピック」などのラベルでわかりやすく提示

#### コサイン類似度の計算ロジック

コサイン類似度は次の式で計算します:

```
similarity = (A · B) / (||A|| × ||B||)
```

Dart での実装:

```dart
double _cosineSimilarity(List<double> a, List<double> b) {
  double dot = 0, normA = 0, normB = 0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  return denom == 0 ? 0.0 : dot / denom;
}
```

#### Gemini Embedding API の呼び出し

`gemini-embedding-001` は `embedContent` エンドポイントを使います:

```dart
Future<List<double>> _fetchEmbedding(String text) async {
  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent',
  );
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: jsonEncode({
      'content': {
        'parts': [{'text': text}],
      },
    }),
  );
  final data = jsonDecode(response.body);
  return (data['embedding']['values'] as List)
      .map((v) => (v as num).toDouble())
      .toList();
}
```

2つのテキストを並列フェッチする場合は `Future.wait` を活用:

```dart
final results = await Future.wait([
  _fetchEmbedding(textA),
  _fetchEmbedding(textB),
]);
final score = _cosineSimilarity(results[0], results[1]);
```

#### UI の工夫

類似度スコアを `LinearProgressIndicator` で可視化し、スコアに応じて色が変わるようにしています:

- **0.85以上**: 緑 (高い類似度)
- **0.70〜0.85**: ライトグリーン (関連あり)
- **0.50〜0.70**: オレンジ (やや関連)
- **0.50未満**: 赤 (異なるトピック)

### なぜ作ったか

自分株式会社アプリには**ノートのセマンティック検索**機能を今後実装予定です。埋め込みベクトルを使えば「キーワードに完全一致しなくても意味が近いノートを発見できる」というUXが実現できます。

Embedding Lab はその実験台として、ユーザーが「こんな2つのテキストはどのくらい似ているか？」を体感できるツールとして提供しています。

### flutter analyze 0件の維持

コード追加後も `flutter analyze` の 0件を維持しました。今回のポイントは:

- `require_trailing_commas`: ウィジェットのすべての引数にトレーリングカンマを付ける
- `dart:math` の `sqrt` を使うため `import 'dart:math'` を追加

### 今後の展開

1. **ノートのベクトルをSupabaseに保存**: `pgvector` 拡張を使ってノートごとのembeddingを保存
2. **類似ノート検索**: 現在のノートに近い内容のノートをホーム画面に表示
3. **自動タグ生成の高精度化**: embeddingを使ったクラスタリングでカテゴリを自動推定

### まとめ

Gemini の埋め込みAPIは使いやすく、Dartから直接呼び出せます。今回のEmbedding Labは「AI機能の実験場」として、今後のセマンティック機能開発のベースになります。

実際に試してみたい方はこちらから:
https://my-web-app-b67f4.web.app/

#FlutterWeb #GeminiAPI #Embeddings #buildinpublic #Supabase
