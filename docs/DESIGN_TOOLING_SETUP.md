# Design Tooling Setup

このプロジェクトでは、デザイン作業を以下の 5 点セットで回します。

1. `docs/DESIGN.md` と `lib/services/theme_service.dart`
2. `Figma MCP`
3. `AIDesigner MCP`
4. Anthropic Designプラグインと `docs/DESIGN_ACCESSIBILITY_AUDIT.md`
5. `.claude/agents/design-skills.md`

モデル単体で UI を生成させるのではなく、既存デザインの読解、バリエーション生成、最終判断基準を分離して使う前提です。

## このリポジトリの構成

- `.mcp.json`
  - `figma`: `https://mcp.figma.com/mcp`
  - `aidesigner`: `https://api.aidesigner.ai/api/v1/mcp`
- `.claude/agents/design-skills.md`
  - Claude Code 用のデザイン判断ルール
- `.claude/commands/design-component.md`
  - 新規 UI を作る時の入口
- `.claude/commands/design-review.md`
  - UI レビューの入口
- `docs/DESIGN.md`
  - 最終的なデザイン基準

## 初回セットアップ

### 1. MCP を認証する

- `figma`
  - Claude Code / Codex 側で MCP 接続時に認証します
  - 既定では Figma の hosted MCP (`https://mcp.figma.com/mcp`) を使います
  - Figma Desktop App のローカル MCP を使いたい場合は `http://127.0.0.1:3845/mcp` へ差し替えて構いません
  - 既存デザインのレイアウト、色、余白、命名を読む用途で使います
- `aidesigner`
  - 初回接続時にブラウザで OAuth 認証します
  - UI の叩き台、比較案、改善案を作る用途で使います

### 2. AIDesigner の確認

必要なら以下を実行して状態確認します。

```bash
npx -y @aidesigner/agent-skills init
npx -y @aidesigner/agent-skills doctor
```

生成物は `.aidesigner/` 配下に置く前提で、成果物本体は Git 管理しない設定にしています。

## 推奨ワークフロー

### 既存画面を改善する時

1. `docs/DESIGN.md` と `lib/services/theme_service.dart` で制約を確認する
2. Figma MCP で元デザインを読む
3. AIDesigner MCP で 2〜3 案出す
4. `.claude/agents/design-skills.md` のルールで Flutter 実装に落とす
5. `/design-review` でDesignプラグイン監査と実装差分を確認する

### 新規画面を作る時

1. `docs/DESIGN.md` でトーンと禁止事項を確認する
2. Figma MCP で既存近接画面の構造を読む（存在する場合）
3. AIDesigner MCP で desktop / mobile の両案を出す
4. `/design-component` 相当で Flutter 実装に落とす
5. `/design-review` でDesignプラグイン監査と実装差分を確認する

## 役割分担

### Figma MCP

- 既存 UI の正解データを読む
- レイアウト、余白、タイポ、コンポーネント構造を拾う
- 「今あるものに合わせる」時に最優先

### AIDesigner MCP

- 新規案や改善案の初速を出す
- 比較案を短時間で増やす
- repo-aware な UI 叩き台を作る

### Design Skills

- Claude Code にこのプロジェクトの UI 判断ルールを渡す
- `ThemeService`、`docs/DESIGN.md`、既存 Flutter 実装に沿わせる

### docs/DESIGN.md

- 最終的な判断基準
- 色、タイポ、余白、コンポーネントの禁止事項を固定する

## 実運用メモ

- Figma MCP は既存デザイン準拠の精度を上げるための土台です
- AIDesigner MCP は「0 から作る」「比較案を出す」時に強いです
- `docs/DESIGN.md` に反する提案は採用しません
- 画面を実装する前に、desktop と mobile の両方を前提に案出しします
- Flutter 実装では `Theme.of(context)` と `ThemeService` を優先します

## 参考プロンプト

### Figma を読んでから改善案を作る

```text
Figma MCP でこの画面の構造と余白を読んでください。
その上で docs/DESIGN.md に合わせて、AIDesigner MCP で改善案を 2 案作ってください。
最後に Flutter Web の widget 構成に落としてください。
```

### AIDesigner から新規画面を起こす

```text
docs/DESIGN.md と lib/services/theme_service.dart を前提に、
この機能の desktop / mobile UI を AIDesigner MCP で提案してください。
既存画面との整合も説明し、その後 Flutter 実装案まで出してください。
```

---

## Design プラグインによるアクセシビリティ・UX監査

新規または大幅改修したUIは、実装・ブラウザQAに加えてAnthropic公式の
DesignプラグインでWCAG 2.1 AAのデザイン監査を行う。チェックアウト、
決済、認証、フォームのエラー状態はマイクロコピーもレビューし、修正後に
再監査する。

詳細な入力状態、プロンプト、pass定義、決定論的な補完検証、PR証跡形式は
`docs/DESIGN_ACCESSIBILITY_AUDIT.md` を正本とする。PRの監査セクションは
`scripts/check_design_accessibility_audit.py` が検証する。Figma MCPと
AIDesigner MCPは設計探索・参照用であり、Designプラグインの監査証跡を
代替しない。

---

## Claude Design 取り込みフロー (Rule 21 統合)

Claude Design SaaS (Anthropic Labs) で生成した handoff bundle を Flutter コードに変換するワークフロー。

### ステップ

1. **Claude Design SaaS で bundle 出力** (Pro/Max/Team/Enterprise プラン必須)
   - UI をデザインして「Export as JSON」または handoff spec を生成

2. **開発者インポートページで取り込み** (`/dev/claude-design-importer`)
   - ブラウザで `/dev/claude-design-importer` を開く (admin ログイン必須)
   - bundle JSON をテキストフィールドに貼り付けて「Parse」
   - 「Diff vs DESIGN.md」でトークン差分を確認
   - 「Generate Flutter widgets」でコード生成 → クリップボードにコピー

3. **生成コードを配置・調整**
   - 生成物は `lib/widgets/generated/claude_design/` に保存する命名規則
   - 生成コードは ~70% 精度: `onPressed`、状態管理、API 連携は手動補完
   - `docs/DESIGN.md` トークン (orange=0xFFFF6B35 / indigo=0xFF6366F1 等) と照合して修正

4. **flutter analyze 0 エラーを確認してコミット**

### 実装ファイル

| ファイル | 役割 |
|---|---|
| `lib/dev/claude_design/handoff_bundle.dart` | ClaudeDesignHandoff 型定義 (fromJson/toJson) |
| `lib/dev/claude_design/token_diff.dart` | DESIGN.md トークンとの差分計算 |
| `lib/dev/claude_design/flutter_codegen.dart` | HTML snippet → Flutter widget コード生成 |
| `lib/dev/claude_design/importer_page.dart` | 開発者向け UI (`/dev/claude-design-importer`) |
| `test/dev/claude_design/` | unit tests 28件 (all passing) |

### 制約

- `/dev/claude-design-importer` は admin ユーザー専用 (kanta13jp1)
- 生成コードは review 必須 — production に直接使用しない
- `docs/DESIGN.md` 更新は自動 merge しない (ユーザー確認必須)
