---
title: "AI 依存をポートフォリオ化する — Claude / OpenAI Codex / 自分株式会社を BS で語る"
tags: AI,Claude,OpenAI,個人開発,buildinpublic
published: false
---

# AI 依存をポートフォリオ化する — Claude / OpenAI Codex / 自分株式会社を BS で語る

## この記事の立ち位置

先に書いた本A「[Claude Code vs OpenAI Codex Desktop vs 自分株式会社 — AI を束ねる個人 CEO の 3 層設計](https://my-web-app-b67f4.web.app/)」では、3 者が違う層で働くから競合しないという **住み分けの地図** を示した。

この記事はその続編で、**「なぜ束ねるのが合理なのか」を会計的に語り直す** ことが主題。個人 CEO の頭の中にバランスシート (BS) を置いて、AI 依存度を「資産」と「負債」に分解する。

## 前提の事実 (2026-04-17 イベント)

2026-04-17 に OpenAI Codex Desktop が Computer Use + 20+ plugins + MCP servers を追加した。
当初「Codex 90+ plugin で Claude にパリティ+α」と報じられたが、複数 source を交差させると実際は:

- **Claude Code: 423 plugins / 2,849 skills / 177 agents** (43 marketplaces / 834 total)
- **OpenAI Codex: 20+ plugins (self-serve publish 未対応)**

→ Claude は plugin で **約 20 倍** リード。Codex が追いついたのは **Computer Use カテゴリのみ**。

この事実の数字は後段で使うので一旦キープ。

## 個人 CEO の BS 原則 (自分株式会社 第 7 原則)

自分株式会社の 9 原則のうち、原則 7 は「資産負債バランスシート」。
定義はシンプルに:

> 将来の収益・時間・自由度を**増やす**もの = 資産
> 将来の収益・時間・自由度を**減らす**もの = 負債

会社員でも個人開発者でも、毎日の選択は BS の片側を厚くする行為の連続。AI ツール選定もここから逃げられない。

## AI ツールを BS で分解する

単一 vendor ロックインを会計目線で見ると、**流動性が極端に低い短期負債**に相当する。理由:

1. **置換コスト (switching cost)**: memory / skill / plugin / workflow が vendor 固有 → 他社乗換時に再構築
2. **価格リスク (price risk)**: 値上げ時に拒否権ゼロ (Anthropic $20→$100/seat の件を想起)
3. **稼働リスク (availability risk)**: 障害時に仕事停止 (個人 CEO は冗長化スタッフ不在)
4. **ロードマップリスク (roadmap risk)**: vendor の戦略変更で自分のワークフローが陳腐化

具体例で当てはめる:

| AI ツール | 短期負債 (-) | 隠れ資産 (+) | 正味評価 |
|---|---|---|---|
| Claude Code 単一依存 | Anthropic 全面依存 / 423 plugin も Anthropic が止めたら使えない | plugin エコシステム世界最大 | **負債優勢** (単一依存) |
| OpenAI Codex 単一依存 | ChatGPT エコシステム全面依存 / Computer Use の先行 1 ヶ月 | 3M 週次 DAU の情報流通量 | **負債優勢** (単一依存) |
| Cursor 単一依存 | Anysphere 依存 + IDE ロックイン | IDE 内完結の UX | **負債優勢** (単一依存) |
| **自分株式会社 (ai-hub 分散)** | 初期実装コスト | Claude + OpenAI + Gemini + fallback を束ねる指揮所 / 障害時 fallback 自動切替 | **資産優勢** (手段分散) |

「Claude が 423 plugin で強い」は事実だが、**単一 vendor 依存という負債を正当化する理由にならない**。むしろ plugin 数 423 > 20 だからこそ「離脱コストが高い」= 将来の選択肢を縛るロックインという裏面が強まる。

## 自分株式会社の実装パターン

### ai-hub で vendor を選ばない側に回る

```dart
// 擬似コード: Flutter Web 側の呼び出し
final response = await supabase.functions.invoke('ai-hub', body: {
  'action': 'provider.chat_auto',
  'messages': [...],
  'intent': 'design_decision', // → Claude ルーティング
});
```

Edge Function 側で intent を見て振り分け:

| intent | 1 st choice | fallback 1 | fallback 2 |
|---|---|---|---|
| `design_decision` (長期 memory 重視) | Claude Sonnet | GPT-4.1 | Gemini 2.5 Pro |
| `computer_use_required` | Codex (plugin) | Claude Computer Use | — |
| `cost_sensitive_bulk` | Haiku | Gemini Flash | DeepSeek |
| `fallback_any` | Gemini Flash | Haiku | Mistral Small |

### cost-hub の 4 段階 CB

1. **green**: 通常 (全モデル利用可)
2. **yellow**: per-session cost > $0.50 → sonnet → haiku 降格
3. **orange**: $1.50 → flash / deepseek-v3 に強制降格
4. **red**: $3.00 → call 停止 + alert

→ 単一 vendor 価格改定に振り回されない。Anthropic が値上げしても Gemini / DeepSeek 側が安ければそちらに流れる。

### Supabase に歴史を持たせる

AI ツール本体に依存しない状態で、**自分株式会社の PostgreSQL が歴史を保持**:

- 睡眠 / 支出 / 学習 / 健康 / KPI → Supabase table
- Claude session / Codex plugin 起動は揮発 / 単発
- → 「AI を乗り換えても過去の自分データは残る」= fixed asset として減価しない

## 会計的に整理するとこうなる

個人 CEO の BS (資本 = 時間・注意・自由度) を簡易 T 字で書くと:

```
【資産 (+)】                              【負債 (-)】
- 6 部署 KPI 履歴 (Supabase)             - AI 単一 vendor 依存
- ai-hub routing 資産                    - 手動クレジット残高ウォッチ労働
- 自作 hook / workflow                   - 無言 pause (課金切替で突然停止)
- 横断検索可能な memory/                 - 英語 first UX の認知コスト

【純資産】
= 資産 − 負債
= ai-hub × 6 部署統合 × 日本語 UX
```

単一ツールへの課金を止めても自分株式会社の純資産は減らない。これが「束ねる」設計の core。

## 結論

- 「どの AI を選ぶか」は短期負債の構成を決める意思決定
- 「AI を束ねるハブを持つか」は固定資産の有無を決める意思決定
- 個人 CEO の合理解は後者 = **自分の BS の資産サイドを厚くする**

Claude の plugin 423 はすごい。Codex の Computer Use もすごい。でも、どちらか 1 つに賭ける必要は 1 ミリもない。**束ねれば両方の強みを資産計上できる**。

## 参考

- 本A 住み分け地図: [Claude Code vs OpenAI Codex Desktop vs 自分株式会社 — AI を束ねる個人 CEO の 3 層設計](https://my-web-app-b67f4.web.app/)
- 9 原則: <https://my-web-app-b67f4.web.app/philosophy>
- 21 競合比較: <https://my-web-app-b67f4.web.app/comparison>
- 本番: <https://my-web-app-b67f4.web.app/>
