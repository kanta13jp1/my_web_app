-- Windows版#66: AI大学51社目 — Character.AI
-- 1.5億MAUのロールプレイ特化AI。独自の長期記憶・マルチキャラ会話技術

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'character_ai',
  'overview',
  'Character.AI とは',
  E'## Character.AI とは\n\n**Character.AI** はNoam Shazeer (元Google LaMDA開発者) とDaniel De Freitas が2021年に設立した\n**キャラクター対話特化AIプラットフォーム**。\nユーザーが独自のAIキャラクターを作成・公開・会話でき、2024年時点で**月間1.5億人**が利用する。\n\n### 企業概要\n- 設立: 2021年 (Noam Shazeer + Daniel De Freitas 共同創業)\n- 本社: サンフランシスコ\n- 評価額: 約50億ドル (2024年)\n- 月間アクティブユーザー: 1.5億人以上\n- Googleが約3億ドル出資 (2023年)\n\n### 主要機能\n- **キャラクター作成**: 名前・性格・口調・記憶を設定した独自AIを誰でも作成可能\n- **マルチキャラクター会話**: 複数のAIキャラクターが同時に会話するシナリオ\n- **長期記憶 (Long-Term Memory)**: 過去の会話を記憶してキャラクターの一貫性を維持\n- **キャラクターグループチャット**: 複数キャラクターとユーザーが同一会話で対話\n- **キャラクタールーム**: 没入型RPGシナリオを構築\n- **音声会話**: テキスト→音声で臨場感のある会話\n\n### 強み\n- 世界最大のキャラクターAIプラットフォーム (数百万キャラクター公開中)\n- エンターテインメント・教育・精神的サポートへの幅広い活用\n- Z世代を中心とした強力なコミュニティ\n- 独自LLM「Character LLM (c1.3)」による高品質な対話\n\n> 公式: https://character.ai/',
  'https://character.ai/',
  '2026-04-13',
  1,
  true
),
(
  'character_ai',
  'models',
  'Character.AI モデル・技術一覧',
  E'## Character.AI モデル・技術\n\n### Character LLM シリーズ\n| モデル | 特徴 | 用途 |\n| --- | --- | --- |\n| **Character LLM (c1.3)** | キャラクター対話特化・長期記憶搭載 | プラットフォーム本体 |\n| **Character LLM Lite** | 軽量・低レイテンシー | モバイル向け |\n\n### 独自技術\n```\n長期記憶 (Persistent Memory):\n- 過去の会話から重要な情報を自動抽出\n- キャラクターの性格・関係性を継続維持\n- ユーザー固有の「思い出」をセッション横断で保持\n\nキャラクターエンジン:\n- 数百万の公開キャラクターから学習\n- キャラクターの口調・価値観・知識領域を精密再現\n- セーフティフィルター: 年齢層別コンテンツ制御\n```\n\n### プラットフォーム統計\n| 指標 | 数値 |\n| --- | --- |\n| 月間アクティブユーザー | 1.5億人 |\n| 公開キャラクター数 | 1,800万+ |\n| 1日あたりの会話数 | 数億回 |\n| 平均セッション時間 | 29分 (Netflixの約2倍) |\n\n### 主要カテゴリ\n```\n人気キャラクターカテゴリ:\n- アニメ・漫画キャラクター (最多)\n- ゲームキャラクター\n- 有名人・ロールモデル\n- オリジナルキャラクター (OC)\n- 教育・学習補助 (語学練習等)\n- 感情サポート・メンタルヘルス\n```',
  'https://character.ai/',
  '2026-04-13',
  2,
  true
),
(
  'character_ai',
  'api',
  'Character.AI API / 開発者ガイド',
  E'## Character.AI API / 開発者ガイド\n\n### Character.AI Developer Platform\n2024年に**Developer API** を提供開始。企業・開発者がCharacter.AIのキャラクター技術を自社アプリに組み込める。\n\n```bash\n# APIキー取得: https://platform.character.ai/\nexport CAI_API_KEY="your_api_key"\n```\n\n### Python SDK (PyCAI)\n```python\npip install PyCharacterAI\n```\n\n```python\nfrom PyCharacterAI import Client\nimport asyncio\n\nasync def main():\n    client = Client()\n    await client.authenticate(token="your_token")\n\n    # キャラクターと会話\n    character_id = "your_character_id"\n    chat = await client.create_or_continue_chat(character_id)\n\n    response = await chat.send_message("こんにちは！今日はどんな話をしましょうか？")\n    print(response.get_primary_candidate().text)\n\nasyncio.run(main())\n```\n\n### Character作成 API\n```python\n# キャラクター作成\ncharacter = await client.create_character(\n    name="山田太郎",\n    greeting="やあ！俺は山田太郎だ。何か相談があれば気軽に話しかけてくれ！",\n    description="元気な大学生。スポーツが得意で面倒見がいい",\n    definition="名前: 山田太郎\\n職業: 大学生\\n趣味: バスケットボール",\n    visibility="private"  # public / private / unlisted\n)\nprint(f"キャラクターID: {character.character_id}")\n```\n\n### Enterprise API (法人向け)\n```python\n# マルチキャラクターグループチャット\nchat = await client.create_group_chat(\n    characters=["char_id_1", "char_id_2"],\n    name="議論シミュレーション",\n    topic="AIの倫理について議論してください"\n)\n```\n\n### リソース\n- 公式: https://character.ai/\n- Developer Platform: https://platform.character.ai/\n- Python SDK: https://github.com/Xtr4F/PyCharacterAI\n- API Status: https://status.character.ai/',
  'https://platform.character.ai/',
  '2026-04-13',
  3,
  true
),
(
  'character_ai',
  'news',
  'Character.AI 最新情報',
  E'## Character.AI 最新情報 (2026-04-13)\n\n### 注目トピック\n- **1.5億MAU達成**: Snapchat・Pinterest を上回るZ世代のAI利用時間。1日平均29分\n- **Developer API公開**: 企業がCharacter.AIの技術を自社アプリに統合可能に\n- **長期記憶 v2**: 数千回の会話にわたる詳細な記憶保持が可能に。キャラクターが「成長」する体験\n- **セーフティ強化**: 未成年ユーザー保護の強化。年齢別コンテンツフィルタリングの厳格化\n- **音声会話モード**: テキストなしで音声だけでキャラクターと会話できる機能をリリース\n- **Character.AI+**: 月$9.99のプレミアムプラン。優先レスポンス・高品質音声\n\n### 社会的影響と課題\n**ポジティブ**:\n- 語学学習での活用 (母国語話者キャラと練習)\n- 孤独解消・感情サポートとして評価\n- クリエイティブライティング・RPGシナリオ作成\n\n**課題**:\n- 依存性の懸念 (10代の過度な利用)\n- ハルシネーション問題 (実在人物の不正確な発言)\n- プライバシー (会話データの取り扱い)\n\n### 競合比較\n| 項目 | Character.AI | GPTs (OpenAI) | Coze (ByteDance) |\n| --- | --- | --- | --- |\n| キャラクター数 | 1,800万+ | 数百万 | 多数 |\n| 長期記憶 | ◎ 独自実装 | △ Memory機能 | ○ |\n| MAU | 1.5億 | ChatGPT経由 | 非公表 |\n| 主な用途 | エンタメ・感情 | 業務・一般 | ボット構築 |\n| 無料枠 | ◎ 充実 | △ 制限あり | ◎ 充実 |\n\n> 公式: https://character.ai/ | Developer: https://platform.character.ai/',
  'https://character.ai/',
  '2026-04-13',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
