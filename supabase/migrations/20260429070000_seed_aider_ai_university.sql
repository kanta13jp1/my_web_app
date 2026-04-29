-- PS#3 S118: AI大学 331→332社化 — Aider (CLI コーディングAI / git統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aider', 'overview',
  'Aider — CLI コーディングAI・git統合・Claude+GPT・ファイル自動編集 (GitHub 24k+ / 9/9)',
  $$## Aider とは

**Aider** は **ターミナルで動く AI ペアプログラマー**。Claude / GPT-4o / Gemini と会話しながら、**自動でコードを編集して git commit するまで**を一貫して行う。「**Claude Code の軽量 CLI 版**」として、既存プロジェクトへのシームレスな統合が強み。

GitHub **24,000+ スター** (2024年急成長)。コードベース全体をコンテキストに入れて編集するため、大規模プロジェクトの横断修正が得意。**SWE-bench スコアで上位** (GPT-4o 単体を超える実装精度)。無料で OSS として利用可能。

## Aider のアーキテクチャ

```
Aider のコンポーネント:

  CLI インターフェース:
    ・ターミナルで対話型チャット
    ・/add でファイルを追加
    ・/drop でファイルを除外
    ・/diff で変更確認
    ・/undo で直前の変更を元に戻す

  LLM 統合:
    ・Claude Sonnet 4.6 / Opus 4.7 (推奨)
    ・GPT-4o / o1
    ・Gemini 1.5 Pro
    ・Ollama (ローカル)
    ・任意の OpenAI 互換 API

  git 統合:
    ・変更を自動で git add + git commit
    ・コミットメッセージも AI が生成
    ・git blame でコンテキスト補完
    ・変更履歴をコンテキストとして活用

  マップ機能 (repo-map):
    ・プロジェクト全体の構造をトークン効率よくコンテキスト化
    ・Tree-sitter で AST 解析 → 重要な定義・参照を抽出
    ・大規模リポジトリでも効率的にコンテキスト管理
```

## 主要機能

```
コーディング支援:
  ・複数ファイルにまたがる変更を一括実行
  ・テスト失敗 → 自動修正ループ
  ・リファクタリング
  ・バグ修正
  ・ドキュメント生成

git 統合:
  ・変更ごとに自動コミット
  ・コミットメッセージの AI 生成
  ・/undo で気に入らない変更を即座に取消

コンテキスト管理:
  ・repo-map: プロジェクト構造の効率的コンテキスト化
  ・/add でファイルを動的に追加
  ・大規模コードベースにも対応

精度:
  ・SWE-bench で top tier のスコア
  ・Claude 3.5 Sonnet + Aider の組み合わせが最高精度
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 EF 改善** | `aider --model claude-sonnet-4-6` で EF の confidence 計算を改善 | Claude Code 不要でターミナルだけで完結 |
| **Flutter バグ修正** | `aider lib/pages/horse_racing_page.dart` で特定ページを修正 | 対話的にバグ原因を探りながら修正 |
| **一括リファクタリング** | `/add lib/` で複数ファイルを追加して一括変換 | 横断修正を git commit 単位で管理 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aider', 'api',
  'Aider 実践 — インストール/Claude設定/基本操作/repo-map/git統合/競馬開発への応用',
  $$## インストール

```bash
# pip でインストール (推奨)
pip install aider-chat

# または uv (高速)
uv tool install aider-chat

# バージョン確認
aider --version
```

## 起動 (Claude 統合)

```bash
# Anthropic API キー設定
export ANTHROPIC_API_KEY=sk-ant-...

# Claude Sonnet 4.6 で起動 (推奨)
aider --model claude-sonnet-4-6

# 特定ファイルを最初から追加して起動
aider lib/pages/horse_racing_page.dart

# 複数ファイルを指定
aider lib/pages/horse_racing_page.dart lib/providers/racing_provider.dart

# ディレクトリ全体 (repo-map で効率化)
aider

# GPT-4o で起動
aider --model gpt-4o

# Ollama (ローカル) で起動
aider --model ollama/llama3.2
```

## 基本的な使い方

```text
起動後のチャット例:

aider> /add lib/pages/horse_racing_page.dart
  → ファイルをコンテキストに追加

aider> このページの競馬予想の confidence 計算を改善して。
      jockey_win_rate >= 20% なら +0.03 ボーナスを追加する。
  → Aider がコードを修正 → 自動でgit commit

aider> /diff
  → 変更内容を確認

aider> /undo
  → 気に入らければ取消

aider> /add supabase/functions/ai-prediction/index.ts
  → Edge Function も追加

aider> このEFに馬体重のバリデーションを追加して
  → EFを修正 → コミット

aider> /drop lib/pages/horse_racing_page.dart
  → 不要なファイルを除外
```

## .aider.conf.yml (プロジェクト設定)

```yaml
# .aider.conf.yml (プロジェクトルート)
model: claude-sonnet-4-6
auto-commits: true
dirty-commits: false
git: true
show-diff: true
map-tokens: 2048

# 除外ファイル (.aiderignore)
# node_modules/
# .dart_tool/
# build/
```

## .aiderignore の設定

```text
# .aiderignore
node_modules/
.dart_tool/
build/
.flutter-plugins
.flutter-plugins-dependencies
*.g.dart
*.freezed.dart
supabase/.branches/
supabase/.temp/
```

## repo-map の仕組み

```text
repo-map とは:
  - プロジェクト全体の「地図」をトークン効率よく生成
  - Tree-sitter でコードを解析
  - クラス定義・関数シグネチャ・重要な参照を抽出
  - LLM がファイルを読まなくても構造を理解できる

効果:
  - 大規模プロジェクトでも全体を把握しながら修正
  - 関連するファイルを AI が自律的に /add
  - トークン使用量を最適化

チューニング:
  aider --map-tokens 2048  # デフォルト: 1024
  aider --map-tokens 4096  # 大規模プロジェクト向け
```

## git 統合の活用

```bash
# 変更ごとに自動コミット (デフォルト: ON)
aider --auto-commits

# コミットなしで実行 (変更確認してから手動コミット)
aider --no-auto-commits

# コミットメッセージのプレフィックス設定
aider --attribute-committer

# 典型的なワークフロー:
git checkout -b feature/confidence-improvement
aider  # 対話的に改善
# Aider が自動でコミット
git push origin feature/confidence-improvement
# PR を作成
```

## Claude Code との使い分け

```text
Aider を使う場面:
  ✅ ターミナルだけで完結したい
  ✅ 既存プロジェクトのファイル修正
  ✅ git コミットまで自動化したい
  ✅ Claude Code quota 超過時のフォールバック
  ✅ CI/CD パイプラインから AI 修正を呼びたい

Claude Code を使う場面:
  ✅ 設計・アーキテクチャ判断が必要
  ✅ cross-instance PR の作成
  ✅ memory/ の管理・統合
  ✅ 複雑な判断が必要なタスク

組み合わせ例:
  1. Claude Code でアーキテクチャを決定
  2. .cursorrules/.aider.conf.yml に方針を記録
  3. Aider で実装を一括実行
  4. Claude Code でレビュー
```

## CI/CD 統合 (非対話モード)

```bash
# --yes フラグで全て承認 (CI/CD 向け)
aider --yes --message "lint エラーを全て修正して" lib/

# GitHub Actions での利用
- name: AI Fix
  run: |
    pip install aider-chat
    aider --yes \
      --model claude-sonnet-4-6 \
      --message "flutter analyze のエラーを修正して" \
      lib/
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 331→332社化: Aider 追加',
  'PS#3 S118。Aider (CLI コーディングAI/git統合/Claude+GPT統合/repo-map/SWE-bench top tier/ファイル自動編集+自動コミット/Claude Code フォールバック/GitHub 24k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
