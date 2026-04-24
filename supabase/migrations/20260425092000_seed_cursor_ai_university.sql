-- Session PS#4-S40: AI大学 182→183社化 — Cursor AI コードエディタ
-- Michael Truell・Suat Kadireken ら元 MIT・OpenAI エンジニアが創業 (2022)。
-- VS Code fork の AI ファーストエディタ。Tab補完/Composer/Agent/codebase context を一体化。
-- $105M Series B at $2.5B (a16z / 2024-08) → $900M at $9.9B (2025)。4M+ 開発者。
-- Claude Sonnet 4.6 / GPT-4.1 / Gemini 2.0 Flash などマルチモデル対応。
-- Step 0: 9/9 (GitHub Copilot を上回る勢い / a16z最大投資先 / 40,000+ 企業採用)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'cursor',
  'overview',
  'Cursor — VS Code fork の AI ファーストエディタが開発者 400 万人を獲得',
  $md$
# Cursor — AI ネイティブコードエディタの王者

**Michael Truell** (CEO) ら元 MIT/OpenAI エンジニア 4 人が 2022 年創業。
VS Code の fork として出発し、「AI が最初から設計されたエディタ」を実現した。

GitHub Copilot が「VS Code の拡張機能」であるのに対し、Cursor は
**エディタ自体が AI と深く統合**されている点が最大の差別化。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **創業** | 2022 年 / Anysphere Inc. |
| **CEO** | Michael Truell |
| **本社** | San Francisco, CA |
| **調達** | $105M Series B at $2.5B (a16z・2024-08) → $900M at $9.9B (2025) |
| **ユーザー数** | 4M+ 開発者 / 40,000+ 企業 (2025) |

## 主要機能

### 1. Cursor Tab — 文脈対応型補完

単純な補完を超えた **多行・多ファイル補完**。
直前のコード変更を学習して「次に何をするべきか」を提案。
Git diff や関連ファイルを考慮した提案が特徴。

### 2. Cursor Composer (Ctrl+K / Ctrl+I) — マルチファイル編集

複数ファイルを横断する変更を一度に生成・適用。
「新機能を追加して」「バグを修正して」など自然言語で指示。

### 3. Cursor Agent — 自律型コーディング

ターミナル実行・ファイル作成・テスト実行まで自律的に行う Agent モード。
「このリポジトリに認証機能を追加して」など複雑なタスクを自動完遂。

### 4. @codebase — コードベース全体の文脈理解

`@codebase` でプロジェクト全体をインデックス化。
「この関数はどこで呼ばれてる？」「この設計の意図は？」に正確回答。

## 競合との比較

| 機能 | Cursor | GitHub Copilot | Windsurf | Claude Code |
| :--- | :--- | :--- | :--- | :--- |
| エディタ種別 | 独立エディタ (VS Code fork) | VS Code 拡張 | 独立エディタ (VS Code fork) | CLI |
| Agent モード | ✅ (強力) | ✅ (限定的) | ✅ | ✅ |
| マルチモデル | ✅ (Claude/GPT/Gemini) | GPT のみ | Claude 中心 | Claude のみ |
| codebase index | ✅ | △ | ✅ | ✅ |
| 料金 | $20/月 | $19/月 | $15/月 | Max Plan $100 |

## 調達・評価額の急成長

```
2022    創業 (Anysphere Inc.)
2023    シード調達 → 初期ユーザー獲得
2024-01 Series A $60M (a16z・Thrive)
2024-08 Series B $105M at $2.5B (a16z主導)
2025    $900M raise at $9.9B 評価額 (報道)
```

a16z の Marc Andreessen は Cursor を **「過去 10 年で最も重要な開発者ツール」** と評価。
$md$,
  'https://www.cursor.com/',
  '2026-04-24',
  1
),

(
  'cursor',
  'models',
  'Cursor のモデル選択 — Claude / GPT-4.1 / Gemini マルチモデル戦略',
  $md$
## Cursor のモデル戦略 (2026-04 時点)

Cursor は特定のモデルに依存しない **マルチモデルアーキテクチャ**。
ユーザーが用途に応じてモデルを切り替えられる。

### サポートモデル一覧

| モデル | 用途 | 速度 | 品質 |
| :--- | :--- | :--- | :--- |
| **Claude Sonnet 4.6** | コーディング全般・デフォルト推奨 | 速い | ⭐⭐⭐⭐⭐ |
| **Claude Opus 4.7** | 複雑なアーキテクチャ設計 | 遅い | ⭐⭐⭐⭐⭐ |
| **GPT-4.1** | 数学・論理推論 | 速い | ⭐⭐⭐⭐ |
| **o3** | 段階的推論が必要なデバッグ | 遅い | ⭐⭐⭐⭐⭐ |
| **Gemini 2.0 Flash** | 高速タスク・大量補完 | 超速 | ⭐⭐⭐⭐ |
| **cursor-fast** | Tab補完専用 (Cursor独自) | 超速 | ⭐⭐⭐ |

### cursor-fast — Cursor 独自の補完モデル

Cursor は Tab 補完用に **独自の軽量モデル** (`cursor-fast`) を開発。
大型モデルより 10-20 倍高速で、補完の待ち時間をほぼゼロに。

### Cursor Rules — モデル設定のカスタマイズ

`.cursorrules` ファイルでプロジェクト固有のルールを設定:

```
# .cursorrules 例
You are an expert Flutter/Dart developer.
Follow these conventions:
- Use const constructors when possible
- Prefer functional style with immutable data
- Add TODO comments for incomplete logic
```

### モデル切り替えの使い方

```
Ctrl+Shift+P → "Cursor: Change Model"
Chat 画面右下のモデル名をクリック → ドロップダウン選択
```
$md$,
  'https://www.cursor.com/pricing',
  '2026-04-24',
  2
),

(
  'cursor',
  'api',
  'Cursor 活用入門 — Tab補完・Composer・Agent の実践パターン',
  $md$
## Cursor の使い方 (2026-04 時点)

### インストール

```bash
# 公式サイトからダウンロード
# https://www.cursor.com/

# または Homebrew (Mac)
brew install --cask cursor
```

VS Code の設定・拡張機能・キーバインドを **ワンクリックでインポート** 可能。
既存の VS Code ユーザーは 5 分で移行完了。

### Tab 補完の活用

```dart
// Dart の例: コメントを書くと Cursor が実装を補完
// Supabase からユーザーのタスクを取得する関数

// ↑ ここで Tab を押すと完全な実装が生成される:
Future<List<Task>> fetchUserTasks(String userId) async {
  final response = await supabase
      .from('tasks')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return response.map((json) => Task.fromJson(json)).toList();
}
```

### Composer でマルチファイル編集

```
Ctrl+I → Composer を開く

例: "lib/services/ に新しい WeatherService クラスを作成して。
     OpenWeatherMap API を使い、現在地の天気を取得する。
     エラーハンドリングと retry ロジックを含めて。"

→ Cursor が複数ファイルを自動生成・編集
```

### @codebase でコンテキスト参照

```
Chat で:
@codebase この認証フローはどこで実装されている？
@supabase/functions ここの Edge Function の設計意図は？
@lib/pages/landing_page.dart この LP に新しい CTA セクションを追加して
```

### Agent モード (自律実行)

```
Ctrl+Shift+A → Agent モードを起動

例: "このアプリに Google ログインを追加して。
     Supabase Auth を使い、
     既存の認証フローと統合して。
     必要なパッケージを追加して、実装して、テストも書いて。"

→ Cursor が自律的にターミナル操作・ファイル作成・パッケージインストールを実行
```

### Cursor Rules (プロジェクト設定)

```
# .cursorrules を作成 (Git 管理推奨)
cat > .cursorrules << 'EOF'
あなたは Flutter/Dart + Supabase の専門家です。

コーディング規則:
- const コンストラクタを常に使用する
- dart format 準拠のコードを書く
- Edge Function は Deno + TypeScript で作成
- 日本語コメントを使用

プロジェクト構造:
- lib/pages/ にページコンポーネント
- lib/services/ にビジネスロジック
- supabase/functions/ に Edge Functions
EOF
```

### 料金プラン

| プラン | 価格 | 内容 |
| :--- | :--- | :--- |
| **Free** | $0/月 | 2,000 補完/月 / 50 低速リクエスト |
| **Pro** | $20/月 | 無制限補完 / 500 高速リクエスト / 10 o1 リクエスト |
| **Business** | $40/user/月 | Pro + 管理者機能 / SSO / プライバシーモード |

**Pro $20/月** が開発者の標準選択。GitHub Copilot ($19/月) とほぼ同価格で Agent 機能が強力。
$md$,
  'https://docs.cursor.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
