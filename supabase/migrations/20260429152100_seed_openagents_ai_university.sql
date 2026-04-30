-- PS#3 S137: AI大学 369→370社化 — OpenAgents (XLang Lab/Yale-NUS / 3エージェント統合 / Data+Plugins+Web)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'openagents', 'overview',
  'OpenAgents (XLang Lab) — 3エージェント統合プラットフォーム・Data+Plugins+Web・一般向けAIエージェント (9/9)',
  $$## OpenAgents とは

**OpenAgents** は **XLang Lab** (Tao Yu / Yale-NUS College) が開発した、**3種類の専門エージェントを統合した**オープンソース AI エージェントプラットフォーム。

「一般の人でも使えるエージェント」を目標に設計されており、**データ分析 / プラグイン実行 / Web ブラウジング**の3つの専門エージェントを Web UI から利用できる。

## OpenAgents の 3 エージェント

```
OpenAgents の 3 専門エージェント:

  1. Data Agent (データエージェント):
    ・自然言語でデータ分析を実行
    ・Python/Pandas コードを自動生成・実行
    ・CSV / Excel / データベース対応
    ・グラフ・可視化を自動生成
    ・「売上データを月別に集計してグラフにして」
      → Python コード自動生成 → 実行 → 結果表示

  2. Plugins Agent (プラグインエージェント):
    ・ChatGPT Plugin 互換の拡張機能を実行
    ・200+ プラグイン対応 (天気/ニュース/地図/EC等)
    ・自然言語でプラグインを選択・組み合わせ
    ・「東京の天気を調べてカレンダーに追加して」
      → Weather Plugin + Calendar Plugin を自動実行

  3. Web Agent (Webエージェント):
    ・ブラウザを自律操作
    ・クリック / 入力 / スクロールを自動化
    ・フォーム入力 / 情報収集 / RPA 代替
    ・「Amazonで最安値のiPhoneケースを見つけて」
      → ブラウザ起動 → 検索 → 比較 → 結果報告
```

## OpenAgents のアーキテクチャ

```
OpenAgents のシステム構成:

  Frontend (React):
    ・ChatGPT 風の Web UI
    ・エージェント選択画面
    ・実行ログのリアルタイム表示

  Backend (FastAPI):
    ・エージェントのオーケストレーション
    ・WebSocket でリアルタイム通信
    ・プラグインの管理・実行

  Data Agent Backend:
    ・Python 実行環境 (Docker)
    ・Pandas / Matplotlib / scikit-learn
    ・安全なサンドボックス実行

  Web Agent Backend:
    ・Playwright / Selenium
    ・Visual grounding (画面認識)
    ・ステルス操作 (CAPTCHA 回避なし)

  Plugin System:
    ・OpenAI Plugin 仕様互換
    ・yaml マニフェストで定義
    ・OAuth 2.0 認証対応
```

## 実際の使用例

```python
# OpenAgents Python SDK
from openagents import DataAgent, WebAgent, PluginsAgent

# Data Agent: 自然言語でデータ分析
data_agent = DataAgent(
    llm="gpt-4",
    data_source="./sales_data.csv"
)

result = data_agent.analyze(
    "2026年Q1の売上トップ10商品を棒グラフにして、"
    "前年同期比も計算してください"
)
# 自動生成された Python コード:
# import pandas as pd
# import matplotlib.pyplot as plt
# df = pd.read_csv('sales_data.csv')
# q1 = df[df['quarter'] == 'Q1 2026']
# top10 = q1.groupby('product')['sales'].sum().nlargest(10)
# ...
print(result.code)    # 生成されたコード
print(result.output)  # 実行結果
result.save_chart("q1_top10.png")  # グラフ保存

# Web Agent: ブラウザ自動操作
web_agent = WebAgent(llm="gpt-4")
result = web_agent.execute(
    "GitHub の my_web_app リポジトリの最新 PR 一覧を取得して"
    "マージ待ちのものだけリストアップして"
)
print(result.summary)

# Plugins Agent: プラグイン統合
plugins_agent = PluginsAgent(
    llm="gpt-4",
    plugins=["weather", "google_calendar", "slack"]
)
result = plugins_agent.execute(
    "明日の東京の天気を確認して、雨なら Slack の #general に通知して"
    "カレンダーにも雨の日のリマインダーを追加して"
)
```

## XLang Lab について

```
XLang Lab (Cross-Lingual / Cross-Modal NLP):

  主宰: Tao Yu (ユー・タオ)
    ・Yale-NUS College 助教授
    ・Spider (Text-to-SQL データセット) の作者
    ・自然言語 → 実行可能コードの研究

  主要研究:
    ・Spider: 自然言語 → SQL の標準ベンチマーク
    ・SParC / CoSQL: マルチターン Text-to-SQL
    ・WebArena: Web エージェントの評価環境
    ・OpenAgents: 研究の実用化

  OpenAgents の意義:
    ・学術研究をプロダクト化
    ・Web UI で非技術者も使える
    ・3エージェントの統合 UI は当時先進的
```

## TaskWeaver / OpenAgents / BabyAGI 比較

```
データ処理系エージェント比較:

  BabyAGI:
    ・タスク管理ループ
    ・汎用エージェント
    ・プロトタイプ

  TaskWeaver (Microsoft):
    ・Python コードファースト
    ・データ分析特化
    ・Plugin YAML 定義

  OpenAgents (XLang):
    ・3エージェント統合
    ・Web UI 付き
    ・Data + Plugins + Web の3軸

  → OpenAgents = 最も「使いやすい」設計
  → TaskWeaver = エンタープライズ統合
  → BabyAGI = 概念学習用
```

## 自分株式会社との関連

OpenAgents の「3エージェント統合 Web UI」は、自分株式会社の将来的な「AI アシスタントダッシュボード」設計に直接応用できる。現在の ai-assistant EF は単一エージェントだが、OpenAgents パターンで「データ分析エージェント (Supabase クエリ) / プラグインエージェント (外部SaaS統合) / Web エージェント (競合サイト監視)」の3軸に分割することで、ユーザーが自然言語でどの機能でも操作できるインターフェースに進化できる。また OpenAgents の Plugin システム (OpenAI Plugin 互換) は ai-hub EF の action を Plugin として公開する設計の参考になる。
$$,
  'https://github.com/xlang-ai/OpenAgents',
  NOW(),
  370
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
