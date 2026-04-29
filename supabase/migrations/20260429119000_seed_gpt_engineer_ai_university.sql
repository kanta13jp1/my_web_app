-- PS#3 S130: AI大学 354→355社化 — GPT-Engineer (仕様→コード全自動生成 / OSS 50k+ stars / JARVIS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'gpt-engineer', 'overview',
  'GPT-Engineer — 仕様書からコード全自動生成・OSS 50k+ stars・バイブコーディング先駆者 (9/9)',
  $$## GPT-Engineer とは

**GPT-Engineer** は「仕様を書けば、コードを書いてくれる」AI コーディングツール。2023年に GitHub で公開されると爆発的な人気を集め、**50,000 stars** 以上を獲得。「バイブコーディング」の先駆的な OSS として AI コーディングムーブメントを牽引した。

現在は **Lovable** (旧 GPT Engineer App) という SaaS プロダクトとして商業展開されている。

## 誕生の背景

```
2023年 GitHub Trending 爆発の経緯:

  公開日: 2023年6月
  公開者: Anton Osika (スウェーデン人エンジニア)
  初日 GitHub Stars: 数千
  1週間後: 20,000+ stars
  現在: 50,000+ stars

  話題になった理由:
  ・「プロンプト1つ → アプリが生まれる」の驚き
  ・シンプルな実装 (Python 数百行)
  ・MIT ライセンスで誰でも試せる
  ・ChatGPT ブームの追い風
```

## GPT-Engineer の動作原理

```bash
# 使い方 (シンプル)
pip install gpt-engineer

# プロジェクトフォルダを作成
mkdir my-project
echo "Todoアプリを作って。React + TypeScript で。
ローカルストレージに保存。ダークモード対応。" > my-project/prompt

# 実行
gpt-engineer my-project

# → src/ に React コンポーネントが生成される
```

## 内部動作フロー

```
GPT-Engineer の生成フロー:

  Step 1 — 仕様明確化:
    ・プロンプトを読む
    ・不明点があればユーザーに質問 (対話型)
    ・仕様を詳細化

  Step 2 — ファイル計画:
    ・必要なファイル一覧を決定
    ・ディレクトリ構造を設計

  Step 3 — コード生成:
    ・ファイルを順番に生成
    ・依存関係を考慮した順序

  Step 4 — エントリーポイント:
    ・起動スクリプトを生成
    ・README を自動作成
```

## GPT-Engineer → Lovable への進化

| フェーズ | ツール | 特徴 |
|----------|--------|------|
| 2023年6月 | GPT-Engineer (OSS) | CLI ツール / テキスト → コード |
| 2024年 | GPT Engineer App (Beta) | Web UI / リアルタイムプレビュー |
| 2025年 | **Lovable** | Full-stack Web app builder / $20月〜 |

**Lovable** は Bolt.new / v0.dev と同じ「ブラウザ完結フルスタック生成」カテゴリで競合。

## 他ツールとの比較

| 項目 | GPT-Engineer | Bolt.new | v0.dev |
|------|-------------|----------|--------|
| OSS | ✓ (CLI) | × | × |
| UI | CLI → Web | ブラウザ完結 | ブラウザ完結 |
| 対象 | 任意アプリ | フルスタック | React UI |
| Stars | 50k+ | N/A | N/A |
| 商用版 | Lovable | Bolt.new | v0.dev |

## 自分株式会社との関連

GPT-Engineer が体現した「プロンプトから完全なアプリを生成する」コンセプトは、自分株式会社の AI 大学が追跡する重要なトレンド。自分株式会社の自動化フロー（GHA → Edge Function → Flutter UI 自動更新）は、GPT-Engineer が先鞭をつけた「AI がコード全体を生成・管理する」世界観の延長線上にある。
$$,
  'https://github.com/AntonOsika/gpt-engineer',
  NOW(),
  355
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
