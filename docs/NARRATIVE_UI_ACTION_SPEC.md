# Narrative UI Action — 抽象 action enum 拡張 spec (#1366 / part 145)

> **status**: 設計 spec / Win版#132 part 145 / 2026-05-05
> **issue**: [#1366](https://github.com/kanta13jp1/my_web_app/issues/1366) [追加要望] ストーリー分岐・文脈移行に対応する汎用的UIアクションの追加
> **scope**: 設計のみ (Win Claude territory / UI design + AI tool schema) / 実装は Win Codex (= EF tool schema + Flutter handler) ハンドオフ
> **NotebookLM source**: `dd2b382d` The Ghost in the Schema: Emergent AI Semantic Abstraction
> **PHILOSOPHY-22 alignment**: #5 (商品=価値 — 表現力) + #6 (時間最適化 — UI hack 削減) / **AI-CHARACTER-24** #3 (人格表現) + #5 (会話自然性) / **IMBUE-25** #4 (mentor 感) + #7 (流れ感)

## 1. 思想

5 つの物理 tool (`invite` / `rename_space` / etc) で物語の分岐や文脈移行を表現すると
ボタン抽象化 hack が発生 = AI が UI に縛られる. **AI が "意味" を返し UI が "表現" する** 分離を
schema レベルで作る = AI-CHARACTER #3 (人格表現) と IMBUE #7 (流れ感) を schema gate.

## 2. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| AI tool schema (= EF 側 tool list) | 部分整備 (= 5 物理 action) | §3 で抽象 enum 追加 |
| Flutter tool dispatcher | 部分整備 (= [ai_service.dart](lib/services/ai_service.dart) 想定) | §4 で safe-handle map 追加 |
| 視覚 transition widget | 整備済 (= AnimatedSwitcher / Hero) | §4 で再利用 |
| chat 自動送信 | 整備済 (= chat_service.dart 想定) | §4 で narrative_choice 接続 |

## 3. Schema 拡張 (= Win Codex 担当)

### 3.1 抽象 action enum 追加 (= AI tool schema)

```typescript
// supabase/functions/_shared/tool_schema.ts (= 既存 想定 / 拡張)

export const TOOL_ACTIONS = [
  // 物理 (= 既存)
  'invite', 'rename_space', 'archive_space', 'pin_message', 'react_message',

  // 抽象 (= NEW / part 145 追加)
  'narrative_choice',     // 物語の分岐 / 代替案提示
  'scene_transition',     // シーン移行 (= 場面/章/視点切替)
  'ambient_setpiece',     // 環境演出 (= BGM / 背景 / 雰囲気変更)
  'recap_summary',        // ここまでの振り返り (= TL;DR 自動)
  'cliffhanger_hint',     // 続きを促す控えめな示唆
  'context_handoff',      // 別 chat / 別 mentor へ引継ぎ
] as const;

export type ToolAction = typeof TOOL_ACTIONS[number];

export const ABSTRACT_ACTIONS: ReadonlySet<ToolAction> = new Set([
  'narrative_choice', 'scene_transition', 'ambient_setpiece',
  'recap_summary', 'cliffhanger_hint', 'context_handoff',
]);
```

### 3.2 各抽象 action の payload schema

```typescript
// narrative_choice — 2-4 択 + reasoning
type NarrativeChoicePayload = {
  prompt: string;                    // "次の選択は？"
  options: Array<{
    label: string;                   // "A. 静観する"
    short_reason?: string;           // "短期 risk 低 / 長期 cost 不明"
  }>;                                // 2 ≤ length ≤ 4
  default_index?: number;            // タイムアウト時 fallback (任意)
  timeout_sec?: number;              // 自動進行 (= 任意 / 無指定 = 待機)
};

// scene_transition — 演出付き場面切替
type SceneTransitionPayload = {
  to_scene: string;                  // 'home' / 'reflection' / 'planning'
  visual: 'fade' | 'slide_left' | 'slide_right' | 'crossfade' | 'zoom';
  caption?: string;                  // "—— 翌朝 ——"
  duration_ms?: number;              // 既定 800ms / max 2000ms (cap 安全弁)
};

// ambient_setpiece — 環境演出
type AmbientSetpiecePayload = {
  mood: 'calm' | 'focus' | 'celebrate' | 'reflect' | 'urgent';
  bgm_url?: string;                  // optional / null = 無音
  background_token?: string;         // design token 名 (= colorScheme.surface 等)
};

// recap_summary — 振り返り
type RecapSummaryPayload = {
  span: 'session' | 'today' | 'week' | 'last_5_turns';
  bullets: string[];                 // 3-7 件
  next_hint?: string;                // 次行動の控え目示唆
};

// cliffhanger_hint — 続きの示唆
type CliffhangerHintPayload = {
  hook_text: string;                 // "...続きは明日"
  resume_at?: string;                // ISO datetime / 任意 / scheduled task 連動
};

// context_handoff — 別 chat / mentor へ
type ContextHandoffPayload = {
  to_mentor_id: string;              // 'cfo' / 'cto' / 'designer' / etc
  summary: string;                   // 引継ぎ要約 (= 200 字以内)
  resume_route?: string;             // '/cfo-office?topic=runway'
};

export type ToolPayload =
  | NarrativeChoicePayload | SceneTransitionPayload | AmbientSetpiecePayload
  | RecapSummaryPayload | CliffhangerHintPayload | ContextHandoffPayload;
```

## 4. Flutter handler 設計 (= Win Codex 実装)

### 4.1 dispatcher 拡張

```dart
// lib/services/ai_tool_dispatcher.dart (= 既存 想定 / 拡張)

class AiToolDispatcher {
  Future<DispatchResult> handle(ToolCall call) async {
    if (_physical.contains(call.action)) {
      return _handlePhysical(call);   // 既存
    }
    if (_abstract.contains(call.action)) {
      return _handleAbstract(call);   // NEW
    }
    return DispatchResult.unknown(call.action); // 安全 fallback
  }

  Future<DispatchResult> _handleAbstract(ToolCall call) async {
    switch (call.action) {
      case 'narrative_choice':
        return _showChoiceModal(call.payload as NarrativeChoicePayload);
      case 'scene_transition':
        return _runSceneTransition(call.payload as SceneTransitionPayload);
      case 'ambient_setpiece':
        return _applyAmbient(call.payload as AmbientSetpiecePayload);
      case 'recap_summary':
        return _renderRecapBubble(call.payload as RecapSummaryPayload);
      case 'cliffhanger_hint':
        return _renderCliffhanger(call.payload as CliffhangerHintPayload);
      case 'context_handoff':
        return _navigateToMentor(call.payload as ContextHandoffPayload);
    }
    return DispatchResult.unknown(call.action);
  }
}
```

### 4.2 safe-handle map (= 受入 #2)

| action | 想定 widget | 失敗時 fallback (= NEVER throw) |
|---|---|---|
| narrative_choice | `showModalBottomSheet` + ButtonGroup | chat に「選択肢: A / B / C」テキスト送信 |
| scene_transition | `AnimatedSwitcher` + caption Snackbar | 何もせず (= silent) |
| ambient_setpiece | `ThemeNotifier.setMood()` | 既定 mood に戻す |
| recap_summary | chat bubble 拡張 (= bullet list) | bullets を改行 join で plain text 化 |
| cliffhanger_hint | chat bubble + 控え目 italics | plain text 化 |
| context_handoff | `Navigator.pushNamed(resume_route)` | "/" home へ |

= `payload` 不正でも **必ず chat 自動送信または silent** で graceful degrade.

### 4.3 narrative_choice modal 詳細

```
┌─ NarrativeChoiceSheet (heightFactor 0.4) ─┐
│ {{prompt}}                  [×]            │
├──────────────────────────────────────────┤
│ ┌─ A. {{options[0].label}} ──────────┐   │
│ │ {{options[0].short_reason}}        │   │
│ └────────────────────────────────────┘   │
│ ┌─ B. {{options[1].label}} ──────────┐   │
│ │ {{options[1].short_reason}}        │   │
│ └────────────────────────────────────┘   │
│ ...                                       │
│ [もう一度提案を見る] [自由記述]            │
└──────────────────────────────────────────┘
```

選択時 → AI へ「user chose: A」を chat 自動送信 + sheet 閉じる + bubble に選択ログ残す.

### 4.4 安全弁 (= AI-DEV-23 #2 deny-by-default)

- `ABSTRACT_ACTIONS` enum 外 = 即 reject + chat に「unknown action: foo」error bubble
- `payload` JSON schema validation 失敗 = silent silent + Sentry breadcrumb 記録
- `scene_transition.duration_ms > 2000` = 2000 cap (= UX 暴走防止)
- `narrative_choice.options.length > 4` = 先頭 4 件のみ採用
- `context_handoff.to_mentor_id` 不在 = "/" home fallback

## 5. Win Codex hand off scope

- [ ] `supabase/functions/_shared/tool_schema.ts` (= §3 enum + payload type)
- [ ] `supabase/functions/<existing-ai-hub>/index.ts` (= ABSTRACT_ACTIONS allow list 追加)
- [ ] `lib/services/ai_tool_dispatcher.dart` (= §4.1)
- [ ] `lib/widgets/narrative_choice_sheet.dart` (= §4.3 / 新規)
- [ ] `lib/widgets/recap_bubble.dart` (= §4.2 / 新規)
- [ ] `lib/services/theme_notifier.dart` (= §4.2 setMood / 既存拡張)

EF 数 +0 (= 既存 ai-hub 流用 / [EF-CAP-50] 完全遵守).
推定工数: 9h (= schema 1h + dispatcher 2h + sheet 2h + recap bubble 1h + ambient 1h + integration 2h).

## 6. PHILOSOPHY-22 / AI-CHARACTER-24 / IMBUE-25 alignment

### PHILOSOPHY-22

- ✅ #2 ミッション — AI 表現力で mentor 体験
- ✅ #5 商品=価値 — UI hack ゼロ化が直接価値
- ✅ #6 時間最適化 — 場面切替が会話速度に追従
- ✅ #7 資産負債 — schema enum = 拡張資産

### AI-CHARACTER-24

- ✅ #3 人格表現 — narrative_choice + ambient で人格 surface
- ✅ #5 会話自然性 — scene_transition で文脈 jump 自然化
- ✅ #6 倫理 gate — deny-by-default + cap

### IMBUE-25

- ✅ #4 mentor 感 — recap + cliffhanger で導く
- ✅ #6 CEO 感 — narrative_choice で意思決定権ユーザー側
- ✅ #7 流れ感 — scene_transition + ambient

## 7. 受け入れ条件 mapping

| 受入条件 | 対応 section |
|---|---|
| #1 enum に narrative_choice / scene_transition 追加 | §3.1 (enum) + §3.2 (payload) |
| #2 frontend safe-handle | §4.1 (dispatcher) + §4.2 (map) + §4.4 (deny-by-default) |
