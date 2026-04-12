---
title: "Flutter×Supabaseで「AI大学」を34社対応に拡張した話 — 毎日自動更新するAI学習プラットフォーム"
tags: Flutter,Supabase,AI,buildinpublic,個人開発
published: false
---

# Flutter×Supabaseで「AI大学」を34社対応に拡張した話 — 毎日自動更新するAI学習プラットフォーム

## はじめに

個人開発アプリ「自分株式会社」の中で最も差別化が進んでいる機能が **AI大学** です。

Google、OpenAI、Anthropic、Meta、DeepSeekなど、乱立するAIプロバイダーを横断的に学習できるプラットフォームを Flutter Web + Supabase で構築し、**34社対応**まで拡張しました。

この記事では:
1. AI大学の基本設計とDB構造
2. 34社のコンテンツを **GitHub Actions で2時間ごと自動更新** する仕組み
3. スコア・ストリーク・バッジの実装
4. SNSシェアカード生成 (Flutter Web → PNG → base64)

を紹介します。

---

## AI大学の概要

ユーザーが各AIプロバイダーの概要・モデル一覧・API情報・最新ニュースを学習し、クイズに答えることで「AI偏差値」を競う機能です。

```
┌─────────────────────────────────────────────────┐
│ AI大学                                           │
│                                                  │
│  [Google] [OpenAI] [Anthropic] [Meta] [xAI] ... │
│   34社タブで切り替え                              │
│                                                  │
│  📖 概要 | 🤖 モデル | 🔌 API | 📰 最新ニュース  │
│                                                  │
│  [クイズに挑戦] ✓ 3/5問正解                      │
│  🔥 連続学習 7日目                               │
└─────────────────────────────────────────────────┘
```

---

## DBスキーマ

```sql
-- コンテンツテーブル
CREATE TABLE ai_university_content (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider text NOT NULL,          -- 'google', 'openai', ...
  category text NOT NULL,          -- 'overview', 'models', 'api', 'news'
  title text NOT NULL,
  content text NOT NULL,           -- Markdown形式
  published_at date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(provider, category)       -- UPSERT用
);

-- スコアテーブル
CREATE TABLE ai_university_scores (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  provider text NOT NULL,
  quiz_id text NOT NULL,
  correct boolean NOT NULL,
  studied_at timestamptz DEFAULT now(),
  UNIQUE(user_id, provider, quiz_id)
);

-- ストリークテーブル
CREATE TABLE ai_university_streaks (
  user_id uuid REFERENCES auth.users PRIMARY KEY,
  current_streak int DEFAULT 0,
  max_streak int DEFAULT 0,
  last_studied_date date
);
```

RLS で `user_id = auth.uid()` を設定し、自分のスコアのみ読み書き可能。

---

## 34社のプロバイダー一覧

```
メガプレイヤー (9社):
  google, openai, anthropic, microsoft, meta,
  x (xAI/Grok), deepseek, mistral, perplexity

特化型AI (11社):
  groq, cohere, amazon, oracle, reka,
  aleph_alpha, together_ai, fireworks_ai, replicate,
  writer, ai21

AIインフラ層 (5社):
  voyage, elevenlabs, openrouter, ollama, ideogram

マルチモーダル (5社):
  runway, suno, udio, luma, kling

その他 (4社):
  pika, stability, huggingface, ...
```

各プロバイダーには `overview` / `models` / `api` / `news` の4カテゴリのコンテンツがあります。

---

## コンテンツ自動更新: 2層アーキテクチャ

コンテンツ更新は2つの仕組みが並行して動いています:

### 層1: GitHub Actions (2時間ごと・RSS駆動)

```yaml
# ai-university-update.yml
on:
  schedule:
    - cron: '0 */2 * * *'

steps:
  - name: Update news content
    run: |
      # 各プロバイダーの公式ブログRSSを取得
      # schedule-hub EF の upsert_news action で更新
      curl -X POST \
        "https://{project}.supabase.co/functions/v1/schedule-hub" \
        -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
        -d '{"action":"ai_university.upsert_news","provider":"google","content":"..."}'
```

### 層2: Claude Code Schedule (4時間ごと・NotebookLM Deep Research)

```bash
# NotebookLM に最新AIニュースを調査させて高品質コンテンツを生成
notebooklm use jibun-master-brain
notebooklm source add-research "Google Gemini OpenAI GPT Anthropic Claude latest 2026"
notebooklm research wait
notebooklm ask "各AIプロバイダーの最新情報をまとめて"
```

GitHub Actions の RSS 更新より深い情報を Claude Schedule が上書きするため、
後から書いた方が最新版になります。

---

## Flutter側の実装: DB駆動タブ

```dart
// gemini_university_v2_page.dart
class _GeminiUniversityV2PageState extends State<GeminiUniversityV2Page>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final response = await Supabase.instance.client
        .from('ai_university_content')
        .select('provider')
        .eq('category', 'overview');
    
    final providers = (response as List)
        .map((e) => e['provider'] as String)
        .toSet()
        .toList()
      ..sort();
    
    setState(() {
      _providers = providers;
      _tabController = TabController(length: providers.length, vsync: this);
    });
  }
}
```

`_providers` は DB から動的に取得するため、新プロバイダーを migration で追加するだけでタブが自動追加されます。

---

## スコア書き込み (RLS直接UPSERT)

```dart
// クイズ回答時
await Supabase.instance.client
    .from('ai_university_scores')
    .upsert({
      'user_id': userId,
      'provider': provider,
      'quiz_id': quizId,
      'correct': isCorrect,
      'studied_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,provider,quiz_id');
```

RLS ポリシー:
```sql
-- INSERT: 自分のスコアのみ
CREATE POLICY "Users can insert own scores"
ON ai_university_scores FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

---

## SNSシェアカード生成 (Flutter Web)

学習完了時に「何社学習済み」をビジュアル化してシェアできます:

```dart
// RenderRepaintBoundary → PNG → base64 → HTMLAnchorElement
Future<void> _shareProgress() async {
  final boundary = _shareCardKey.currentContext!
      .findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  
  // Web: base64エンコードしてダウンロードリンクを生成
  final base64 = base64Encode(byteData!.buffer.asUint8List());
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:image/png;base64,$base64'
    ..download = 'ai-university-progress.png'
    ..click();
}
```

---

## 連続学習ストリーク (Supabase RPC)

```sql
-- update_streak RPC
CREATE OR REPLACE FUNCTION update_ai_university_streak(p_user_id uuid)
RETURNS TABLE(current_streak int, max_streak int) AS $$
DECLARE
  v_last_date date;
  v_current int;
  v_max int;
BEGIN
  SELECT last_studied_date, current_streak, max_streak
  INTO v_last_date, v_current, v_max
  FROM ai_university_streaks WHERE user_id = p_user_id;
  
  IF v_last_date = CURRENT_DATE - 1 THEN
    v_current := v_current + 1;  -- 連続
  ELSIF v_last_date = CURRENT_DATE THEN
    NULL;  -- 今日すでに学習済み
  ELSE
    v_current := 1;  -- リセット
  END IF;
  
  v_max := GREATEST(v_max, v_current);
  
  UPDATE ai_university_streaks
  SET current_streak = v_current, max_streak = v_max,
      last_studied_date = CURRENT_DATE
  WHERE user_id = p_user_id;
  
  RETURN QUERY SELECT v_current, v_max;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## まとめ

| 項目 | 内容 |
|------|------|
| 対応プロバイダー | 34社 |
| コンテンツ更新 | 2時間ごと (GitHub Actions) + 4時間ごと (Claude Schedule) |
| スコア管理 | Supabase `ai_university_scores` (RLS直接UPSERT) |
| ストリーク | Supabase RPC `update_ai_university_streak` |
| バッジ | `ai_university_badges` テーブル (EF自動発行) |
| シェア | Flutter Web → PNG → base64 (package:web) |

AIプロバイダーの乱立は個人開発者にとってノイズですが、「全部学べる1アプリ」として整理すると差別化になりました。

フィードバックお待ちしています。

---

URL: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #AI #buildinpublic #個人開発
