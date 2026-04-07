# Design Tooling Setup

このプロジェクトでは、デザイン作業を以下の 4 点セットで回します。

1. `Figma MCP`
2. `AIDesigner MCP`
3. `.claude/agents/design-skills.md`
4. `docs/DESIGN.md`

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

1. Figma MCP で元デザインを読む
2. `docs/DESIGN.md` と `lib/services/theme_service.dart` で制約を確認する
3. AIDesigner MCP で 2〜3 案出す
4. `.claude/agents/design-skills.md` のルールで Flutter 実装に落とす
5. `/design-review` 相当でズレを確認する

### 新規画面を作る時

1. `docs/DESIGN.md` でトーンと禁止事項を確認する
2. AIDesigner MCP で desktop / mobile の両案を出す
3. 必要なら Figma MCP で既存近接画面の構造を読む
4. `/design-component` 相当で Flutter 実装に落とす

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
