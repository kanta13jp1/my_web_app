-- PS#3 S122: AI大学 338→339社化 — OpenHands (旧OpenDevin / OSS自律AIエンジニア / AllHands AI)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'openhands', 'overview',
  'OpenHands — OSS自律AIエンジニア・旧OpenDevin・AllHands AI製・SWE-bench最高水準・ローカル実行可 (9/9)',
  $$## OpenHands とは

**OpenHands**（旧称: **OpenDevin**）は **AllHands AI** が開発するオープンソースの**自律型 AI ソフトウェアエンジニアプラットフォーム**。Devin の OSS 代替として 2024 年に登場し、GitHub で **40k+ スター**を獲得した超人気プロジェクト。

完全オープンソースであり、**ローカルで実行可能**。任意の LLM（Claude / GPT-4 / Llama など）と組み合わせて使える柔軟性が特徴。

## OpenHands のコアアーキテクチャ

```
OpenHands の構成:

  エージェントレイヤー:
    ・CodeAct Agent (メイン): シェル + Python REPL + ブラウザ統合
    ・Browsing Agent: Webブラウジング特化
    ・Readonly Agent: コード読み取り・説明専用

  実行環境:
    ・Docker サンドボックス (安全な分離実行)
    ・シェルコマンド実行 (bash/fish/zsh)
    ・Python/Node.js REPL
    ・ファイルシステム操作
    ・Webブラウザ (Playwright統合)

  LLM プロバイダー:
    ・Anthropic Claude (推奨)
    ・OpenAI GPT-4o
    ・Google Gemini
    ・ローカル LLM (Ollama/LM Studio)
    ・その他 LiteLLM 対応モデル
```

## SWE-bench 実績

OpenHands は SWE-bench Verified で **Claude 3.5 Sonnet を使用した場合 50%超**のスコアを記録（2025年時点で最高水準の一つ）。Devin の商用サービスと比較してもオープンソースながら遜色ない性能。

## セットアップ方法

```bash
# Docker が必要
docker pull docker.allhands.ai/openhands:latest

# 起動 (Claude API キーを指定)
docker run -it \
  -e SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.allhands.ai/runtime:latest \
  -e LLM_API_KEY=sk-ant-xxx \
  -e LLM_MODEL=claude-sonnet-4-6 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 3000:3000 \
  docker.allhands.ai/openhands:latest
```

## Devin vs OpenHands 比較

| 項目 | OpenHands | Devin |
|------|-----------|-------|
| ライセンス | MIT (OSS) | プロプライエタリ |
| 価格 | 無料 (LLM API 実費のみ) | $500/月〜 |
| LLM | 任意 (Claude推奨) | 非公開 |
| ローカル実行 | ○ | × |
| カスタマイズ | 完全自由 | 制限あり |
| GitHub Stars | 40k+ | — |

## 主なユースケース

1. **GitHub Issue の自動修正**: Issue URL を貼るだけで PR まで自動作成
2. **コードベース探索**: 大規模リポジトリの理解・ドキュメント生成
3. **テスト作成**: 既存コードのテストを自動生成
4. **リファクタリング**: 特定パターンの一括書き換え
5. **ドキュメント生成**: コードからドキュメントを自動生成

## コミュニティとエコシステム

- **GitHub Stars**: 40k+（2025年時点）
- **Discord**: 活発なコミュニティ
- **Plugin エコシステム**: 独自エージェントの追加が可能
- **企業採用**: 多数のスタートアップ・大企業が POC 実施中

## 自分株式会社との関連

OpenHands は自分株式会社の **Codex インスタンス代替** として検討価値がある。Claude API をバックエンドに持ちつつ、GitHub Issue → PR 自動作成フローは `github-issue-fix.yml` ワークフローと類似した機能を持つ。ローカル実行可能なため API コスト制御が容易。
$$,
  'https://github.com/All-Hands-AI/OpenHands',
  NOW(),
  339
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
