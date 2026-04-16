# AI大学 v2 設計ドキュメント — SamiWISE アーキテクチャ統合

**作成日**: 2026-04-16
**担当インスタンス**: VSCode版
**参照**: NotebookLM notebook `c7e786bb-b4fb-466e-9382-efdb739b992f` (SamiWISE Voice AI GMAT Tutor)

---

## 概要

SamiWISE (Voice AI GMAT Tutor) のアーキテクチャパターンを自分株式会社の AI大学機能に統合する。
4つの機能を優先度順に実装し、AI大学をより学習効果の高いインタラクティブなプラットフォームへ進化させる。

### 実装優先度

| 優先度 | 機能 | 依存 | API キー |
|--------|------|------|----------|
| P1 | FSRS スペース反復法 | Supabase auth | 不要 |
| P2 | Memory Agent (構造化学習者プロファイル) | Supabase auth | 不要 |
| P3 | ハイブリッド LLM ルーティング | P1, P2 | GROQ_API_KEY |
| P4 | 音声学習 (TTS + STT) | P3 | DEEPGRAM_API_KEY + ELEVENLABS_API_KEY |

---

## Section 1: アーキテクチャ

```
┌─────────────────────────────────────────────┐
│           AI大学 v2 アーキテクチャ             │
├────────────────────────────────────────────┤
│ P1: FSRS           │ P2: Memory Agent       │
│ クイズスケジューラー │ 学習者プロファイル      │
│ (Supabase only)    │ (Supabase only)        │
├────────────────────────────────────────────┤
│ P3: ハイブリッド LLM │ P4: 音声学習           │
│ Groq (routing)     │ Deepgram STT           │
│ Claude (reasoning) │ ElevenLabs TTS         │
└────────────────────────────────────────────┘
         ↕ 全て ai-hub EF 経由
         ↕ Supabase auth (必須)
```

**データフロー**:
1. ユーザーがクイズ回答 → FSRS が次回出題日を計算 → Supabase 保存
2. Memory Agent が学習パターンを JSON 構造化 → プロファイル更新
3. クイズ評価は Groq (<200ms)、詳細解説は Claude Sonnet
4. 音声ボタンで TTS 再生 / マイクで STT 入力

---

## Section 2: データスキーマ

### 新規テーブル

```sql
-- P1: FSRS スペース反復カード
CREATE TABLE ai_university_fsrs_cards (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid REFERENCES auth.users NOT NULL,
  provider     text NOT NULL,
  question_id  text NOT NULL,
  due_date     timestamptz NOT NULL DEFAULT now(),
  stability    float NOT NULL DEFAULT 1.0,
  difficulty   float NOT NULL DEFAULT 0.3,
  state        text NOT NULL DEFAULT 'new', -- new/learning/review/relearning
  reps         int NOT NULL DEFAULT 0,
  lapses       int NOT NULL DEFAULT 0,
  last_review  timestamptz,
  UNIQUE(user_id, provider, question_id)
);

-- RLS
ALTER TABLE ai_university_fsrs_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_fsrs_cards" ON ai_university_fsrs_cards
  USING (user_id = auth.uid());

-- P2: 構造化学習者プロファイル
CREATE TABLE ai_university_learner_profiles (
  user_id          uuid REFERENCES auth.users PRIMARY KEY,
  weak_providers   text[],
  strong_providers text[],
  preferred_style  text,  -- 'visual' | 'text' | 'voice'
  total_sessions   int DEFAULT 0,
  profile_json     jsonb,
  updated_at       timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE ai_university_learner_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_profile" ON ai_university_learner_profiles
  USING (user_id = auth.uid());
```

### 既存テーブル拡張

```sql
-- P3/P4: ai_university_scores に追加
ALTER TABLE ai_university_scores
  ADD COLUMN IF NOT EXISTS voice_mode   bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS groq_routed  bool DEFAULT false;
```

---

## Section 3: EF アクション設計 (ai-hub 拡張)

既存の `supabase/functions/ai-hub/index.ts` に7つのアクションを追加する。新規EFは作成しない。

### P1: FSRS

| アクション | 処理 | 入力 | 出力 |
|---|---|---|---|
| `quiz.fsrs_next` | due_date 順で次回出題リスト取得 | `{ provider, limit }` | `{ cards: FsrsCard[] }` |
| `quiz.fsrs_grade` | 回答結果を記録・次回日を FSRS アルゴリズムで再計算 | `{ question_id, provider, grade }` (grade: 1=Again/2=Hard/3=Good/4=Easy) | `{ next_due: string, stability: number }` |

**FSRS アルゴリズム**: SM-2 ベースの簡易実装。`grade` に応じて `stability` と `due_date` を更新。
- grade=1 (Again): stability *= 0.5、1日後
- grade=2 (Hard): stability *= 0.8、stability日後
- grade=3 (Good): stability *= 1.0、stability日後
- grade=4 (Easy): stability *= 1.3、stability*1.3日後

### P2: Memory Agent

| アクション | 処理 | 入力 | 出力 |
|---|---|---|---|
| `learner.update_profile` | セッション後に Claude Sonnet でプロファイルを構造化・更新 | `{ session_summary, scores[] }` | `{ profile_json }` |

**Claude Sonnet プロンプト**:
```
学習セッションのデータから構造化プロファイルを抽出してください。
弱点プロバイダー・得意プロバイダー・学習スタイルをJSONで返してください。
```

### P3: ハイブリッド LLM

| アクション | モデル | 処理 |
|---|---|---|
| `quiz.evaluate` | Groq llama-3.3-70b | 回答の正誤判定 (<200ms) |
| `quiz.explain` | Claude Sonnet | 不正解時の詳細解説生成 |

**ルーティングロジック**:
```
回答受信
  → Groq: "correct / incorrect / partial" を判定
  → correct → FSRS grade=3 で記録のみ (Claude 不使用)
  → incorrect/partial → Claude: 解説生成 → FSRS grade=1/2 で記録
```

### P4: 音声

| アクション | API | 処理 |
|---|---|---|
| `voice.tts` | ElevenLabs | テキスト → 音声 URL (base64 or signed URL) |
| `voice.stt` | Deepgram | 音声データ (base64) → テキスト |

---

## Section 4: Flutter UI 設計

### 変更ファイル一覧

```
lib/
├── pages/
│   ├── gemini_university_v2_page.dart  ← クイズUI拡張 (FSRS + Hybrid LLM)
│   └── ai_university_voice_page.dart   ← 新規: 音声学習ページ
├── services/
│   ├── ai_fsrs_service.dart            ← 新規: FSRS クライアント
│   └── ai_learner_profile_service.dart ← 新規: Memory Agent クライアント
└── widgets/
    └── ai_university_home_card.dart    ← 音声モードボタン追加
```

### クイズUI拡張 (gemini_university_v2_page.dart)

```
[従来フロー] 問題表示 → テキスト回答 → ○/× 表示
[v2 フロー]  問題表示 → テキスト/音声回答
               → Groq で即時判定 (<200ms) [ローディング表示なし]
               → 正解: "次回: 3日後" FSRS バッジ表示
               → 不正解: Claude 解説カード + "次回: 明日" バッジ
```

### 音声学習ページ (ai_university_voice_page.dart)

```
┌─────────────────────────────┐
│  🎓 AI大学 音声学習モード     │
│  プロバイダー: [Google ▼]    │
├─────────────────────────────┤
│                             │
│   問題文 (TTS 再生中)        │
│   🔊 ──────────────         │
│                             │
│   ┌──────────────────┐     │
│   │  🎤 話して回答    │     │
│   └──────────────────┘     │
│                             │
│   [テキスト入力に切替]       │
└─────────────────────────────┘
```

### ホームカード拡張 (ai_university_home_card.dart)

既存カードのフッターに `🎤 音声で学ぶ` ボタンを追加。`AiUniversityVoicePage` へ遷移。

---

## エラーハンドリング

| シナリオ | 対応 |
|---|---|
| Groq タイムアウト (>500ms) | Claude にフォールバック |
| ElevenLabs API エラー | テキスト表示のみに切替 |
| Deepgram STT 失敗 | テキスト入力フォームを表示 |
| FSRS カード未登録 | new カードとして初期化 |

---

## テスト方針

- FSRS アルゴリズム: Dart unit test (`ai_fsrs_service_test.dart`)
- EF アクション: `*.test.ts` で Deno test
- 音声UI: Playwright で音声ボタン表示確認 (実際の音声再生はモック)

---

## 実装しないこと (YAGNI)

- Pinecone RAG パイプライン (SamiWISE 固有、AI大学には不要)
- Railway 長時間コンテナ (Supabase EF で十分)
- Paddle 課金 (自分株式会社は無料提供)
- llama-3.3-70b のファインチューニング
