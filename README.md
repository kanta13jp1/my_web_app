# AI開発コンテキスト設計書 (AI_DEV_HANDOVER)

## 1. プロジェクト概要

* **プロジェクト名**: 自分株式会社 (Me Inc.)
* **コンセプト**: ユーザーはCEO。実務は全てAI（CXO）が担当する経営シミュレーション型生産性アプリ。
* **技術スタック**: Flutter (Web), Supabase (Auth, DB, Edge Functions), AI (Gemini/OpenAI/Anthropic).
* **AI tool update gate (2026-05-07 #1706)**: Claude/Codex/Gemini/Copilot changes must be verified against official sources, then routed through the two-instance flow in `docs/AI_FALLBACK_RUNBOOK.md`.

## ローカル開発環境セットアップ（コマンド実行ベース / #2724）

新規参画者・ローカル検証環境向けに、曖昧な手動設定を排し以下のコマンド順で
Flutter Web + Supabase CLI ローカル環境を構築・起動できます（CI 固定バージョン `3.38.10` 準拠）。
詳細なクラウド優先ルールは [docs/CLOUD_FIRST_DEVELOPMENT_WORKFLOW.md](docs/CLOUD_FIRST_DEVELOPMENT_WORKFLOW.md) を参照してください。

### 1. Flutter SDK バージョン統一（`.fvm/fvm_config.json`）

リポジトリ直下の [`.fvm/fvm_config.json`](.fvm/fvm_config.json) に Flutter SDK バージョン (`3.38.10`) を固定しています。

```bash
fvm install
fvm use
flutter --version
```

> FVM を使用しない環境でも `flutter --version` が `3.38.x` 系であることを確認し、設定検証を実行してください。

### 2. ローカル環境変数テンプレート検証と `.env.development` 自動生成

非機密のループバック標準設定は [`config/local_supabase_env_template.json`](config/local_supabase_env_template.json) に定義され、全変数の雛形は [`.env.example`](.env.example) に記載されています。

```bash
python scripts/setup_local_dev.py --check
python scripts/setup_local_dev.py --write-env
```

Windows PowerShell で `.env.example` をベースにする場合もコマンドで完結します:

```powershell
Copy-Item .env.example .env.development
python scripts/setup_local_dev.py --check
```

### 3. Supabase CLI ローカル起動・DB 反映・`.env.development` 同期

[`supabase/config.toml`](supabase/config.toml) のポート定義（API `54321` / DB `54322` / Studio `54323` / Inbucket `54324`）に合わせて起動します。

```bash
# Linux / macOS / WSL2 一括実行（資格情報を引数へ出さず stdin 経由で同期）
./scripts/setup_local_dev.sh --start-supabase --write-env --force

# または個別コマンドで実行
supabase start
supabase db reset
supabase status -o env | python scripts/setup_local_dev.py --write-env --force --status-stdin
```

### 4. Flutter Web 起動・オンボーディング検証

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=.env.development
python -m unittest discover -s test/scripts -p "test_local_dev_onboarding.py"
```

## Windows 開発環境セットアップ

新規 Windows 11 環境では、初期セットアップとプロキシ解除手順を
[docs/setup/windows-dev-setup.md](docs/setup/windows-dev-setup.md) にまとめています。
一括インストールは以下を使用します。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1
```

VS Code 統合ターミナルが起動しない、または終了コードだけで落ちる場合は
[docs/VSCODE_TERMINAL_TROUBLESHOOTING.md](docs/VSCODE_TERMINAL_TROUBLESHOOTING.md)
を参照してください。

### Git hooks (推奨 / コミット前の静的監査)

クローン後、ローカル git hooks を有効化すると、コミット前に
`scripts/check_duplicate_dispose.py`(二重 dispose / 二重 await / 二重 setState の
検知)が自動実行されます。CI と同じゲートを手元で前倒しでき、手戻りを減らせます。

```bash
git config core.hooksPath .githooks
```

詳細は [.githooks/README.md](.githooks/README.md) を参照。CI でも同じ監査が走るため
未設定でも検出はされますが、ローカル有効化を推奨します(CI で hook の健全性も検証)。

## 2. 組織構造 (AI Agents) & 機能マップ

ユーザー（CEO）を支えるAI役員たちの構造図については、以下のファイルを参照してください。

* **[詳細設計書](DETAILED_DESIGN.md)**
* **[プロジェクトファイル一覧](project_tree.txt)**
* **[テスト仕様書カバレッジ](TEST_COVERAGE.md)**

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
    * 組織図のMermaid化（ルートディレクトリへ配置）。
    * 緊急役員会議(`EmergencyMeetingPage`)の実装とDB連携。
* **次のタスク**:
    * **未実装Officeの機能追加**: CMO（分析画面）、CFO（コスト入力）などの中身の実装。
    ~~* **リアル断捨離クエスト**: 物理的なモノの写真を撮ってAIに判定させる機能の実装。~~ (完了)

## 6. 変更履歴 (Change Log)

**運用ルール**:
1. 軽微なバグ修正やリファクタリングを含め、すべての変更内容を本セクションに記録すること。
2. **重要**: ソースコードを修正した後は、必ず `dart format .` コマンドを実行してフォーマット修正を行うこと。

* **2026-01-07**:
    * **Fix**: `lib/services/theme_service.dart` のビルドエラー修正。不足していた `isDarkMode` ゲッターを追加。
    * **Feature**: 緊急役員会議 (Emergency Board Meeting) の実装。
        * DB: `board_meetings`, `board_messages` テーブル追加。
        * UI: `EmergencyMeetingPage` 追加。AI役員によるチャット形式の議論とDB保存。
    * **Fix**: `lib/pages/home_page.dart` のCEOカード遷移先を `EmergencyMeetingPage` に接続。

* **2026-01-08**:
    * **Feature**: リアル断捨離クエスト (Real World Danshari) の実装。
        * Backend: analyze_danshari_item アクションをEdge Functionに追加。
        * UI: RealWorldDanshariPage を実装。カメラ撮影とAI判定フローを構築。
    * **Feature**: メモ一覧機能 (Note List) の実装。
        * UI: NoteListPage 追加。CKOオフィスからアクセス可能に。
        * Backend: Supabase `notes` テーブルからのデータ取得とリスト表示。

    * **Refactor**: GamificationServiceの再設計とビルドエラーの完全修正。
        * GamificationService: 名前付き引数と位置引数の不整合を修正し、インターフェースを統一。
        * StatsPage, ImportService 等の呼び出し元コードを修正。
        * Achievement モデルの定義を拡張。

* **2026-01-09**:
    * **Doc**: 詳細設計書 (DETAILED_DESIGN.md) を策定し、10個目の管理インプットとして追加。
    * **Maint**: 次回セッションへの引き継ぎ準備として、全管理ファイル (LINT_REPORT, BUILD_LOG 等) を最新化。
    * **Feature**: CHO (最高健康責任者) 機能の実装。
        * UI: ChoOfficePage および HealthPage を追加。
        * Logic: 健康ログを
otes テーブルの特定タイトル形式([Health])で管理する簡易実装。
    * **Feature**: CMO (最高マーケティング責任者) 機能の実装。
        * UI: CmoOfficePage を追加。ユーザーのエンゲージメント（継続日数）やLTV（ポイント）を可視化。
    * **Update**: 緊急役員会議の分析ロジックを強化。CHO（健康）やCMO（継続率）のデータを実データとしてAIに提供するように変更。
    * **Fix**: ビルドエラーの修正 (EmergencyMeetingPage, CmoOfficePage)。
        * プロンプトテキストの文字列リテラル化漏れによる構文エラーを修正。
        * 文字列補間 ($) のエスケープ処理を修正。
    * **Fix**: 重大なビルドエラー (Illegal character) の修正。
        * EmergencyMeetingPage: 文字列リテラルのエスケープ処理を修正し、構文エラーを解消。
        * EmergencyMeetingPage: AIレスポンスの型チェック (Map vs List) を強化し、実行時エラー (TypeError) を回避。
        * CmoOfficePage: 文字列補間の構文修正。
    * **Fix**: 緊急ビルド修復。EmergencyMeetingPage の日本語文字列リテラル構文エラーを解消。
    * **Feature**: CHRO (最高人事責任者) 機能の実装。
        * UI: ChroOfficePage 追加。福利厚生(Rewards)と人事評価(Stats)へのアクセスを集約。
    * **Fix**: 重大なビルドエラー (Illegal character) の修正。
        * EmergencyMeetingPage: 文字列リテラルのエスケープ処理を修正し、構文エラーを解消。
        * EmergencyMeetingPage: AIレスポンスの型チェック (Map vs List) を強化し、実行時エラー (TypeError) を回避。
---

## 7. 標準開発コマンド & 参照ドキュメント (Standard Commands & References)

曖昧な手動判断を避け、検証・参照は次のコマンドと正本ドキュメントから開始します。

```bash
git config core.hooksPath .githooks
python scripts/setup_local_dev.py --check
python scripts/setup_local_dev.py --self-test
python -m unittest discover -s test/scripts -p "test_local_dev_onboarding.py"
```

1. **README.md** (本書: コマンドベースの開発環境構築、プロジェクト概要、変更履歴)
2. **project_tree.txt** (プロジェクト構成図: ファイル一覧)
3. **TEST_COVERAGE.md** (テスト仕様書: 機能検証状況)
4. **pubspec.yaml** (パッケージ依存関係定義)
5. **USER_MANUAL.md** (ユーザーマニュアル: 操作手順と機能仕様)
6. **DETAILED_DESIGN.md** (詳細設計書: アーキテクチャと内部ロジック)
