---
title: "NotebookLM × Claude Code — ゼロトークンリサーチの実践"
tags: AI,個人開発,buildinpublic,postgresql
published: true
---

# NotebookLM × Claude Code — ゼロトークンリサーチの実践

Claude Code のコンテキスト消費量を半分にした一番の施策は「リサーチを NotebookLM に委譲する」ことでした。3ファイル同時読み込み (~150K tokens) が ~5K tokens になる。この差は無視できません。

## なぜ Claude Code だけではいけないのか

| 操作 | Claude 消費 | NotebookLM 委譲後 |
|---|---|---|
| 3ファイル以上を同時に読む | ~150K tokens | ~5K tokens |
| URLを分析する | ~60K tokens | ~2K tokens |
| 競合21社のリサーチ | ~80K tokens | ~3K tokens |
| ドキュメント全体を俯瞰する | ~100K tokens | ~4K tokens |

Claude Code は判断・統合・コード生成に使い、情報収集は外に出す。これが「ゼロトークンリサーチ」の思想です。

## 基本ワークフロー

```bash
# 1. ノートブック作成
notebooklm create "競合調査 2026-Q4"

# 2. ソース追加 (ファイル / URL / YouTube)
notebooklm source add "./docs/competitor-reports/2026-10.md"
notebooklm source add "https://example.com/saas-report"

# 3. 質問
notebooklm ask "競合21社の価格戦略の共通点は？"

# 4. 成果物生成 (Google インフラで無料処理)
notebooklm generate slide-deck "要点をスライドにまとめて"
notebooklm generate audio "deep dive focusing on key findings" --wait
```

Claude が消費するのは「質問を投げる」1ターンだけ。残りは NotebookLM が処理する。

## Web Deep Research: 自律調査

```bash
# NotebookLM が自分でWebを調査してレポートを生成
notebooklm source add-research "advanced Flutter Web performance optimization 2026"
notebooklm research wait  # 調査完了まで待機
notebooklm ask "調査結果のサマリーを教えて"
```

`add-research` コマンドで NotebookLM が数百ページを自律的に調査する。Claude Code は待機しているだけです。

## DBS フレームワーク: 調査 → スキル変換

調査した知識を使い捨てにせず、Claude Code スキルに変換する:

```
D (Direction) = 意思決定ツリー・手順 → SKILL.md のコア
B (Blueprints) = テンプレート・分類ルール → サポートファイル
S (Solutions) = API呼び出し・確定コード → スクリプト
```

実例: `t1-blog-dispatch` スキルは NotebookLM で blog-publish.yml の仕様を調査 → DBS 分類 → SKILL.md 化したものです。

## 実際の token 削減効果

月次 Claude Code token 使用量の推移:

| 月 | Claude 消費 | うち NotebookLM 委譲分 | 節約率 |
|---|---|---|---|
| 2026-01 | 800K | 0K | 0% |
| 2026-02 | 750K | 150K | 20% |
| 2026-03 | 500K | 350K | **44%** |
| 2026-04 | 420K | 400K | **49%** |

4月時点でほぼ半分。目標 50% 削減に届きました。

## Master Brain: 長期記憶の外部化

NotebookLM をプロジェクトの「マスターブレイン」として運用:

```bash
notebooklm use ea6cff25-574d-4b8b-ad72-ab47cf1ed01f  # jibun-master-brain
notebooklm source add "./memory/project_20260428.md"  # セッション要約を蓄積
notebooklm ask "過去に試して失敗したアーキテクチャ決定は？"
```

Claude Code のコンテキストは消えるが、NotebookLM の Master Brain は残る。セッション横断の「なぜ」を保持できます。

## まとめ

ゼロトークンリサーチの3原則:

1. **3ファイル以上はNotebookLMに渡す** (Claude Codeで読まない)
2. **URL分析はNotebookLMに任せる** (WebFetchを使わない)
3. **セッション終了時に要約をMaster Brainに蓄積** (知識を捨てない)

Claude Code を「使い切る」のではなく「判断だけに使う」設計にすると、コストも品質も同時に改善します。
