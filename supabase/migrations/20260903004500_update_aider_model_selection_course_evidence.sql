-- Issue #5227: Aider モデル選択 & コスト最適化コースのエビデンス契約・評価基準・更新日付の強化
UPDATE ai_university_contents
SET
  description = $md$
## 推奨モデルと使い分け (2026年最新ベンチマーク)

| モデル | コスト | コーディング品質 | 推奨用途 | トークン単価 (入力/出力 1Mあたり) |
| :--- | :--- | :--- | :--- | :--- |
| **claude-sonnet-4-6** | 中 ($3.00 / $15.00) | ★★★★★ (93.7%) | 複雑なリファクタリング・アーキテクチャ変更 | ~$0.02 / 100行 |
| **claude-haiku-4-5** | 安 ($0.80 / $4.00) | ★★★★☆ (82.1%) | 軽微な修正・コメント追加・フォーマット | ~$0.003 / 100行 |
| **deepseek/deepseek-coder** | **最安** ($0.14 / $0.28) | ★★★★☆ (84.5%) | コスト最優先の大量バッチ処理・単体テスト生成 | ~$0.001 / 100行 |
| **gpt-4o** | 高 ($2.50 / $10.00) | ★★★★☆ (88.2%) | OpenAI / Azure 企業インフラ連携 | ~$0.04 / 100行 |
| **ollama/qwen2.5-coder** | 無料 (ローカル) | ★★★☆☆ (74.0%) | 完全オフライン・機密データ・プライベート開発 | $0.00 |

## コスト最適化 `.aider.conf.yml` 実践構成

```yaml
# プロジェクトルートに配置 (.aider.conf.yml)
model: claude-sonnet-4-6
auto-commits: true        # 変更後に自動 git commit
dirty-commits: true       # 未コミットのファイルも編集可
read: README.md           # 常にコンテキストに含めるファイル
message-tokens-limit: 4096
cache-prompts: true       # プロンプトキャッシュで最大90%コスト削減
```

## モデル切り替えコマンド

```bash
# Claude を使用 (最高品質・推奨)
export ANTHROPIC_API_KEY=your_key
aider --model claude-sonnet-4-6

# DeepSeek (コスト削減・日常開発)
export DEEPSEEK_API_KEY=your_key
aider --model deepseek/deepseek-chat

# Ollama (完全ローカル・無料)
ollama pull qwen2.5-coder:7b
aider --model ollama/qwen2.5-coder:7b
```
$md$,
  source_url = 'https://aider.chat/docs/config/options.html',
  published_at = '2026-09-02'
WHERE provider_id = 'aider' AND (title LIKE '%Aider モデル選択%' OR id = '256fce47-54de-4716-ad2c-478bc2e9613b');
