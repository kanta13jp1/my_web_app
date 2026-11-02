# Imbue 7 設計パターン — 自分株式会社の AI×人生設計 実装ガイド

> このドキュメントは、自分株式会社の AI 機能・UI 機能を設計するときに **どんな
> 体験パターンで作るか / how should it feel** を規定する **必守実装パターン** である。
>
> **ソース**: NotebookLM Notebook [Imbue: Empowering Human Agency Through AI Reasoning and Coding](https://notebooklm.google.com/notebook/2fc6d86f-2bbd-4fdc-ad9e-f302d93b5c6e)
> Imbue 公式ブログ + CARBS (Cost-aware hyperparameter tuning) GitHub + Kanjun Qiu CEO Q&A + sanitized datasets paper を統合した notebook (2026-04-27 取り込み)
>
> **位置づけ**: 既存ドキュメントとの 4 軸構成
> - [PHILOSOPHY.md](./PHILOSOPHY.md) (9 原則) = **何を作るか / why**
> - [AI_DEV_PRINCIPLES.md](./AI_DEV_PRINCIPLES.md) (7 原則) = **どう作るか / how**
> - [AI_CHARACTER_PRINCIPLES.md](./AI_CHARACTER_PRINCIPLES.md) (8 原則) = **どんな人格で動くか / who**
> - **IMBUE_PATTERNS.md** (7 パターン) = **どう体験させるか / how it feels**

---

## なぜ必要か

PHILOSOPHY (what) / AI_DEV (how) / AI_CHARACTER (who) の 3 軸が揃っても、
**ユーザーが AI を「自分の人生の共同作業者」として使いこなせる体験** には
なりにくい。Imbue は "Empowering Human Agency Through AI Reasoning and Coding"
を掲げる AI 研究組織で、その手法 (CARBS, sanitized datasets, Sculptor UI) は
「AI を抱え込んだまま、人間のエージェンシー (主体性) を最大化する」という
本サービスのミッションと完全に重なる。これを自分株式会社の機能設計に
パターンとして注入する。

## 2026-08-26 公式ソース再レビュー

Imbue の現在の公式方針は、人間が AI に従属するのでなく、自分のソフトウェアと
agent を作成・変更・制御できることを重視している。また、agent UX では
inspectability が信頼性と同じく重要だと説明している。

- [Empowering humans in the age of AI](https://ideas.imbue.com/p/empowering-humans-in-the-age-of-ai)
- [Why AI agents don't work (yet)](https://imbue.com/blog/latent-space-imbue)
- [Human agency vs. "agentic" AI](https://imbue.com/blog/human-agency-vs-agentic-ai-kanjun-on-the-nonzero-podcast)

この再レビューでは、候補だった「Transparent Reasoning Trail」と
「Autonomy Preservation in Automation」を独立したパターン 8 / 9 に増やさない。
前者はパターン 6 のユーザー向け根拠要約とパターン 7 の review、後者は
パターン 1 の最終決定権とパターン 7 の preview / approval / undo を強化する
横断要件として扱う。これによりチェックリストを重複させず、既存の7パターンを
後方互換のまま維持する。

「透明性」は private chain-of-thought の保存・表示を意味しない。表示するのは
ユーザーが提案を評価するための簡潔な根拠、参照情報、不確実性、想定影響である。
また、本ドキュメントは設計契約を定めるものであり、scheduled task の確認/undo UIが
全機能へ実装済みだとは主張しない。個別UIは feature freeze と優先順位に従って扱う。

---

## 7 パターン

### パターン 1: DIY メンター設計 (Empowering Human Agency)

**ルール本文**: AI 機能を「指示を出すボット」ではなく、ユーザー (CEO) が自分の
目的に合わせて **性格・焦点・役割を自由にカスタマイズできる共同作業者** として
設計する。最終的な意思決定権は常に人間に残す。

**なぜ重要か**: 命令 → 服従の片方向 AI は「自分の人生を AI に委ねる」体験を
作ってしまい、PHILOSOPHY 原則 1 (CEO 感) と矛盾する。

**どう適用するか**:
- ai-assistant の "3 柱" (柱選択 UI) のように、AI ペルソナのスロット化を
  全 AI 機能で標準化する
- system prompt を「ユーザー編集可能な設定 + 共通 preamble」に分離
  (preamble は `_shared/ai_character_preamble.ts` で固定 / 残りは UI から書き換え可)
- 「AI に決めてもらう」ボタンを「AI に提案させて自分で決める」UX に置換
- ❌ NG: daily-judgment が「今日は X を必ずやれ」と断言する
- ✅ OK: daily-judgment が「今日 X が効率的そうですが、CEO のあなたが
  最終判断してください」と提案する

### パターン 2: コスト制約つき最適化 (CARBS-style)

**ルール本文**: ユーザーの「限られたリソース (時間 / 体力 / 精神力 / 集中力)」を
コストと見なし、AI は **アクションあたりの ROI (パレート境界) を提示** する。

**なぜ重要か**: AI の助言が「全部やれ」になると人間は燃え尽きる。CARBS が
GPU 計算コストと精度のパレートを探すのと同じ思想で、人生の制約下で
「次の 1 手」のコスパを示す必要がある。

**どう適用するか**:
- daily-judgment / focus-tracker / habit-builder の助言生成時、
  **「投入リソース (分・MP) → 期待リターン (KGI 寄与度)」の比** を併記
- ai-hub `judgment.get` の advice 出力に `cost_estimate_minutes` と
  `expected_kgi_lift` フィールドを追加
- ユーザーの「予算」(今日使える時間 + MP) を Supabase に保存し、
  助言は budget 内に収まる組合わせのみ提案
- ❌ NG: 「読書 30 分 + 運動 20 分 + 学習 60 分 + 整理 15 分」(合計超過)
- ✅ OK: 「予算 60 分 → 学習 40 分 (KGI +5) + 整理 15 分 (KGI +1) が最適」

### パターン 3: スケーリング則による予測 (Habit-Scaling Laws)

**ルール本文**: 大きな目標をいきなり立てず、**数日の小規模実験データ** を
取り、そこから現実的な拡大パスを AI が予測・提示する。

**なぜ重要か**: CARBS は小規模モデル実験から 70B モデルの成功を予測した。
人生でも「今日 5 分続けられる習慣を半年後に何時間に拡大できるか」は
小規模データから線形に外挿できる。いきなり「毎日 2 時間」を目標にすると
失敗 → 自己肯定感低下スパイラルに入る (= AI_CHARACTER 原則 2 とも連携)。

**どう適用するか**:
- 新習慣登録時、最初の 7 日は "実験フェーズ" として最小値で開始
  (例: 読書 5 分 / 運動 5 分)
- 7 日経過後、`habit-scaler` ロジックが完了率 + 主観難易度から
  「8 週間で N 分まで拡大可能」と予測 → ユーザーに提示 (パターン 1 と連動)
- 失敗連続 3 日で **自動的に縮小** (拡大の逆方向のスケーリング)
- ❌ NG: ユーザー登録初日に「毎日 2 時間運動」目標を確定
- ✅ OK: 「最初の 7 日は 5 分。データを取って 2 月後に 30 分まで拡大予測を出します」

### パターン 4: クリーンな自己データの蓄積 (Sanitized Self-Data)

**ルール本文**: 曖昧な入力を AI 助言の入力源にせず、**入力時に明確化を促す UI** で
ノイズのないデータベースを構築する。

**なぜ重要か**: Imbue は低品質・曖昧な訓練データを徹底的に排除した
("Sanitized open-source datasets")。AI メンターの助言品質は
Supabase に積み上がるデータの品質に直結する。「なんとなくモヤモヤ」を
そのまま蓄積するとノイズで AI 出力が不安定になる。

**どう適用するか**:
- 感情メモ / 目標 / タスク登録時、AI が「このタスクの成功条件は何ですか?」
  「いつ完了したか分かる指標は?」と 1 回問い返す UI (Flutter 側)
- Supabase の core テーブル (goals / tasks / journal_entries) に
  `clarity_score` カラム追加 → AI 助言は score >= 0.6 のレコードのみ参照
- "I don't know" を許容しつつ、**未明確レコードは "exploration バケット"** に
  分離して助言入力対象から除外
- ❌ NG: 「気分が悪い」の 1 行をそのまま daily-judgment 入力に投入
- ✅ OK: 「気分が悪い」→「いつから? どんな種類? 今日の予定は?」と問い返し →
  明確化されたレコードのみ助言生成に使用

### パターン 5: 本質的進捗の厳格評価 (Anti-Vanity-Metrics)

**ルール本文**: 「タスクをこなした件数」「アプリ起動日数」のような
**バニティ・メトリクス** を成功指標にしない。本当に推論力・人生の質が
向上しているかを測る厳格な評価基準を設ける。

**なぜ重要か**: Imbue は学習モデルの評価で「暗記による高スコア」を排除し、
真の汎化能力を測る評価セットを設計した。本サービスでも「ToDo を 100 件
チェック」が「人生が良くなった」を意味しないという前提で KPI を設計する。

**どう適用するか**:
- daily-judgment の `score` を計算する関数を、`tasks_completed` カウントから
  「タスクと KGI の整合度 + 振り返り深度 + 翌日への反映度」の 3 指標に変更
- 振り返り (journal) の AI 評価で「具体性 (どんな気づきがあったか)」
  「次のアクションの明確度」をスコア化
- "100 日連続ログイン" バッジは廃止 → 「30 日内に KGI を 1 つ達成」
  バッジに置き換え
- ❌ NG: ホーム画面に「連続日数 ⭐ 100 days」を大写し
- ✅ OK: ホーム画面に「先週の自己成長: 集中時間 +12% / 振り返り深度 +5pt」

### パターン 6: 推論とコード化の直結 (Reasoning → DB Action)

**ルール本文**: AI が「ユーザーの悩みを論理的に分解 (推論)」した後、
**結論を Supabase レコードに直接 INSERT する実行力** を持たせる。
助言で終わらせない。

**なぜ重要か**: Imbue の AI は論理的推論と code execution を両立させている。
本サービスでも「AI が良い助言を返したのにユーザーが手で転記」では
moment of truth (= 行動への変換) で価値が消失する。推論結果を
構造化データとして直接書き込むまでが AI 機能の責務。

**どう適用するか**:
- ai-assistant が "週次目標を立てよう" 提案 → ユーザー承認 →
  `goals` テーブルに INSERT + `tasks` に分解タスクを INSERT
  までを 1 つのフローで完結
- AI 出力に **`actions: [{table, op, payload}]` フィールド** を必須化
  (= AI 自身が行動可能なコード/データを生成)
- 各 action の `reasoning` は、内部思考の逐語開示ではなく、ユーザーが判断できる
  **1-2文の根拠要約**とする。必要に応じて参照情報・不確実性・代替案を併記する
- ユーザー確認モーダル → 承認 → service_role で INSERT (RLS 経由) → UI 反映
- ❌ NG: AI が「では goals に 'X を達成する' を追加しましょう」とテキストで
  返し、ユーザーが手動でフォームに入力
- ✅ OK: AI が `[{table:'goals', op:'insert', payload:{title:'X を達成', kgi:5}}]`
  を返し、UI が確認モーダル → ワンタップで反映

### パターン 7: Sculptor 的 UI (Sculpt-with-AI)

**ルール本文**: AI が提案した計画をブラックボックスのまま受け取らせず、
**ユーザーが直感的に修正・編集・テストできるダッシュボード** を必ず併設する。
AI 提案 = 叩き台。

**なぜ重要か**: Imbue の Sculptor UI は AI 出力を「彫刻の素材」として扱い、
人間が削り出していく体験を作っている。本サービスでも AI 提案を
完成品として受け取らせると CEO 感が薄れる (= パターン 1 + PHILOSOPHY 原則 1 違反)。

**どう適用するか**:
- 新機能 (ai-* / *-judgment / *-planner) は **必ず "review/edit panel"** を併設
  - パネル要件: 提案を 1 項目ずつ削除/追加/編集可能 / "シミュレーション"
    ボタンで影響予測表示 / "適用" ボタンでパターン 6 の DB INSERT 発火
- 自動化された理由、変更対象、適用前後の差分、想定影響を apply 前にpreviewする
- cancelを常に提供し、可逆な変更にはundo、不可逆な変更には明示的な再確認と
  compensating action（復旧手順）を用意する
- 誰が・いつ・どの根拠を確認して適用したかをaudit trailへ残す
- AI 出力をいきなり apply しない。**review → edit → simulate → apply** の
  4 段階を経由
- 既存 ai-assistant 出力もこのフローに統一 (legacy "送信ボタンですぐ適用" を廃止)
- ❌ NG: AI 助言モーダル → "OK" ボタン 1 つで Supabase に反映
- ✅ OK: AI 助言モーダル → 各項目編集可 → "シミュレーション" → "適用" の 4 段階

---

## 開発判断チェックリスト (新 AI / UI 機能設計時に必ず確認)

```markdown
### Imbue Patterns Check

- [ ] **パターン 1 (DIY mentor)**: ユーザーが AI のペルソナ・焦点を編集できるか?
- [ ] **パターン 2 (Cost-aware)**: 助言出力に投入時間/MP コストと期待リターンを併記しているか?
- [ ] **パターン 3 (Scaling laws)**: 新習慣/目標は小規模実験 → 拡大パス予測の 2 段階か?
- [ ] **パターン 4 (Sanitized data)**: 曖昧入力に明確化プロンプトを返す UI があるか?
- [ ] **パターン 5 (Anti-vanity)**: 評価指標が件数/連続日数でなく質を測っているか?
- [ ] **パターン 6 (Reasoning→DB)**: `actions[]` とユーザー向け根拠要約を含むか?
- [ ] **パターン 7 (Sculptor UI)**: review → edit → simulate → apply と cancel/undoを経由するか?

合計 7 項目中:
- 6+ ✅ → 即実装可
- 4-5 ✅ → 設計再考 (体験品質リスク)
- 3 以下 ✅ → 実装見送り or 大幅再設計
```

---

## 既存 AI/UI 機能の評価 (要レビュー)

| 機能 | DIY | Cost | Scaling | Sanitized | Anti-Vanity | Action | Sculptor | スコア |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ai-assistant | △ | ❌ | ❌ | ❌ | ❌ | ❌ | △ | 0.5/7 |
| daily-judgment (ai-hub) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 0/7 |
| ai-writing-assistant | △ | ❌ | N/A | ❌ | N/A | ❌ | ❌ | 0.5/7 |
| habit / streak 機能 | ❌ | ❌ | ❌ | △ | ❌ | △ | ❌ | 0.5/7 |
| comparison_page | N/A | N/A | N/A | △ | △ | N/A | △ | 1.5/7 |

→ **すべて 1/7 未満**。Imbue Patterns は本サービス UX 改善の最大伸びしろ。
**最優先: パターン 6 (actions[] 構造化) + パターン 4 (clarity 明確化 UI)** —
この 2 つを実装するだけで 5 機能が一気に 3/7 に到達。

---

## PHILOSOPHY / AI_DEV / AI_CHARACTER との関係

| 軸 | PHILOSOPHY | AI_DEV | AI_CHARACTER | **IMBUE_PATTERNS** |
| --- | --- | --- | --- | --- |
| 質問 | **why** | **how** | **who** | **how it feels** |
| 対象 | サービス全体 | 実装の安全性 | AI の振る舞い | UI/UX 体験パターン |
| 例 | 「ユーザーが CEO」 | 「Sentinel/Warden 通せ」 | 「セラピスト擬装禁止」 | 「actions[] 必須」 |
| 違反時 | 機能撤回 | 即修正必須 | UX 悪化 | "AI が口だけ" 体験 |

**4 軸すべてクリアした機能のみ実装可** とする。
- PHILOSOPHY = 戦略 (この機能はサービス哲学に合うか)
- AI_DEV = 戦術 (この機能は安全に動くか)
- AI_CHARACTER = 人格 (どんな AI として振る舞うか)
- **IMBUE_PATTERNS = 体験 (ユーザーがどう CEO 感を保てるか)**

---

## 次のアクション候補

1. **パターン 6 (actions[]) 共通スキーマ定義**: `supabase/functions/_shared/
   ai_action_schema.ts` を新規作成し、全 AI EF の出力 contract に追加
2. **パターン 4 (clarity 明確化)**: `goals` / `tasks` / `journal_entries` に
   `clarity_score smallint DEFAULT 0` migration + Flutter 入力フォームで
   AI 1 回問い返し
3. **パターン 7 (Sculptor UI) skeleton**: `lib/widgets/ai_review_panel.dart` で
   review/edit/simulate/apply 4 段ウィジェットを再利用可能に
4. **パターン 5 (anti-vanity)**: ホーム画面の "連続 X 日" 表示を「先週の質的指標」に
   置換する `home_page.dart` 改修 cross-instance-pr (VSCode版担当)
5. **パターン 2 (CARBS-cost)**: daily-judgment の advice payload に
   `cost_estimate_minutes` + `expected_kgi_lift` 追加 (ai-hub 改修)

---

## 改訂履歴

| 日付 | 変更 |
| --- | --- |
| 2026-04-27 | 初版 (NotebookLM `2fc6d86f-2bbd-4fdc-ad9e-f302d93b5c6e` から蒸留) |
| 2026-08-26 | Imbue公式方針を再確認し、根拠要約・preview・cancel/undo・audit要件を既存パターン 6/7へ統合 |
