-- PS#3 S132: AI大学 359→360社化 — ChatDev (清華大学 / ソフトウェア会社シミュレーション / chat駆動)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'chatdev', 'overview',
  'ChatDev — 清華大学発ソフトウェア会社シミュレーション・チャット駆動開発・役割別エージェント (9/9)',
  $$## ChatDev とは

**ChatDev** は清華大学 (Tsinghua University) が開発した、AI エージェントがソフトウェア会社全体をシミュレートするシステム。MetaGPT と同様の「マルチエージェントによるソフトウェア開発」コンセプトだが、**「チャット」を唯一のコミュニケーション手段**として徹底している。

論文「Communicative Agents for Software Development」として発表。**25,000+ GitHub stars** を獲得。

## ChatDev の独自性: Chat-Chain

```
ChatDev の設計思想:

  通常の AI コーディング: LLM → コード生成
  ChatDev: エージェント同士が「チャット」してコードを生成

  Chat-Chain (チャットの連鎖):
    Phase 1: Design
      CEO ←→ CPO: 要件定義チャット
      CEO ←→ CTO: 技術選定チャット

    Phase 2: Coding
      CTO ←→ Programmer: 設計チャット
      Programmer ←→ Programmer: コードレビューチャット

    Phase 3: Testing
      Tester ←→ Programmer: バグ報告チャット
      Programmer ←→ Reviewer: 修正確認チャット

    Phase 4: Documentation
      Documenter ←→ Programmer: 仕様確認チャット
```

## ChatDev の役割体系

```
ChatDev の登場人物 (エージェント):

  経営層:
    CEO: 最終意思決定・要件承認
    CPO (Chief Product Officer): 製品仕様管理
    CTO (Chief Technology Officer): 技術方針決定

  開発:
    Programmer: 実際のコード作成
    Reviewer: コードレビュー
    Tester: テスト設計・実行

  ドキュメント:
    Documenter: 技術文書作成

  → 全員が「チャット」で協調
```

## 実際の動作フロー

```bash
# インストール
git clone https://github.com/OpenBMB/ChatDev
cd ChatDev
pip install -r requirements.txt

# タスク実行 (自然言語で指定するだけ)
python run.py \
  --task "Create a snake game in Python with GUI" \
  --name "SnakeGame"

# → ChatDev/ SnakeGame/ に以下が生成される:
#   main.py          (Pythonコード)
#   requirements.txt (依存関係)
#   README.md        (README)
#   manual.md        (ユーザーマニュアル)
#   meta.txt         (チャット履歴)
```

## ChatDev vs MetaGPT の比較

| 項目 | ChatDev | MetaGPT |
|------|---------|---------|
| 機関 | 清華大学 | 中国・OSS |
| 通信方式 | チャットのみ | 構造化文書 |
| 役割 | CEO/CPO/CTO/Programmer | PM/Architect/Engineer/QA |
| Stars | 25k+ | 40k+ |
| 論文 | ✓ (ICML/ACL) | ✓ |
| 強み | シンプルなコミュニケーション | 厳密な成果物管理 |

## ChatDev の研究的貢献

1. **Self-Reflection**: エージェントが自分の出力を批判・改善する仕組み
2. **Role-Playing**: LLM が特定の役職を演じることでパフォーマンス向上
3. **Thought Instructions**: 思考パターンをプロンプトで誘導する技術
4. **デジタル社会の研究**: エージェントが社会をシミュレートする

## 自分株式会社との関連

ChatDev の「チャットのみでエージェントが協調」パターンは、自分株式会社の 12 インスタンスフリートの cross-instance-pr メカニズムに対応。「PS#3 がAI大学コンテンツを追加 → Win版がアーキテクチャレビュー → VSCode版が UI 実装」という流れは ChatDev の Chat-Chain と同構造。また ChatDev の「Self-Reflection (自己批判・改善)」は自分株式会社の claude-agent-review.yml が実装している機能と同一。
$$,
  'https://github.com/OpenBMB/ChatDev',
  NOW(),
  360
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
