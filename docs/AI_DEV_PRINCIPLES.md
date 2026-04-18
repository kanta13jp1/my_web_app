# AI 開発 7 原則 — 自分株式会社 開発フロー必須遵守事項

> このドキュメントは AI エージェント・AI 機能を開発・運用するときの **必守原則** を定義する。
> CLAUDE.md Rule 23 によって全機能・全インスタンスで強制適用される。
>
> **ソース**: NotebookLM Notebook [Perils of Invisible Defaults](https://notebooklm.google.com/notebook/7e39f060-7f61-4a31-babb-237da14f06aa)
> AI エージェントを活用してわずか 1 日で 23 ページを構築した開発者の実体験 + 教訓集
>
> **位置づけ**: PHILOSOPHY.md 9 原則 (= 何を作るか / why) と並列で本ドキュメントは **どう作るか / how** を規定する

---

## なぜ必要か

AI ツールで開発スピードが圧倒的に上がる一方、**目に見えない欠陥** が大きな代償を生む:

- API キーの上書きで数時間ロス
- セキュリティ欠陥で初日からサーバ制御を奪われる
- ハルシネーションループで数分で月予算消費
- メモリーなしで毎セッション同じミスを繰り返す

**AI 開発の安全な高速化は強力な監視・制御・記憶の組み合わせで実現する**。

---

## 7 原則

### 原則 1: 認証レイヤー管理 (Auth Layer Discipline)

**ルール本文**: API キー・認証情報は単一の信頼できる source of truth で管理し、古い値が新しい設定を上書きしないようにする。

**なぜ重要か**: 古い `.env` や Supabase Secrets の残値が新しい設定を黙って上書きすると、デバッグできない数時間のロスを生む。AI 開発では認証エラーが「動作するが間違った先に向かう」形で出るため検知困難。

**どう適用するか**:
- Supabase Secrets が真値・`.env.local` は禁止 (重複防止)
- セッション開始時に `notebooklm status` のような認証検証コマンドを必ず実行
- 古いキー削除を必ず明示記録 (`memory/feedback_correction_*` で永続)
- API キーローテーション時は **古い値を即時無効化** + 新しい値の動作確認まで 1 セッション内で完結

### 原則 2: デフォルト拒否 (Deny-by-default Security)

**ルール本文**: MVP 段階から「明示的に許可されない限り全てブロック」のミドルウェア・バリデーションを組み込む。後付けセキュリティは禁止。

**なぜ重要か**: パストラバーサル・SQLi・ファイルアップロード脆弱性は **顕在化するまで見えない**。最初のユーザーがサーバ制御を奪う致命的リスク。リリース後の修正は 100 倍コスト。

**どう適用するか**:
- 新規ルートは Edge Function `verify-jwt` で認証を必ず通す (デフォルトで JWT 検証 ON)
- ユーザーメール単位の rate limit (例: AiQuotaGuard 60 秒 cooldown)
- ファイルアップロードは拡張子ホワイトリスト + サイズ制限 (例: 5MB)
- `Bash(rm:*)` `Bash(sudo:*)` は `~/.claude/settings.json` permissions deny で禁止

### 原則 3: トレースベース可観測性 (Trace-based Observability)

**ルール本文**: 全 HTTP リクエストに `trace_id` を付与し、各エージェント呼び出しを span として記録する。動作の完全可視化を担保。

**なぜ重要か**: 複数 AI エージェントが連鎖する複雑なシステムで可観測性がなければ、ボトルネック特定もエラー原因究明も「当て推量」になる。本番障害時に復旧時間が桁違いに増える。

**どう適用するか**:
- 新 Edge Function には `console.log({ trace_id, span_name, duration_ms })` 必須
- 5 秒超のリクエストは `incident-report` で自動記録
- Supabase `ai_quota_usage` + `health-check` EF で全 AI 呼び出しを集計
- 失敗トレースを `docs/incident-reports/YYYY-MM-DD-HH.md` に蓄積

### 原則 4: コスト・サーキットブレーカー (Cost Circuit Breaker)

**ルール本文**: AI エージェント稼働コストに対して **絶対譲れない (non-negotiable)** 多層上限値を設定し、超過時自動遮断する。

**なぜ重要か**: ハルシネーションを起こしたエージェントが無限ループに陥ると、**数分で月予算を使い果たす**。ユーザー増加で破産速度も加速する。

**どう適用するか**:
- 4 段階上限 (例):
  - リクエスト単位: $2
  - エージェント 1 時間単位: $10
  - ビジネス 1 日単位: $50
  - プラットフォーム 1 時間単位: $100
- 超過リクエストは即時 401/429 で遮断
- Supabase `ai_quota_usage` テーブル + `quota-monitor.yml` Dashboard で監視
- 既実装: AiQuotaGuard 60秒 cooldown (Windows版#78・ai-assistant 429 緩和)
- **未実装**: business/platform 全体 cap → Win#101 候補

### 原則 5: チームメモリー (Team Memory with Effectiveness Score)

**ルール本文**: エージェントの成功・失敗・最適化パターンを蓄積し、各記憶に **有効性スコア (0.0〜1.0)** を付与する。低スコアは減衰、高スコアはプロンプト先頭に自動注入する学習システム。

**なぜ重要か**: 単なるコードコピーでは得られない「蓄積知識」が **競合に対する防御壁 (moat)** になる。エージェントが過去パターンを次に活かすことで学習効果が複利で働く。

**どう適用するか**:
- 既存: `memory/feedback_success_*.md` + `memory/feedback_correction_*.md` (有効性スコアなし)
- 既存: `~/.claude/hooks/inject-rules.txt` (毎ターン system-reminder 注入)
- 既存: NotebookLM Master Brain (`jibun-master-brain` notebook)
- **未実装**: 有効性スコア付与・自動減衰・自動注入優先度ソート → 将来拡張候補
- 既存パターンの強化策として今すぐ実施可能: memory ファイル冒頭の `description` を「有効性: high/medium/low」で前置き

### 原則 6: チェックポイント + 再試行 (Checkpoint + Retry)

**ルール本文**: エージェント連鎖処理の各ステップで状態を保存し、失敗時に途中から再開できる仕組みを持たせる。再試行ポリシー + dead letter queue を整備。

**なぜ重要か**: AI 処理は不安定で、障害発生のたびに最初からやり直すのは時間とコストの浪費。長時間ジョブで途中失敗 → 全消滅は致命的。

**どう適用するか**:
- 長時間 EF (`predict_all` バッチ・`competitor-monitoring` 等) は中間結果を Supabase に保存
- `can_resume: true` フラグで再開ポイントを明示
- 再試行ポリシー: `default`(3回) / `critical`(5回 + alert) / `fast_fail`(0回・即エラー)
- Dead letter queue: 全試行失敗ジョブは `docs/incident-reports/` + `cs-notes/` に escalate
- 既実装: `predict_all` batch 化で 150s timeout 回避 (Windows版#94b)

### 原則 7: 品質監視ゲート (Quality Gate / Sentinel + Warden)

**ルール本文**: 自律的に外部に出力するエージェントの前段に、必ず **事実確認 (Sentinel)** + **品質確認 (Warden)** の関所を設ける。

**なぜ重要か**: X 自動投稿・メール送信・PR コメントなどが **スパム化** したり **誤情報拡散** したりするリスクは高い。一度信頼を失うと取り戻せない。Qiita 自己返信ループ (Win版#98 修正) はこの原則違反の典型例。

**どう適用するか**:
- 任意の自動投稿前に:
  - Sentinel: 事実確認 (URL アクセス可能か / モデル名が現存するか / 数値が最新か)
  - Warden: 品質確認 (文体・冗長度・誤字脱字・author == 自分の skip 確認)
- 既存: `blog_engagement.py` の `MAX_REPLIES_PER_ARTICLE=2` (defense-in-depth)
- 既存: `cs-check` の FAQ vs バグ vs エスカレーションの 3 段階判定
- **未実装**: blog 自動投稿の Warden (重複検出・誤投稿防止) → 将来候補

---

## 開発判断チェックリスト (新 AI 機能設計時に必ず確認)

```markdown
### AI Dev Principles Check

- [ ] **原則 1 (Auth)**: API キー source of truth は明確か?
- [ ] **原則 2 (Deny-default)**: 認証・rate limit・サイズ制限は最初から組み込んだか?
- [ ] **原則 3 (Observability)**: trace_id + 5秒超検出は入っているか?
- [ ] **原則 4 (Circuit breaker)**: 4 段階のコスト上限を設定したか?
- [ ] **原則 5 (Memory)**: 成功・失敗パターンを memory に記録するか?
- [ ] **原則 6 (Checkpoint)**: 長時間処理は再開可能か? dead letter queue ある?
- [ ] **原則 7 (Quality gate)**: 自動出力に Sentinel/Warden を通すか?

合計 7 項目中:
- 6+ ✅ → 即実装可
- 4-5 ✅ → 設計再考 (どこかで spam/explosion リスク)
- 3 以下 ✅ → 実装見送り or 大幅再設計
```

---

## PHILOSOPHY.md (9 原則・what/why) との関係

| 軸 | PHILOSOPHY.md | AI_DEV_PRINCIPLES.md |
| --- | --- | --- |
| 対象 | サービス全体 (UX 哲学) | AI 機能の実装方法 |
| 質問 | **何を作るか / なぜ** | **どう作るか / how** |
| 例 | 「ユーザーが CEO」 | 「自動投稿前に Warden 通せ」 |
| 違反時 | 機能撤回検討 | 即修正必須 (本番事故リスク) |

**両方クリアした機能のみ実装可** とする。PHILOSOPHY.md = 戦略レイヤー / AI_DEV_PRINCIPLES.md = 戦術レイヤー。

---

## 既存機能の評価 (要レビュー)

| 機能 | Auth | Deny | Obs | Circuit | Memory | Retry | Gate | スコア |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ai-assistant (3-柱) | ✅ | ✅ | △ | ✅ AiQuotaGuard | △ | ✅ | △ | 5/7 |
| ai-hub provider.chat | ✅ | ✅ | △ | △ | △ | ✅ | △ | 4/7 |
| blog-publish | ✅ | △ | △ | ❌ | △ | △ | ❌ | 2/7 |
| blog-engagement | ✅ | ✅ | △ | ✅ MAX_REPLIES | ✅ | ❌ | ✅ | 5/7 |
| competitor-monitoring | ✅ | ✅ | △ | ❌ | △ | ❌ | △ | 3/7 |
| cs-check | ✅ | ✅ | △ | ❌ | ✅ | △ | ✅ | 4/7 |

→ **competitor-monitoring + blog-publish が要改善**。それぞれ Win#101+ 候補。

---

## 改訂履歴

| 日付 | 変更 |
| --- | --- |
| 2026-04-19 | 初版 (Windowsアプリ版#100・NotebookLM 7e39f060 から蒸留) |
