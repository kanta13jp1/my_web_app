---
title: "Claude + Groq で学習プロファイルを自動構築した — AI大学 Memory Agent"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# Claude + Groq で学習プロファイルを自動構築した — AI大学 Memory Agent

## はじめに

自分株式会社 AI大学に **Memory Agent** を実装しました。学習セッション後に Claude Sonnet が「弱点プロバイダー・得意プロバイダー・学習スタイル」を自動抽出し、次回セッションで個人最適化されたクイズを出題します。

さらに **Hybrid LLM** パターンで、クイズ採点は Groq (Llama 3.3 70B、無料高速) を使い、分析は Claude にまかせることでコストと速度を両立しています。

## アーキテクチャ

```
学習セッション終了
  → learner.update_profile (EF)
    → Claude Sonnet: セッションデータ → 構造化プロファイル JSON
      → ai_university_learner_profiles (Supabase) に UPSERT

クイズ回答
  → quiz.evaluate (EF)
    → Groq Llama 3.3 70B: 自由記述採点 (JSON mode)
    → fallback: 文字列完全一致
```

## Memory Agent: Claude で学習プロファイル抽出

```typescript
// supabase/functions/ai-hub — learner.update_profile
const prompt = `学習セッションのデータから構造化プロファイルを抽出してください。
セッションサマリー: ${sessionSummary}
スコアデータ: ${JSON.stringify(scores).slice(0, 2000)}
弱点プロバイダー・得意プロバイダー・学習スタイルをJSONで返してください。
形式: {"weak_providers":["..."],"strong_providers":["..."],"preferred_style":"visual|text|voice","insights":"..."}`;

const claudeResp = await fetch("https://api.anthropic.com/v1/messages", {
  method: "POST",
  headers: { "x-api-key": claudeKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
  body: JSON.stringify({
    model: "claude-sonnet-4-6",
    max_tokens: 512,
    messages: [{ role: "user", content: prompt }],
  }),
});

// JSON を安全にパース (コードブロック除去)
const rawText = claudeData.content[0].text;
const profileJson = JSON.parse(rawText.replace(/```json\n?|\n?```/g, "").trim());
```

Claude の出力をそのまま Supabase に保存:

```typescript
await admin.from("ai_university_learner_profiles").upsert({
  user_id,
  weak_providers:   profileJson.weak_providers  ?? [],
  strong_providers: profileJson.strong_providers ?? [],
  preferred_style:  profileJson.preferred_style  ?? "text",
  profile_json:     profileJson,
  total_sessions:   (existing?.total_sessions ?? 0) + 1,
}, { onConflict: "user_id" });
```

## Hybrid LLM: Groq でリアルタイム採点

クイズ採点は Claude より Groq (Llama 3.3 70B) の方が安くて速い。

```typescript
// quiz.evaluate — Groq Llama で自由記述採点
const groqResp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
  method: "POST",
  headers: { "Authorization": `Bearer ${groqKey}`, "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "llama-3.3-70b-versatile",
    max_tokens: 100,
    temperature: 0,
    response_format: { type: "json_object" }, // JSON mode
    messages: [{
      role: "user",
      content: `問題: ${question}\n模範回答: ${correctAnswer}\nユーザー回答: ${userAnswer}
評価: {"result":"correct|incorrect|partial","confidence":0-100}`,
    }],
  }),
}).catch(() => null);

// Groq が失敗したら文字列一致で fallback
if (!groqResp || !groqResp.ok) {
  const isCorrect = userAnswer.trim().toLowerCase() === correctAnswer.trim().toLowerCase();
  return json({ result: isCorrect ? "correct" : "incorrect", confidence: 100, fallback: true });
}
```

| 役割 | モデル | 理由 |
|------|--------|------|
| 学習プロファイル抽出 | Claude Sonnet 4.6 | 複雑な分析・JSON抽出の精度 |
| クイズ採点 | Groq Llama 3.3 70B | 速度優先・大量リクエスト・無料枠あり |

## DB スキーマ

```sql
CREATE TABLE ai_university_learner_profiles (
  user_id         uuid PRIMARY KEY REFERENCES auth.users,
  weak_providers  text[] DEFAULT '{}',
  strong_providers text[] DEFAULT '{}',
  preferred_style text DEFAULT 'text',
  profile_json    jsonb DEFAULT '{}',
  total_sessions  int  DEFAULT 0,
  updated_at      timestamptz DEFAULT now()
);
```

## まとめ

1. **Claude は「分析」専任** — セッション全体を俯瞰した深い抽出に向いている
2. **Groq は「採点」専任** — レイテンシ重視の大量リアルタイム処理に向いている
3. **`response_format: { type: "json_object" }`** — Groq の JSON mode でパースエラーを防ぐ
4. **fallback必須** — Groq 障害時は文字列一致で無停止継続

モデルを「得意なことに特化」させることでコストと品質を両立できます。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #LLM
