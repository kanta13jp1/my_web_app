---
title: "1つのEdge Functionで議事録・Xスレッド・技術ブログ原稿を同時生成する実装解説"
tags: Flutter,Supabase,個人開発,buildinpublic,GeminiAPI
published: true
---

# ブログ下書き 2026-04-07 (AI文章アシスタント拡張)

## タイトル案

1. 「1つのEdge Functionで議事録・Xスレッド・技術ブログ原稿を同時生成 — Flutter+Supabase実装例」
2. 「Gemini APIで会議メモを構造化議事録に変換する — 既存Edge Functionへのアクション追加パターン」
3. 「#buildinpublic をシステム化する — ノート→Xスレッド自動変換機能をFlutter Webに実装した話」

## 投稿先候補

- [x] Zenn（技術実装詳細）
- [x] Qiita（実用向け手順）
- [ ] note（エッセイ）
- [ ] X Article

## 本文下書き (約2000字)

### はじめに

「議事録を書くのが面倒」「技術ブログを書きたいけど構成を考えるのが辛い」「XでのBuild in Public投稿を毎日続けたい」— この3つの課題を1つのEdge Functionで解決する機能を実装しました。

自分株式会社（Notion・Evernote・Slack・ChatworkなどSaaS21社の機能を統合したAIプラットフォーム）では、AI文章アシスタント機能として既に「文章改善・要約・翻訳・トーン変換」などを提供していました。今回はそこに3つの新アクションを追加しました。

### 実装内容

#### 1. 既存Edge Functionへのアクション追加（Deno/TypeScript）

Supabase Edge Functionのquotaが94/94に近づいている中、新しいFunction追加ではなく**既存Functionへのswitch-caseアクション追加**で機能を拡張しました。

```typescript
// supabase/functions/ai-writing-assistant/index.ts
case "minutes":
  prompt = `以下のメモ・会話内容を整理して、ビジネス会議の議事録フォーマットに変換してください。

【出力フォーマット】
## 議事録

**日時**: [記載があれば抽出、なければ「未記載」]
**参加者**: [記載があれば抽出]

### 議事内容
（箇条書きで整理）

### 決定事項
（明確に決まったことを箇条書き）

### アクションアイテム
| 担当者 | タスク | 期限 |
|--------|--------|------|

### 次回予定
[記載があれば抽出]

---
入力テキスト:
${text}`;
  break;

case "thread":
  prompt = `以下の内容をX (Twitter) のスレッド形式に変換してください。

【ルール】
- 各ツイートは140字以内
- スレッドは5〜8ツイートで構成
- 1ツイート目は注目を集めるフックで始める
- 各ツイートの冒頭に番号 (1/ 2/ ...) を付ける
- 最後のツイートに #buildinpublic #自分株式会社 のハッシュタグを付ける

入力テキスト:
${text}`;
  break;
```

ポイントは**プロンプトで出力フォーマットを明示**することです。「議事録らしい出力」を得るには、Markdownのテーブル形式や見出し構造をプロンプトに直接書いてGeminiに示すのが効果的でした。

#### 2. Flutter側 — 新アクションの追加とX投稿ボタン

```dart
static const _actions = {
  'improve': ('文章改善', Icons.auto_fix_high, Color(0xFF6366F1)),
  // ... 既存アクション ...
  'minutes': ('議事録生成', Icons.assignment, Color(0xFF0EA5E9)),
  'thread': ('Xスレッド', Icons.dynamic_feed, Color(0xFF1DA1F2)),
  'blog': ('ブログ記事', Icons.article, Color(0xFFF97316)),
};
```

スレッド生成時は結果表示部分に「Xに投稿」ボタンを追加。`twitter.com/intent/tweet` URLスキームで1ツイート目を開くUIにしています。

```dart
if (_selectedAction == 'thread')
  IconButton(
    icon: const Icon(Icons.open_in_new, size: 18),
    tooltip: 'Xに投稿',
    color: const Color(0xFF1DA1F2),
    onPressed: () async {
      final encoded = Uri.encodeComponent(
        _resultController.text.length > 280
            ? '${_resultController.text.substring(0, 277)}...'
            : _resultController.text,
      );
      final uri = Uri.parse(
        'https://twitter.com/intent/tweet?text=$encoded',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    },
  ),
```

### つまずいたポイント

**Supabase quotaの制約**

最初は「議事録生成」専用のEdge Functionを作ることを検討しましたが、Supabase Free Planのデプロイ数上限（94）が限界に近いため、既存の `ai-writing-assistant` に統合しました。これにより quota 消費なしで3機能を追加できました。

**プロンプトエンジニアリング**

単純に「議事録を作って」と指示するだけでは出力が不安定でした。Markdownフォーマットとサンプル構造をプロンプトに含めることで、一貫した形式の出力を得られるようになりました。

### まとめ

今回の実装で「テキストを書く → AIが構造化 → SNSやドキュメントとして共有」というループを強化しました。特にXスレッド生成機能は、個人開発の#buildinpublicコンテンツ作成を大幅に効率化します。

Edge Functionのquota制約がある中でも、既存Functionへのアクション追加という設計パターンで機能を無制限に拡張できます。ぜひ参考にしてください。

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発 #Gemini
