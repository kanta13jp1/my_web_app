-- PS#3 S70: AI大学 234→235社化 — Cursor 追加
-- Cursor: AIファーストコードエディタ / Anysphere / $400M Series B $9.9B / GPT-4+Claude+Gemini / .cursorrules

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cursor',
  'overview',
  'Cursor — AIファーストコードエディタ (Anysphere / $9.9B評価 / Tab補完+Composer / GitHub Copilot対抗)',
  $$## Cursor — AIファーストコードエディタ

**カテゴリ**: AI Code Editor / Developer Tools / AI-Assisted Development
**開発元**: Anysphere Inc. / 本社: San Francisco, CA
**設立**: 2022年 / 創業者: Michael Truell / Sualeh Asif / Arvid Lunnemark / Aman Sanger
**資金調達**: $400M Series B (2024年8月) / 企業評価 $9.9B / 投資家: Andreessen Horowitz / Thrive Capital / Benchmark
**MAU**: 100万人以上の開発者 (2025年時点)
**評価**: 9/9

### 概要
Cursor は **VS Code をフォークして「AIファースト」に作り直したコードエディタ**。単なる補完プラグインではなく、エディタ全体をAIコーディング体験に最適化している。2024年に急速普及し、GitHub Copilot の最大の対抗馬として浮上した。

特に **Cursor Tab** (Tab補完) と **Composer/Agent モード** (複数ファイル同時編集・タスク自律実行) が開発者に高く評価されており、「AIと一緒にコーディングする体験が最も自然」と評される。Claude Code / Windsurf / Aider と並び、2025年のAIコーディングツール4強の一角。

### 主な機能

**Cursor Tab (AI Tab補完)**
- キーストロークを予測して次のコード変更を提案
- 単行補完を超えた「複数行の変更ブロック」を予測
- 既存コードの文脈を理解した補完 (インポート追加・変数名補完込み)
- `Tab` で採用 / `Esc` でキャンセル

**Chat (コードベースと対話)**
- `Ctrl+L` でチャット開 → コードの質問・説明・リファクタ依頼
- `@ファイル名` でファイルを参照 / `@コード` でコード断片を参照
- `@Web` でリアルタイムWeb検索を組み込んだ回答
- `@Docs` でライブラリのドキュメントを取得して回答

**Composer / Agent (マルチファイル編集)**
- `Ctrl+I` でComposer起動 → 自然言語でタスクを指示
- 複数ファイルを横断した編集・作成・削除を自律実行
- Agent モード: ターミナルコマンド実行・エラー自動修正のループ
- Checkpointで変更を段階的にレビュー・承認

**.cursorrules (プロジェクト専用AI設定)**
```
// .cursorrules の例 (プロジェクトルートに配置)
You are a Flutter/Dart expert. Follow these rules:
- Use camelCase for variables, PascalCase for classes
- Always add null safety checks
- Use Supabase for all data operations
- Prefer const constructors where possible
- Never use print(), use debugPrint() instead
- All UI changes must follow docs/DESIGN.md color tokens
```

### GitHub Copilot との比較
| 機能 | Cursor | GitHub Copilot |
|------|--------|----------------|
| エディタ形態 | **独立エディタ** (VS Codeフォーク) | VS Code / JetBrains **プラグイン** |
| マルチファイル編集 | ✅ Composer/Agent | ✅ Workspace (Beta) |
| コードベース理解 | ✅ 深い (全ファイルインデックス) | △ (一部) |
| .cursorrules相当 | ✅ `.cursorrules` | ✅ `.github/copilot-instructions.md` |
| LLM選択 | ✅ GPT-4o/Claude/Gemini | ✅ (GPT-4o等) |
| 月額 (個人) | $20 Pro / $40 Business | $10 / $19 Business |
| VS Code互換 | ✅ 拡張機能ほぼ動作 | ✅ ネイティブ |

### 導入コスト
- **Hobby (Free)**: 2000補完/月 / 50スローリクエスト / Pro機能14日トライアル
- **Pro**: 月$20 / 無制限補完 / 500プレミアムリクエスト / 無制限スローリクエスト
- **Business**: 月$40/シート / SSO / 管理コンソール / 使用ポリシー設定
- **API利用**: Bring Your Own Key (BYOK) 対応 → 自社APIキーで無制限利用可

### 自分株式会社での活用可能性
- **Flutter開発加速**: `.cursorrules` に DESIGN.md / Supabase規約 / Dart規約を記述 → AI補完精度が劇的向上
- **EF (Deno) 作成**: Composer Agent に「新しいEdge Functionを作って」→ index.ts / CORS / 認証ガード自動生成
- **Claude Code との使い分け**: 設計・アーキテクチャ = Claude Code / 実装コーディング = Cursor Pro$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cursor',
  'api',
  'Cursor 設定・カスタマイズ — .cursorrules / CLAUDE.md統合 / Supabase+Flutter開発テンプレート',
  $$## Cursor 設定・カスタマイズ

### .cursorrules 設定例 (Flutter + Supabase プロジェクト)
```
# .cursorrules — 自分株式会社 Flutter/Supabase プロジェクト

## 技術スタック
- Flutter Web + Dart (null-safe)
- Supabase (PostgreSQL + Edge Functions / Deno)
- Firebase Hosting

## コーディング規約
- 変数/関数: camelCase
- クラス/Widget: PascalCase
- ファイル名: snake_case
- const constructors を可能な限り使用
- print() 禁止 → debugPrint() のみ
- setState() の過剰使用禁止 → Provider/Riverpod を使う

## Supabase 規約
- 認証: supabase.auth.currentUser (グローバル変数)
- Supabase.instance.client は import が必要なため非推奨
- RLS が有効な前提でクエリを書く
- anon キーで unauthorized 操作をしない

## UI/デザイン
- カラートークンは docs/DESIGN.md を参照
- ダークテーマ前提: bg=#111827, surface=#1F2937, primary=#F97316
- 文字: 日本語は letter-spacing: 0, line-height: 1.7+
- ボタン高さ: 44px以上 (タッチターゲット)

## 禁止事項
- ダミーデータの使用禁止 → 必ず Supabase リアルデータ
- ハードコードされた文字列禁止 → 定数化
- 未使用 import は削除 (flutter analyze でエラーになる)
```

### Composer Agent でのEF生成フロー
```
1. Composer を開く (Ctrl+I)
2. 指示を入力:
   "supabase/functions/get-ai-providers/index.ts を作成して。
    Deno Edge Function として:
    - GET /get-ai-providers → ai_university_content テーブルから全プロバイダー取得
    - CORS ヘッダー (https://my-web-app-b67f4.web.app を許可)
    - 認証: anon キーで読み取り OK
    - エラー時 500 で JSON エラー返却"

3. Cursor が生成したコードを確認
4. 「ターミナルで deno lint して」→ Agent が自動修正
5. Checkpoint で差分確認 → Accept
```

### VSCode 拡張との互換性
Cursor は VS Code フォークのため、ほぼすべての VS Code 拡張が動作:
```bash
# 既存 VS Code の拡張をそのままCursorに移行
# Cursor の設定 → Open VS Code Settings → 拡張のエクスポート

# 特に有用な拡張 (Cursor + Flutter 開発)
- Dart (dartcode.dart-code)         # Flutter/Dart 言語サポート
- Flutter (dart-code.flutter)       # ホットリロード / デバッグ
- Pubspec Assist (jeroen-meijer.pubspec-assist)  # pub.dev 検索
- Error Lens (usernamehw.errorlens) # インラインエラー表示
- GitLens (eamodio.gitlens)         # Git 履歴の可視化
```

### BYOK (Bring Your Own Key) 設定
```json
// Cursor Settings → Models → Add API Key
{
  "anthropic_api_key": "sk-ant-...",
  "openai_api_key": "sk-...",
  "google_api_key": "AIza..."
}
// → 自社 API キーを使うため課金上限を自分でコントロール可能
// → Pro プランの 500リクエスト上限を超えた場合の代替として有用
```

### Claude Code との役割分担 (推奨)
```
Claude Code (claude-sonnet-4-6):
  ✅ アーキテクチャ設計
  ✅ cross-instance-pr 作成
  ✅ memory/ 管理・consolidation
  ✅ 複雑な要件定義・仕様検討
  ✅ セキュリティ・ルール遵守チェック

Cursor Pro (claude-3-5-sonnet via BYOK):
  ✅ 実装コーディング (新ファイル作成・バグ修正)
  ✅ リファクタリング (複数ファイル同時)
  ✅ EF (Deno) テンプレート生成
  ✅ テストコード作成
  ✅ SQL migration ドラフト

→ Claude Code のトークン消費を月 50% 削減 (CLAUDE.md Phase 3 KPI)
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cursor',
  'models',
  'Cursor 技術詳細 — Shadow Workspace / Speculative Edits / AIコードエディタ競合比較 2025',
  $$## Cursor 技術詳細

### Shadow Workspace: Cursor独自の技術

Cursor の最大の技術的差別化要素は **「Shadow Workspace」** と呼ばれるアーキテクチャ。

```
[従来のAI補完 (GitHub Copilot等)]
ユーザーがコード入力
  → カーソル付近のコード (数百行) を LLM に送信
  → LLM が次のトークンを予測して補完提案
  → ユーザーが採用/却下

問題点:
  - コードベース全体の文脈を把握できない
  - import文・型定義・関数シグネチャが補完に反映されない
  - 大規模プロジェクトで補完精度が落ちる

[Cursor: Shadow Workspace + インデックス]
セッション開始時:
  ① プロジェクト全ファイルをバックグラウンドでインデックス化
     → 型情報 / 関数シグネチャ / import グラフを構築
  ② Shadow Workspace: 不可視の仮想ワークスペース
     → AIが「もしこのコードを変更したら?」を事前にシミュレーション

補完時:
  ① ユーザーのカーソル位置 + インデックス情報を LLM に送信
  ② LLM が「プロジェクト全体の文脈」で補完を生成
  ③ Shadow Workspaceで変更をシミュレーション → 構文エラーなし確認
  ④ 問題なければ補完を提示 (エラーがある提案を事前除外)

結果: 補完が「プロジェクト固有の変数名・型・パターン」に合致する精度が高い
```

### Speculative Edits (Tab補完の技術)

```python
# Cursor Tab の動作原理 (疑似コード)

class SpeculativeEditor:
    def predict_next_edit(self, cursor_position, recent_edits):
        """
        ユーザーの編集パターンを学習して次の変更を予測

        入力:
          - cursor_position: 現在のカーソル位置
          - recent_edits: 直近の編集履歴 (過去 N 変更)
          - file_content: 現在のファイル内容
          - project_index: プロジェクト全体インデックス

        出力: predicted_edit (次の変更ブロック)
        """
        # 1. 最近の編集パターンを解析
        #    例: "変数名を camelCase に変更" → 同パターンの変数を予測
        pattern = analyze_edit_pattern(recent_edits)

        # 2. LLM で次の変更を予測 (高速小型モデル使用)
        predicted = fast_llm.predict(
            context=file_content[max(0, cursor_position-500):cursor_position+200],
            pattern=pattern,
            index=project_index
        )

        # 3. Shadow Workspace で変更をシミュレーション
        if shadow_workspace.validate(predicted):
            return predicted
        return None

# Tab を押すと Cursor がこの予測を採用
# Esc を押すと却下 → 次の予測候補を生成
```

### AIコードエディタ競合比較 2025

| 項目 | **Cursor** | **GitHub Copilot** | **Windsurf** | **Claude Code** |
|------|-----------|------------------|-------------|----------------|
| 形態 | 独立エディタ | IDEプラグイン | 独立エディタ | CLI/エージェント |
| ベースLLM | GPT-4o/Claude/Gemini | GPT-4o | GPT-4o/Claude | Claude Sonnet 4.6 |
| エージェントモード | ✅ Composer Agent | ✅ Agent (限定) | ✅ Cascade | ✅ フル |
| コードベース理解 | ✅ 全ファイルインデックス | △ | ✅ | ✅ |
| ターミナル統合 | ✅ | ✅ | ✅ | ✅ (主体) |
| .rules ファイル | ✅ .cursorrules | ✅ copilot-instructions | ✅ .windsurfrules | ✅ CLAUDE.md |
| 月額最安 | $20 Pro | $10 | $15 | $20 Pro |
| 日本語UI | ❌ (英語のみ) | △ | ❌ | ✅ |
| 自分株式会社推奨 | **実装担当** | **行補完担当** | 不要 | **設計・統合担当** |

### 自分株式会社での位置付け
CLAUDE.md の AI 振り分けマトリクス上:
- **行レベル補完**: GitHub Copilot
- **5分以内の修正**: Copilot Inline Chat
- **Flutter widget 新規**: Gemini / Copilot
- **EF (Deno) 新 action**: Codex / Copilot
- **設計・戦略・ルール遵守**: Claude Code 独占

→ Cursor Pro は **「500行超リファクタリング」「複数ファイル同時修正」** に最適
→ Gemini Code Assist の代替候補として検討価値あり (月$20 vs Gemini $19/mo)$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 234→235社化: Cursor 追加',
  'PS#3 S70。Cursor (Anysphere/VS Codeフォーク/AIファーストエディタ/Tab補完+Composer Agent/Shadow Workspace/Speculative Edits/$9.9B評価/$400M/GitHub Copilot対抗/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
