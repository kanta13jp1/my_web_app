-- PS#3 S138: AI大学 370→371社化 — AutoGPT (Significant Gravitas / 最大OSS自律エージェント / 82k+ stars / 2023年3月)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'autogpt', 'overview',
  'AutoGPT (Significant Gravitas) — 最大OSS自律エージェント・82k+ stars・2023年AI革命の象徴 (9/9)',
  $$## AutoGPT とは

**AutoGPT** は **Significant Gravitas** (Toran Bruce Richards) が 2023年3月に公開した、GitHub 史上最速で **80,000+ stars** を獲得した伝説的な自律 AI エージェント。

「目標を与えれば自分でタスクを考えて実行し続ける AI」という概念を世界に初めて広く知らしめた作品であり、**「自律 AI エージェント」という分野の認知を一般に広げた革命的なプロジェクト**。

## AutoGPT が起こした革命

```
2023年3月30日 公開後の数字:

  1週間: 10,000 stars
  1ヶ月: 80,000+ stars (GitHub史上最速クラス)
  Hacker News: トップ10に複数回ランクイン
  Twitter: #AutoGPT が世界トレンド入り
  メディア: Forbes/TechCrunch/Wiredが特集

  なぜ話題になったか:
    ・「AIが自分で考えて動く」を誰でも試せた
    ・GPT-4 APIキーがあれば動く
    ・ブラウザ閲覧・コード実行・ファイル保存
    ・「シンギュラリティが来た」という空気感
```

## AutoGPT のコアアーキテクチャ

```
AutoGPT の動作ループ:

  1. Goal 受け取り:
     例: "競合他社の価格を調査してスプレッドシートにまとめて"

  2. Thought (思考):
     "何をすべきか？" → LLM が次のアクションを決定

  3. Action (行動):
     利用可能なコマンドから1つ選択:
     - browse_website(url)
     - write_file(filename, content)
     - execute_python_file(filename)
     - google(query)
     - send_email(to, subject, body)
     - create_agent / message_agent (サブエージェント)

  4. Result (結果):
     コマンドの実行結果を取得

  5. Memory Update (記憶更新):
     - Short-term: 直近の会話履歴
     - Long-term: Pinecone/Redis にベクトル保存
     - File: ローカルファイルに保存

  6. Loop (ループ):
     Thought に戻る → 完了まで繰り返す
```

## 実際の使用例

```bash
# AutoGPT のセットアップ
git clone https://github.com/Significant-Gravitas/AutoGPT
cd AutoGPT
pip install -r requirements.txt

# .env を設定
cp .env.template .env
# OPENAI_API_KEY=sk-...
# PINECONE_API_KEY=...

# 起動
python -m autogpt

# 対話例:
# Name your AI: MarketResearchGPT
# Role: 競合調査と市場分析を行うAIアシスタント
# Goals:
#   1. Notion・Evernote・Slack の最新料金プランを調査する
#   2. 価格比較表を CSV ファイルに保存する
#   3. 競合優位性の分析レポートを作成する

# AutoGPT が自律的に:
# → Google 検索 → 各サイトを閲覧 → 情報を抽出
# → CSV を生成 → レポートを作成
# → 完了を報告
```

## AutoGPT の進化: Forge + Benchmark

```
AutoGPT エコシステム (2024年以降):

  AutoGPT Forge:
    ・AutoGPT エージェントを構築するフレームワーク
    ・テンプレートベースでカスタムエージェント作成
    ・Protocol: 標準化されたエージェント API

  AutoGPT Benchmark (agbenchmark):
    ・エージェント性能の標準ベンチマーク
    ・タスク達成率 / 効率を測定
    ・他フレームワークとの比較可能

  AutoGPT Platform:
    ・ノーコードでエージェントを構築・デプロイ
    ・クラウド実行 + スケジューリング
    ・フロー設計 UI

  AutoGPT Server:
    ・REST API でエージェントを起動
    ・複数エージェントの並列管理
    ・WebSocket でリアルタイム進捗取得
```

## AutoGPT の課題と教訓

```
AutoGPT が直面した課題:

  ハルシネーション増幅:
    ・ループするたびに誤情報が蓄積
    ・「自信満々に間違い続ける」問題
    → 検証ステップの重要性を証明

  コスト爆発:
    ・制御なしに API を呼び続ける
    ・数分で $10-50 の請求
    → task_budget の必要性を証明

  終了しない:
    ・完了条件を自分で判断できない
    → Human approval の重要性を証明

  これらの教訓が CrewAI / SuperAGI / LangGraph の
  設計改善に直接活かされている
```

## AutoGPT の歴史的位置づけ

```
AI エージェント史の転換点:

  Before AutoGPT (〜2023年3月):
    ・LLM = チャットボット
    ・人間が細かく指示する必要あり
    ・「自律的に動く AI」は研究レベル

  AutoGPT 登場 (2023年3月30日):
    ・「目標だけ与えれば自律実行」を実証
    ・一般ユーザーが AI エージェントを体験
    ・「AGI への道が見えた」という興奮

  After AutoGPT (2023年4月〜):
    ・BabyAGI / SuperAGI が後続
    ・LangChain がエージェント機能を追加
    ・Devin / Claude Code へと進化
    ・AI エージェント市場が形成される
```

## 自分株式会社との関連

AutoGPT の「目標設定 → 自律実行ループ」は、自分株式会社の ai-hub EF の ai-university-update action (daily 自動更新) と同型。現在は GHA cron + EF の組み合わせで疑似的に実現しているが、AutoGPT Forge のエージェント SDK を参考にすることで、より柔軟な自律アップデートパイプラインを設計できる。また AutoGPT のコスト爆発問題への解決策として設計した task_budget (EF) は、自分株式会社のオリジナル設計が AutoGPT の失敗から学んでいることを示している。
$$,
  'https://github.com/Significant-Gravitas/AutoGPT',
  NOW(),
  371
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
