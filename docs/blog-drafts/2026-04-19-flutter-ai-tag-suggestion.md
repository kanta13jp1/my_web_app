---
title: "FlutterノートアプリにAIタグ提案機能を実装 — Groq無料枠でリアルタイムタグ生成"
tags: Flutter,Supabase,Groq,AI,個人開発,buildinpublic
published: true
---

# FlutterノートアプリにAIタグ提案機能を実装

## なぜAIタグ提案か

ノートアプリで一番面倒な作業が「タグ付け」。書いた後に振り返って適切なタグを考えるのは認知コストが高い。AIに任せることで「書く」だけに集中できる。

## アーキテクチャ選択

Supabase Edge Functionを新規作成するのではなく、**既存の `ai-hub` EFのprovider.chatアクションを再利用**した。

```
Flutter → AIService.suggestTags() → ai-hub:provider.chat (Groq llama-3.3-70b) → TagSuggestion
```

Groq の llama-3.3-70b は **無料枠あり・超高速** (100ms以下で返答) なため、タグ提案のような軽量タスクに最適。

## Flutter実装

### AIServiceにsuggestTagsメソッドを追加

```dart
class AIService {
  Future<TagSuggestion> suggestTags({
    required String content,
    String? title,
  }) async {
    final prompt = '''
以下のノートテキストに適切なタグを5〜10個提案してください。
タイトル: ${title ?? '(なし)'}
本文: $content

JSON形式で返答:
{
  "tags": ["タグ1", "タグ2", ...],
  "category": "カテゴリ名",
  "reason": "提案理由"
}
''';

    final response = await _callAiHub(
      action: 'provider.chat',
      provider: 'groq',
      model: 'llama-3.3-70b-versatile',
      prompt: prompt,
    );
    return TagSuggestion.fromJson(json.decode(response['content']));
  }
}
```

### TagSuggestionモデル

```dart
class TagSuggestion {
  final List<String> tags;
  final String category;
  final String reason;

  const TagSuggestion({
    required this.tags,
    required this.category,
    required this.reason,
  });

  factory TagSuggestion.fromJson(Map<String, dynamic> json) => TagSuggestion(
    tags: List<String>.from(json['tags'] ?? []),
    category: json['category'] ?? '',
    reason: json['reason'] ?? '',
  );
}
```

### UIページ (AiSuggestTagsPage)

```dart
class AiSuggestTagsPage extends StatefulWidget {
  const AiSuggestTagsPage({super.key});
  // ...
}

class _AiSuggestTagsPageState extends State<AiSuggestTagsPage> {
  final _aiService = AIService();
  TagSuggestion? _suggestion;
  bool _isLoading = false;

  Future<void> _suggestTags() async {
    setState(() => _isLoading = true);
    try {
      final result = await _aiService.suggestTags(
        content: _controller.text.trim(),
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      );
      setState(() => _suggestion = result);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIタグ提案')),
      body: Column(
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'タイトル')),
          TextField(controller: _controller, decoration: const InputDecoration(labelText: 'ノート本文'), maxLines: 5),
          if (_isLoading) const CircularProgressIndicator(),
          if (_suggestion != null) _buildTagChips(_suggestion!.tags),
          ElevatedButton(onPressed: _suggestTags, child: const Text('タグを提案')),
        ],
      ),
    );
  }

  Widget _buildTagChips(List<String> tags) {
    return Wrap(
      spacing: 8,
      children: tags.map((tag) => Chip(
        label: Text('#$tag'),
        onDeleted: () {/* タグを選択/解除 */},
      )).toList(),
    );
  }
}
```

## 詰まったポイント

### ai-suggest-tags EF が削除されていた

以前は `ai-suggest-tags` という専用EFがあったが、実体はSVGクォートジェネレーターだった (名前と機能がミスマッチ)。EF 50本ハードキャップのクリーンアップ時に削除済み。

**解決**: `ai-hub:provider.chat` アクションを直接呼ぶことで、新規EF不要・既存インフラ再利用。

### JSON解析エラー

Groq のレスポンスにはたまりコードブロック (```json ... ```) が含まれる。

```dart
// コードブロック除去
String cleanJson(String raw) {
  return raw
    .replaceAll(RegExp(r'```json\s*'), '')
    .replaceAll(RegExp(r'```\s*'), '')
    .trim();
}
```

## まとめ

| 項目 | 内容 |
|------|------|
| 実装コスト | AIService に1メソッド追加のみ |
| 新規EF | 不要 (ai-hub再利用) |
| レスポンス速度 | ~100ms (Groq) |
| コスト | 無料枠内 |

EF 50本ハードキャップを守りながらAI機能を追加できるのがhubパターンの強み。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #Groq #AI #buildinpublic #個人開発
