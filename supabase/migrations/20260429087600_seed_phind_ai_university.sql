-- PS#3 S123: AI大学 340→341社化 — Phind (コード特化AI検索エンジン / GPT-4 + 独自モデル)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'phind', 'overview',
  'Phind — コード特化AI検索エンジン・GPT-4+独自モデル・技術質問に最適・無料プランが手厚い (9/9)',
  $$## Phind とは

**Phind** は**コード・技術質問に特化した AI 検索エンジン**。「プログラマーのための AI 検索エンジン」をコンセプトに、技術的な質問に対して **Web 検索 + LLM を組み合わせて回答**する。ChatGPT や Perplexity AI と異なり、**コードの実行例・最新ドキュメント・GitHub Issues** を重点的に参照する点が特徴。

独自モデル **Phind-70B** を開発しており、コーディングタスクにおいて GPT-4 と同等〜それ以上の性能を達成したことで注目を集めた。

## Phind の仕組み

```
Phind の検索フロー:

  1. クエリ解析:
     ・コードの質問かどうかを判定
     ・プログラミング言語・フレームワークを特定
     ・エラーメッセージの場合はデバッグモードに切替

  2. Web 検索 (独自クローラー):
     ・Stack Overflow
     ・GitHub Issues / Discussions
     ・公式ドキュメント
     ・技術ブログ (dev.to / Medium / Qiita等)
     ・Reddit (r/programming など)

  3. 回答生成:
     ・参照元を明示してコード付きで回答
     ・複数の解決策を比較提示
     ・最新情報 (クローラーで取得) を反映

  4. コードブロック:
     ・シンタックスハイライト
     ・コピーボタン
     ・言語自動判定
```

## Phind-70B モデル

- **ベース**: CodeLlama-34B + 独自ファインチューニング
- **コーディング性能**: HumanEval で GPT-4 に匹敵
- **特化領域**: Python / JavaScript / TypeScript / Go / Rust
- **API 提供**: 開発者向け API (有料)

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| Free | $0 | 無制限検索 + GPT-3.5 |
| Pro | $20 | GPT-4o + Phind-70B + 検索無制限 |
| Team | $30/人 | チーム機能 + 優先サポート |

## Phind vs Perplexity AI 比較

| 項目 | Phind | Perplexity AI |
|------|-------|---------------|
| 特化 | コード・技術 | 汎用 |
| モデル | GPT-4o + Phind-70B | Claude / GPT-4o |
| 検索対象 | 技術サイト重点 | 全Web |
| 料金 | $20/月 | $20/月 |
| コード表示 | 専用レンダリング | 汎用 |

## 開発者コミュニティでの評価

- **「Stack Overflow の代替」**: 技術質問のワークフローが大幅に変わったという声
- **「エラーメッセージをそのまま貼れる」**: デバッグの効率化
- **「ドキュメントを読む手間が減った」**: API 使用法を自然言語で質問できる
- **「最新情報が強い」**: Web 検索込みなのでトレーニングデータ切れがない

## ユースケース

1. **エラー解決**: スタックトレースをそのまま入力 → 原因と修正方法
2. **API の使い方**: 「Supabase でリアルタイム購読をするには？」
3. **ベストプラクティス**: 「Flutter でのステート管理ベストプラクティス 2025」
4. **コードレビュー**: コードを貼り付けて改善案を求める
5. **技術選定**: 「PostgreSQL vs MongoDB、この用途では？」

## 自分株式会社との関連

Phind は自分株式会社の開発ワークフローで Claude Code の補完的ツールとして活用できる。特に **最新ライブラリの使い方確認** や **エラーデバッグ** において、Claude のトレーニングデータ切れを Web 検索で補える。PS#3 が担当する AI 大学コンテンツの調査にも有効。
$$,
  'https://www.phind.com',
  NOW(),
  341
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
