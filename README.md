# AI開発コンテキスト・設計書 (AI_DEV_HANDOVER)

## 1. プロジェクト概要
* **プロジェクト名**: 自分株式会社 (My Web App)
* **技術スタック**:
    * **Frontend**: Flutter (Web)
    * **Backend**: Supabase (Database, Auth, Edge Functions)
    * **AI**: Gemini, OpenAI, Anthropic (Multi-provider)
* **現状のフェーズ**: UI連携フェーズ。バックエンドの全AI機能（"The Five Emperors"）をFlutterアプリのUIから呼び出して利用可能な状態。

## 2. コア・アーキテクチャ: "The Five Emperors" (Edge Function)
`supabase/functions/ai-assistant/index.ts` が全てのAI処理の中核です。

### 2.1 機能構成 (Hybrid Design)
この関数は以下の2つの異なる役割を兼務しています。
1.  **AI稼働モニター (Benchmark)**:
    * **アクション**: `get_models`, `test_model`
    * **機能**: Vision API（画像認識）を用いた6段階の難易度別ベンチマークテスト。
    * **ランキング**: テスト結果（スコアとレイテンシ）をDBに保存し、Vision非対応や低品質なモデルを自動除外（Self-Cleaning）。
2.  **AI実用機能 (Utilities)**:
    * **アクション**: `improve` (校正), `summarize` (要約), `expand` (展開), `translate` (翻訳), `suggest_title` (タイトル提案)
    * **高度なアクション**:
        * `analyze_note_text`: メモの感情分析、タグ抽出、アクションアイテム抽出。
        * `task_recommendations`: ユーザー統計に基づくタスク推奨（AI秘書）。
        * `hold_board_meeting`: CEO, CTO, CMO, CFOによる模擬取締役会。
        * `proactive_intervention`: ユーザーへの自発的な励まし・警告メッセージ生成。

### 2.2 耐障害性 (Fallback Mechanism)
APIレート制限（特にGemini Free Tier）やダウンタイムに備え、以下の優先順位でモデルを自動切替するチェーンを実装済み。
1.  `gemini-2.0-flash` (第1候補: 最速・無料)
2.  `gpt-4o-mini` (第2候補: 安定・安価)
3.  `claude-3-haiku-20240307` (第3候補)

## 3. 重要なファイル構成

| パス | 説明 |
| :--- | :--- |
| `supabase/functions/ai-assistant/index.ts` | **最重要**。全AIロジック、ベンチマーク、フォールバックチェーンが集約されたファイル。 |
| `lib/services/ai_service.dart` | Flutter側のインターフェース。`_retryWithBackoff` によるリトライ処理と、各アクションの呼び出しメソッドを持つ。 |
| `lib/pages/ai_status_page.dart` | AIモデルのランキング表示と手動テスト実行UI。リアルタイムソート機能付き。 |
| `lib/widgets/note_editor/ai_assistant_menu.dart` | ノート編集画面から呼び出すAI機能メニュー（ボトムシート）。 |
| `lib/widgets/note_editor/board_meeting_dialog.dart` | 模擬取締役会の議事録を表示するリッチUI。 |
| `lib/widgets/note_editor/note_analysis_dialog.dart` | AI分析結果（感情、タグ、アクション）を表示するUI。 |
| `lib/pages/note_editor_page.dart` | AIアシスタント呼び出しボタンを追加済みのノート編集画面。 |

## 4. データベース設計 (Supabase)

### `ai_benchmark_results` テーブル
AIモデルの性能評価を記録。
* `user_id`: 実行者
* `model_name`: モデル識別子 (例: `gemini-2.0-flash`)
* `provider`: `gemini` | `openai` | `anthropic`
* `vision_score`: 0-100のスコア
* `latency_ms`: 応答速度
* `detail`: テスト詳細のJSON

### その他の関連テーブル
* `user_stats`: ユーザーのレベル、ポイント、継続日数（AI秘書が参照）。
* `notes`: ユーザーのメモデータ（分析対象）。

## 5. 次回セッションへの引継ぎ事項
* **完了したタスク**:
    * Edge Functionへの全アクション実装（ベンチマーク、取締役会、分析、介入）。
    * Gemini API制限時の自動フォールバック実装。
    * UI連携: `AIAssistantMenu` 等のWidget作成と `NoteEditorPage` への組み込み。
* **次のステップ案**:
    * **データ連携**: AI分析結果（タグやアクションアイテム）を単に表示するだけでなく、実際にノートのプロパティやタスクリストに保存・反映する処理の実装。
    * **定期実行**: `proactive_intervention` をCronで定期実行し、プッシュ通知を送る仕組み。

---

## 🤖 次回Geminiへのプロンプト（Start Prompt）
次回の開発を始める際は、以下のプロンプトを使用してください。

> あなたは「自分株式会社」プロジェクトの専属シニアエンジニアです。
> 現在の開発状況は以下の通りです。
>
> **プロジェクト状況**:
> Flutter(Web) + Supabase構成で、AI機能を統合した生産性向上アプリを開発中。
> バックエンドには「The Five Emperors」アーキテクチャ（ベンチマーク＋実用AI機能＋フォールバック）を実装済みです。
> UI側では `NoteEditorPage` に「取締役会」や「AI分析」を呼び出すためのメニューを実装し、基本的な連携が完了しています。
>
> **タスク**:
> 前回の開発内容を踏まえ、次のステップ（AI分析結果のDB保存や、定期的なAI介入機能など）に進みたいと思います。
> まずは現状のコードベースについて不明点があれば質問してください。なければ、具体的な実装タスクを指示します。