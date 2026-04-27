# Collaborative AI 7 設計パターン — Thinking Machines / Tinker 由来

> このドキュメントは、自分株式会社の AI システム自体を **「人間と協働して進化する
> 知能基盤」として設計する** ための **必守実装パターン** である。
>
> **ソース**: NotebookLM Notebook [Architecting the Frontier of Collaborative Intelligence](https://notebooklm.google.com/notebook/491f57bc-68a1-4b12-b1f8-5eaffbc0fe8e)
> Thinking Machines Lab (Mira Murati 創設・OpenAI 元 CTO) 公式サイト + Tinker フレームワーク (sample/forward_backward/optim_step/save_state) ドキュメントを統合した notebook (2026-04-28 取り込み)
>
> **位置づけ**: 既存ドキュメントとの 5 軸構成
> - [PHILOSOPHY.md](./PHILOSOPHY.md) (9 原則) = **何を作るか / why**
> - [AI_DEV_PRINCIPLES.md](./AI_DEV_PRINCIPLES.md) (7 原則) = **どう作るか / how**
> - [AI_CHARACTER_PRINCIPLES.md](./AI_CHARACTER_PRINCIPLES.md) (8 原則) = **どんな人格で動くか / who**
> - [IMBUE_PATTERNS.md](./IMBUE_PATTERNS.md) (7 パターン) = **どう体験させるか / how it feels**
> - **COLLAB_AI_PATTERNS.md** (7 パターン) = **どう一緒に進化するか / how it evolves**

---

## なぜ必要か

IMBUE_PATTERNS は「ユーザーが CEO 感を保つ UX」を扱うが、その背後で AI システム
自体が **どのように学習し / どんな失敗を防ぎ / どう進化するか** は規定されていない。
Thinking Machines は「完全自律 AI」を否定し、**人間と協働して進化するシステム**
の構築を中核哲学に据え、Tinker フレームワークでこれを 4 つの関数に抽象化した。
これを自分株式会社の AI 基盤設計に適用する。

---

## 7 パターン

### パターン 1: Co-Reasoning (共創的推論) — IMBUE #1 補強

**ルール本文**: AI が「唯一の正解」を提供せず、**A 案 B 案のシミュレーション結果 +
価値観への問い** を提示してユーザーの判断プロセス自体に AI を組み込む。

**なぜ重要か**: Thinking Machines は完全自律ではなく協働システムを優先する。
AI 単独では辿り着けない応用範囲がユーザーの専門知識との結合で開ける。

**どう適用するか**:
- ai-hub `judgment.get` の advice payload に **複数選択肢 (alternatives[])** を必須化
- 各選択肢に `tradeoff_summary` と `value_question` (CEO に問う質問) を併記
- IMBUE Pattern 7 (Sculptor UI) の review 段階でこれらを並列表示

### パターン 2: Tinker 4-Function Self-Evolution Loop — 新規

**ルール本文**: ユーザーの行動サイクルを Tinker API の 4 関数概念
(`sample` / `forward_backward` / `optim_step` / `save_state`) で抽象化する。

**なぜ重要か**: Tinker は研究者がインフラ複雑さに悩まずデータと評価に集中できる
よう 4 関数で訓練を制御する。これを UX に応用するとユーザーは「AI を育てている」
意識なしで、対話を通じて自分専用メンターに微調整できる。

**どう適用するか**:
- `sample` = AI メンターの提案生成 (= IMBUE Pattern 6 actions[])
- `forward_backward` = ユーザーが実行結果を入力 → 評価 + 誤差計算
- `optim_step` = ai-hub バックグラウンドでユーザー特性プロンプトの更新
  (LoRA 的 light-weight fine-tuning 相当 / system prompt のパーソナライズ追加文)
- `save_state` = Supabase の `user_ai_profile` テーブルにセッション状態保存
- 新規 EF: `ai-hub` action `profile.optim_step` を作成 (4 関数のうち抽象化されてない最後の輪)

### パターン 3: マルチモーダル意図捕捉 — IMBUE #4 拡張

**ルール本文**: テキスト入力に加え、**音声 / 画像 / 環境データ** で CEO の真の意図を
捕捉する。

**なぜ重要か**: テキスト疲れ時 (散歩中 / ベッド中) でも壁打ち可能化、写真からの
状況読み取りで「文字化されていない真実」を補完できる。

**どう適用するか**:
- ai-assistant に音声入力モード追加 (Web Speech API → trans → ai-hub provider.chat)
- 散らかった部屋 / 達成成果の写真アップロード → ai-hub `vision.analyze` action
- 声のトーンからストレス度推定 → daily-judgment の入力シグナルに追加
  (= AI_CHARACTER 原則 6 の「複数シグナル」要件を満たす)

### パターン 4: 真の価値 KPI 再定義 — IMBUE #5 深化

**ルール本文**: 「滞在時間」「アクセス頻度」を最適化対象から外し、**現実世界での
価値創出 / CEO としての成長** を測る KPI を定義する。

**なぜ重要か**: Thinking Machines は「既存指標の最適化」より「真の価値生成の測定」
からブレークスルーが生まれると主張する。アプリを長く使わせる方向に最適化すると
ユーザーの人生が消費される (= PHILOSOPHY 原則 6 「資本=時間」と矛盾)。

**どう適用するか**:
- ホーム画面の "連続 N 日" / "起動 N 回" バッジを削除 (IMBUE #5 の徹底)
- 代替指標: 「今週現実世界で下した重要な決断数」/ 「心理的負担の前週比」/
  「アプリ外時間でのアクション完了率」
- daily-judgment に `external_action_score` 必須出力 (アプリ外行動の量×質)
- 短時間使用でも "現実アクション" 高評価のスコアリングロジックを採用

### パターン 5: Research → Deployment 反復ループ — 新規

**ルール本文**: AI が策定した戦略 (Research) → ユーザーが現実で実行 (Deployment) →
即座フィードバック → AI が次の戦略を Pivot、を **強制ループ化** する。

**なぜ重要か**: 同ラボの「Research と Product の共同設計」哲学では、
deployment を通じた反復学習が現実に基づく最も影響力ある問題解決を導く。
AI の推論を現実行動の結果で検証し続けないとメンターは絵空事になる。

**どう適用するか**:
- 戦略を AI が提案 → 1-7 日後に **「実証実験振り返りセッション」を強制プッシュ通知**
- 振り返り UI: 想定通り? / 何が違った? / 次の Pivot 方向?
- ai-hub `strategy.pivot` action: 振り返り結果を入力に新戦略を生成
- 既存 daily-judgment に week-pivot サマリ追加

### パターン 6: 管理インフラの完全抽象化 (Eval-First UX) — IMBUE #7 補強

**ルール本文**: 「作業 (タスク実行 / スケジューリング)」を AI に肩代わりさせ、
ユーザーは **「決断」と「評価」のみ** に集中する UX を作る。

**なぜ重要か**: Tinker の最大価値は研究者がインフラ複雑さから解放され
データと Evals に集中できることだった。これを CEO UX に転写する。

**どう適用するか**:
- 情報収集 / 目標細分化 / スケジューリングはバックグラウンド自動化
- UI に出すのは「A vs B どちらか?」「この成果は基準を満たしているか?」の
  二択評価ボタンが基本
- IMBUE Pattern 7 (Sculptor UI) の simulate 段階で AI が代替案を提示し、
  apply はワンタップで完結

### パターン 7: Red-Team Mode (人生のセーフティ・ネット) — 新規

**ルール本文**: ユーザーが重大決断 (退職 / 大型買物 / 引越 / 投資) を入力した際、
AI が **批判的検証者** に切り替わり潜在リスクをあぶり出す。

**なぜ重要か**: 効果的な AI セーフティは事前検証と現実テストの組み合わせから生まれる。
ユーザーが昂揚状態で危険決断を下しかけた時、AI が即同意すると「人生の Sentinel」
としての価値が消える。

**どう適用するか**:
- クリティカル・プロンプト検出: 「会社を辞める」「家を買う」「投資する」等の
  キーワード + 金額/期限の存在 → red-team モード起動 (= AI_CHARACTER 原則 6
  「複数シグナル」要件)
- red-team 質問テンプレ: 「最悪シナリオは?」「資金ショートリスクは?」
  「失敗時の撤退条件は?」「3 日後・3 ヶ月後・3 年後の自分はこの決断を支持する?」
- ユーザーが質問に回答完了するまで決断確定 UI を **意図的にロック**
- 回答後、AI は assertions[] (検証済 + 残リスク) と final_recommend を出力

---

## 開発判断チェックリスト

```markdown
### Collaborative AI Patterns Check

- [ ] **#1 Co-Reasoning**: 複数選択肢 + tradeoff + 価値観質問を出力するか?
- [ ] **#2 Tinker 4-Function**: optim_step (バックグラウンド学習) ループがあるか?
- [ ] **#3 Multimodal**: 音声/画像/環境データのいずれかを補助入力として受けるか?
- [ ] **#4 True-Value KPI**: 滞在時間/起動数を成功指標にしていないか?
- [ ] **#5 R→D Loop**: AI 提案 → 実行 → 振り返り → Pivot を強制循環しているか?
- [ ] **#6 Eval-First UX**: ユーザー操作の主軸が「決断」「評価」になっているか?
- [ ] **#7 Red-Team Mode**: 重大決断時に批判的検証フェーズが起動するか?

合計 7 項目中:
- 6+ ✅ → 即実装可
- 4-5 ✅ → 設計再考
- 3 以下 ✅ → 実装見送り or 大幅再設計
```

---

## IMBUE_PATTERNS との重複/補完マップ

| COLLAB | IMBUE 重複 | IMBUE 補完 | 新規貢献 |
| --- | --- | --- | --- |
| #1 Co-Reasoning | #1 DIY mentor | tradeoff + value_question 必須化 | — |
| #2 Tinker 4-Function | — | — | **新規** (システム自己進化) |
| #3 Multimodal | #4 Sanitized | 音声/画像チャネル追加 | — |
| #4 True-Value KPI | #5 Anti-vanity | external_action_score 具体化 | — |
| #5 R→D Loop | — | — | **新規** (deployment-feedback 強制) |
| #6 Eval-First UX | #7 Sculptor UI | apply ワンタップ統一 | — |
| #7 Red-Team Mode | — | — | **新規** (重大決断セーフティ) |

→ **truly new = #2 / #5 / #7 の 3 パターン**。残 4 つは既存 IMBUE 視点の深化。

---

## 既存機能の評価

| 機能 | #1 | #2 | #3 | #4 | #5 | #6 | #7 | スコア |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ai-assistant | ❌ | ❌ | ❌ | ❌ | ❌ | △ | ❌ | 0.5/7 |
| daily-judgment (ai-hub) | ❌ | ❌ | ❌ | ❌ | ❌ | △ | ❌ | 0.5/7 |
| ai-writing-assistant | N/A | ❌ | ❌ | N/A | ❌ | △ | N/A | 0.5/7 |
| habit / streak | ❌ | ❌ | ❌ | ❌ | △ | ❌ | ❌ | 0.5/7 |

→ 全機能 1/7 未満。**最優先: #7 Red-Team Mode** — 既存 daily-judgment に
クリティカル・キーワード検出 + 質問テンプレ起動を 1 機能追加するだけで 1 → 1.5/7、
かつユーザー価値最大の安全装置。

---

## 5 軸全体の関係

| 軸 | 質問 | 例 |
| --- | --- | --- |
| PHILOSOPHY | **why** | 「ユーザーが CEO」 |
| AI_DEV | **how** | 「Sentinel/Warden 通せ」 |
| AI_CHARACTER | **who** | 「セラピスト擬装禁止」 |
| IMBUE | **how it feels** | 「actions[] 必須」 |
| **COLLAB_AI** | **how it evolves** | 「Red-Team Mode・4-Function loop」 |

**5 軸すべてクリアした機能のみ実装可** とする。

---

## 次のアクション候補

1. **#7 Red-Team Mode 実装**: ai-hub に新 action `judgment.red_team` 追加。
   入力: { decision_type, decision_text, amount, deadline }。
   出力: { questions[], assertions[], final_recommend }。
   キーワード検出は最低 5 シグナル (decision keyword + 金額 + 期限 + tone +
   履歴差分)。
2. **#5 R→D Loop**: `strategy_runs` テーブル新規。AI 提案を `proposed_at` で記録 →
   `executed_at` ユーザー記入 → `reviewed_at` で振り返り作成 → ai-hub
   `strategy.pivot` で next strategy 生成。
3. **#2 Tinker 4-Function**: `user_ai_profile` テーブル新規。
   columns: user_id / personalization_prompt / interaction_count / last_optim_at。
   ai-hub `profile.optim_step` action でユーザー応答履歴から
   personalization_prompt を 7 日毎更新 (= 軽量 LoRA 相当)。
4. **#3 Multimodal**: ai-hub に `vision.analyze` action skeleton 追加。
   入力 image_url → Gemini 1.5 Vision でラベル + 状況推定 →
   daily-judgment 入力に統合。
5. **#4 True-Value KPI**: home_page.dart の連続日数表示廃止 cross-instance-pr
   (VSCode版担当 / IMBUE Pattern 5 と統合実装)。

---

## 改訂履歴

| 日付 | 変更 |
| --- | --- |
| 2026-04-28 | 初版 (NotebookLM `491f57bc-68a1-4b12-b1f8-5eaffbc0fe8e` から蒸留) |
