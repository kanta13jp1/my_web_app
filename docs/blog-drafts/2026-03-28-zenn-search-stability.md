---
title: FlutterアプリのノートAI検索をOpenAIなしでも動くように安定化した話
emoji: 🔍
type: tech
topics: [flutter, supabase, deno, ai, search]
published: false
---

## はじめに

自分株式会社（Notion・Evernote・MoneyForward・Slack を1つに統合するAIライフマネジメントアプリ）の開発を続けています。

今日は「**AI 検索の安定化**」を実装しました。

元々 OpenAI API を使ったセマンティック検索機能はあったのですが、OpenAI キーが設定されていない環境や API 障害時には検索が完全に使えない状態でした。
これを「常に動く全文検索」にしながら「可能なら AI ランキングも使う」というハイブリッド構成に改善しました。

## 課題：AI 検索が脆すぎた

元の `ai-search` Edge Function は以下の問題を抱えていました：

```typescript
// 問題のある元実装
const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
if (!openaiApiKey) {
  throw new Error('OpenAI API key not configured') // ← キーがなければ即エラー
}
```

OpenAI が使えない状況が1つでも発生すると、ユーザーは完全に検索できなくなります。

## 解決策：テキスト検索フォールバック + モード制御

改善後の構成はこうなりました：

```
リクエスト (mode: 'auto')
  ↓
OpenAI 設定済み？
  Yes → AI ランキング検索
    → 失敗時 → ILIKE テキスト検索にフォールバック
  No  → ILIKE テキスト検索
```

### PostgreSQL ILIKE ベースの全文検索

まず日本語でも確実に動く検索を実装します。
PostgreSQL の `ILIKE` はバイト列で部分一致するので日本語でも問題なく使えます：

```typescript
async function textSearch(
  supabase: any,
  userId: string,
  query: string,
  limit: number,
): Promise<Note[]> {
  const keywords = query.trim().split(/\s+/).filter((k) => k.length > 0);
  if (keywords.length === 0) return [];

  // スペース区切りの全キーワードを OR 検索
  const orConditions = keywords
    .map((k) => `title.ilike.%${k}%,content.ilike.%${k}%`)
    .join(",");

  const { data, error } = await supabase
    .from("notes")
    .select("id, title, content, tags, category_id, created_at, updated_at")
    .eq("user_id", userId)
    .is("deleted_at", null)
    .or(orConditions)
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data as Note[]) ?? [];
}
```

### AI フォールバック付きメイン処理

```typescript
if (useAi) {
  try {
    const { rankedNotes, explanation, tokens } = await aiRank(
      openaiApiKey!, query, allNotes, limit,
    );
    results = rankedNotes;
    searchMode = "ai";
  } catch (aiError) {
    // AI 失敗 → テキスト検索にフォールバック
    console.warn("AI search failed, falling back:", aiError);
    results = await textSearch(supabaseClient, user.id, query, limit);
    searchMode = "text_fallback";
  }
} else {
  // OpenAI 未設定: 最初からテキスト検索
  results = await textSearch(supabaseClient, user.id, query, limit);
  searchMode = "text";
}
```

レスポンスに `searchMode` フィールドを追加することで、フロントエンドがどのモードで検索したかを表示できます。

## Flutter 側の対応

`AiSearchPage` を更新して、検索モードを UI に表示するようにしました：

```dart
// 検索モードバッジ表示
if (_searchMode.isNotEmpty)
  Row(
    children: [
      Icon(
        _searchMode == 'ai' ? Icons.auto_awesome : Icons.text_fields,
        size: 13,
        color: _searchMode == 'ai' ? Color(0xFF6366F1) : Colors.grey[500],
      ),
      Text(
        _searchMode == 'ai' ? 'AI 検索' :
        _searchMode == 'text_fallback' ? 'テキスト検索（AIフォールバック）' :
        'テキスト検索',
        style: TextStyle(fontSize: 11),
      ),
    ],
  ),
```

## ホーム画面に検索カードを追加

毎回「AIノート検索」メニューまで辿らなくても済むよう、ホーム画面に `NoteSearchCard` を追加しました：

```dart
class NoteSearchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiSearchPage()),
        ),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.manage_search, color: Color(0xFF6366F1)),
              Text('ノートを検索'),
              Text('キーワード・自然言語で全ノートを横断検索'),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 設計の考え方

| 優先度 | 何を守るか |
|---|---|
| 1 | **常に動く** (テキスト検索は常に使える) |
| 2 | **AI で価値を加える** (設定済みなら AI ランキング) |
| 3 | **透明性** (どのモードで動いたか UI に表示) |

これは Notion の全文検索に近いシンプルさを提供しながら、将来的に pgvector や Claude API によるセマンティック検索への拡張余地も残しています。

## まとめ

- OpenAI 必須 → テキスト検索フォールバック付きハイブリッド構成に変更
- `mode: 'auto'` でクライアントは何も考えなくていい設計
- ホーム画面検索カードで UX を改善
- deno lint 0 件、flutter analyze 0 件を維持

次は pgvector の `notes_embedding` カラム追加による本格的なベクトル検索を検討中です。

サービス: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic
