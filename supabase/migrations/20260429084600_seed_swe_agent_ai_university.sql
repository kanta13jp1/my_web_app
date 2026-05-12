-- PS#3 S122: AI大学 339→340社化 — SWE-agent (Princeton / GitHub Issue自動修正 / OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'swe-agent', 'overview',
  'SWE-agent — Princeton大学製OSS・GitHub Issue自動修正AIエージェント・SWE-bench命名元 (9/9)',
  $$## SWE-agent とは

**SWE-agent** は **Princeton 大学** の研究チームが開発したオープンソースの **AI ソフトウェアエンジニアリングエージェント**。**SWE-bench**（Software Engineering Benchmark）の名前の由来となった研究プロジェクトそのものであり、「AI が実際の GitHub の Issue を自律的に修正できるか」を検証するために開発された。

学術研究から生まれたツールながら、実用性が高く **GitHub で 14k+ スター**を獲得。Devin / OpenHands などの商用・OSS プロダクトに先行して自律 AI エンジニアリングの概念を確立した。

## SWE-agent の仕組み

```
SWE-agent のアーキテクチャ:

  Agent-Computer Interface (ACI):
    ・LLM とコンピュータの間の専用インターフェース
    ・単純なシェルコマンドよりエージェント向けに最適化
    ・ファイル閲覧・編集・コマンド実行を統合

  専用コマンド:
    ・open <file>: ファイルを開いて表示
    ・goto <line>: 特定行にジャンプ
    ・scroll_up/down: ファイル内スクロール
    ・search_file <keyword>: ファイル内検索
    ・find_file <name>: ファイル名検索
    ・edit <line>:<content>: 行単位の編集

  実行フロー:
    1. GitHub Issue を読み込む
    2. リポジトリをクローン
    3. 問題を分析・再現
    4. 修正コードを実装
    5. テストを実行・確認
    6. パッチとして出力
```

## SWE-bench との関係

SWE-agent は SWE-bench の **名前の由来かつ最初の実装**。

- **SWE-bench**: 実際の GitHub リポジトリの Issue 2294 件を解決する能力を測るベンチマーク
- **評価対象**: django / flask / scikit-learn / requests など著名 OSS プロジェクト
- **SWE-agent の初期スコア**: 12.47%（2024年当時の最高水準）
- **その後の進化**: Claude 3.5 + improved prompting で大幅スコア向上

## 使い方

```bash
# インストール
git clone https://github.com/SWE-agent/SWE-agent.git
cd SWE-agent
pip install -e .

# GitHub Issue を自動修正
python run.py \
  --model_name claude-sonnet-4-6 \
  --data_path "https://github.com/owner/repo/issues/123" \
  --config_file config/default.yaml

# ローカルリポジトリに対して実行
python run.py \
  --model_name claude-sonnet-4-6 \
  --repo_path /path/to/local/repo \
  --issue_text "バグの説明..."
```

## 対応 LLM

- **Anthropic Claude** (推奨: claude-sonnet-4-6)
- **OpenAI GPT-4o**
- **Google Gemini**
- **ローカルモデル** (Ollama 経由)

## 学術的背景と影響

- **論文**: "SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering" (2024)
- **著者**: Princeton NLP Group
- **引用数**: 急速に増加（AI エンジニアリング分野の基礎論文）
- **影響**: Devin / OpenHands / AutoCodeRover など多数のプロダクトに影響

## 自分株式会社との関連

SWE-agent のアプローチ（ACI による LLM とコンピュータの統合）は、Claude Code が採用しているアーキテクチャと類似。`github-issue-fix.yml` ワークフローは SWE-agent と同様の Issue 自動修正フローを GHA で実装したもの。学術的背景の理解がシステム設計の参考になる。
$$,
  'https://github.com/SWE-agent/SWE-agent',
  NOW(),
  340
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
