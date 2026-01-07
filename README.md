# AI開発コンテキスト設計書 (AI_DEV_HANDOVER)

## 1. プロジェクト概要
* **プロジェクト名**: 自分株式会社 (Me Inc.)
* **コンセプト**: ユーザーはCEO。実務は全てAI（CXO）が担当する経営シミュレーション型生産性アプリ。
* **技術スタック**: Flutter (Web), Supabase (Auth, DB, Edge Functions), AI (Gemini/OpenAI/Anthropic).

## 2. 組織構造 (AI Agents) & 機能マップ
ユーザー（CEO）を支えるAI役員たちの構造図については、以下のファイルを参照してください。

- **[組織図機能マップ (Mermaid)](docs/organization_chart.md)**

## 3. コアアーキテクチャ: "The Five Emperors"
`supabase/functions/ai-assistant/index.ts` に実装された統合AI機能。
* **Board Meeting**: `hold_board_meeting` で各CXO（Steve, Linus, Gary, Warren）が議論を行う。
* **Analysis**: `analyze_note_text` でメモ（案件）を分析。
* **Benchmark**: 6段階のVisionテストでモデル性能を監視。

## 4. UI/UXの変更点
* **HomePage**: 従来のリスト形式から、各Office（役職）へのアクセスを行う「経営コックピット」へ刷新。
* **DanshariPage**: CSOが古いメモを提示し、CEOが即座に「維持/廃棄」を決定するTinderライクなUIへ復旧。
* **NoteEditorPage**: AIアシスタントメニューを実装し、取締役会や分析機能を呼び出し可能に。

## 5. 次回セッションへの引継ぎ
* **完了**:
    * 経営コックピット(HomePage)の実装。
    * 断捨離クエストの復旧。
    * AIアシスタントメニュー(`NoteEditorPage`)の実装。
    * 組織図のMermaid化と設計への反映。
* **次のタスク**:
    * **緊急役員会議の実装**: `NoteEditorPage` ではなく、チャットUIで複数のAI役員と対話できる専用画面の作成。
    * **未実装Officeの機能追加**: CMO（分析画面）、CFO（コスト入力）などの中身の実装。
    * **リアル断捨離クエスト**: 物理的なモノの写真を撮ってAIに判定させる機能の実装。

---

##  次回Geminiへのプロンプト（Start Prompt）
次回の開発を始める際は、以下のプロンプトを使用してください。

> あなたは「自分株式会社」プロジェクトの専属シニアエンジニアです。
> 現在の開発状況は以下の通りです。
>
> **プロジェクト状況**:
> Flutter(Web) + Supabase構成で、ユーザーをCEOとした経営シミュレーション型生産性アプリを開発中。
> 直近のセッションで、組織構造（CEO, CSO, CKOなど）に基づいた「経営コックピット」へのUI刷新を行いました。
> プロジェクトルートの `README.md` および `organization_chart.md` に最新の設計情報が記載されています。
>
> **タスク**:
> 前回の開発内容を踏まえ、次のステップ（緊急役員会議の実装や、未実装オフィスの開発）に進みたいと思います。
> まずは現状のコードベースについて不明点があれば質問してください。なければ、具体的な実装タスクを指示します。
