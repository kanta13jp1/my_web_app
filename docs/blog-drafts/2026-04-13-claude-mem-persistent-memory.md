---
title: "Claude Codeに永続メモリを追加する「claude-mem」を実際に導入してみた — 自作hook版との比較"
emoji: "🧠"
type: "tech"
topics: ["ClaudeCode", "AI", "開発効率化", "claude-mem", "LLM"]
published: true
---

## はじめに

Claude Codeを日常的に使っていて、こんな経験はないだろうか。

「昨日の続きをやって」と言ったのに、まったく覚えていない。
毎回プロジェクトの構成を説明し直す。前回のセッションで学んだ教訓がリセットされる。

これを解決するツール **claude-mem** が公開48時間で4.6万スターを突破した。実際に導入してみたので、自作の軽量版hookとの比較も含めてレポートする。

## claude-mem とは

GitHub: https://github.com/thedotmack/claude-mem

Claude Codeに「永続メモリ」を追加するプラグイン。セッション間で文脈を引き継ぎ、過去の作業内容・コーディングスタイル・プロジェクト知識を蓄積する。

### 技術アーキテクチャ

- **5つのLifecycle Hooks**: SessionStart / UserPromptSubmit / PostToolUse / Stop / SessionEnd
- **SQLite + Chroma**: ハイブリッド検索（キーワード + ベクター類似度）
- **Bun HTTP Worker**: localhost:37777 で常駐サービス
- **MCP Tools**: search / timeline / get_observations の3層検索
- **Web UI**: ブラウザで蓄積状況を可視化

### インストール

```bash
npx claude-mem install
npx claude-mem start  # Worker起動（Bun必須）
```

## 導入前に自作した軽量版

実はclaude-memを知る前に、同じ課題を解決する軽量hookを自作していた。

### 自作版の設計

```
PostToolUse hook (auto-capture.ps1)
  └─ git commit / Write → memory/auto-capture/YYYY-MM-DD.md に追記

SessionStart hook (session-resume.ps1)
  └─ 直近3日分のキャプチャを読み込み → コンテキスト注入
```

**特徴**: 外部サーバー不要。ファイルベース。PowerShellスクリプト2本だけ。

### settings.json への登録

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Bash|Write",
      "hooks": [{
        "type": "command",
        "command": "powershell -File auto-capture.ps1"
      }]
    }],
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "powershell -File session-resume.ps1"
      }]
    }]
  }
}
```

## claude-mem vs 自作hook 比較

| 機能 | claude-mem | 自作hook |
|------|-----------|---------|
| セットアップ | `npx install` 1コマンド | スクリプト2本手書き |
| 自動キャプチャ | 全ツール使用を記録 | git commit + Write のみ |
| 検索 | ベクター類似度 + キーワード | grep (テキスト検索) |
| Web UI | localhost:37777 で可視化 | なし |
| 外部依存 | Bun + SQLite + (Chroma) | なし |
| トークン消費 | 圧縮にLLM使用 (Gemini無料可) | ゼロ |
| git管理 | DBファイル (gitignore) | mdファイル (git共有可) |
| 複数インスタンス | セッション単位で分離 | ファイル共有で協調 |

## 実際に両方を併用してみた結果

結論: **共存できる**。

claude-memはプラグインとしてhooksを登録し、自作hookはsettings.jsonに直接登録。両方が同時に動作する。

### claude-memの良い点

1. **圧縮が賢い**: LLM（Gemini等）で要約するので、大量のツール使用をコンパクトに記憶
2. **検索が強力**: 「先週のAPI実装」のような自然言語クエリで過去の作業を検索可能
3. **Web UIが便利**: 何が記憶されているか一目で確認できる

### 自作hookの良い点

1. **ゼロ依存**: サーバー起動不要。スクリプトだけで完結
2. **git共有**: チーム（複数インスタンス）で記憶を共有できる
3. **完全無料**: LLM APIを一切使わない
4. **カスタマイズ自在**: 何をキャプチャするか完全に制御可能

## コスト最適化のコツ

claude-memはデフォルトでClaude APIを使って圧縮するため、トークンを消費する。以下の設定で無料化できる:

```json
// ~/.claude-mem/settings.json
{
  "CLAUDE_MEM_PROVIDER": "gemini",
  "CLAUDE_MEM_GEMINI_API_KEY": "your-key-here"
}
```

Google AI StudioでGemini API Keyを無料取得し、圧縮処理をGeminiに委譲。Claude側のトークン消費はゼロになる。

## 我々のプロジェクトでの活用

自分株式会社（Flutter Web + Supabase）では3インスタンス並行開発を行っている。各インスタンスの知識共有に以下の3層メモリを使い分けている:

| 層 | ツール | 用途 |
|---|--------|------|
| L1: セッション内 | claude-mem (SQLite) | ツール使用の自動記録・検索 |
| L2: セッション間 | 自作hook (mdファイル) | git commit履歴・インスタンス間共有 |
| L3: プロジェクト横断 | NotebookLM Master Brain | 深い調査・長期知識の蓄積 |

## まとめ

claude-memは「Claude Codeを育てるパートナーに変える」ツールとして、宣伝文句に偽りなし。特にベクター検索とWeb UIは自作では難しい。

ただし、シンプルなユースケースなら自作hookで十分。外部依存なし・トークン消費なし・git共有可能という利点がある。

**おすすめ**: まず自作hookで最小限のメモリを実装し、必要に応じてclaude-memを追加導入する「段階的アプローチ」が最も合理的。

---

URL: https://my-web-app-b67f4.web.app/
GitHub: https://github.com/thedotmack/claude-mem
#ClaudeCode #AI #buildinpublic
