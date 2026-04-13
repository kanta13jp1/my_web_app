-- Windows版#66: AI大学52社目 — Inflection AI (Pi)
-- Mustafa Suleiman (DeepMind共同創業者) が設立。感情的知性特化のAI「Pi」

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'inflection',
  'overview',
  'Inflection AI (Pi) とは',
  E'## Inflection AI (Pi) とは\n\n**Inflection AI** はDeepMindの共同創業者**Mustafa Suleiman** と元LinkedIn CTO**Reid Hoffman**が\n2022年に設立したAIスタートアップ。\n「人間の感情を理解し寄り添う」**感情的知性 (EQ) 特化のAI「Pi (Personal Intelligence)」**を開発。\n\n### 企業概要\n- 設立: 2022年 (Mustafa Suleiman + Karén Simonyan + Reid Hoffman)\n- 本社: サンフランシスコ\n- 評価額: 約40億ドル (2024年)\n- 調達総額: 約15億ドル (Microsoft・NvidiaなどからSeries B)\n- 2024年: MicrosoftがMustafa SuleimanをMicrosoft AI CEO として招聘\n\n### 主要製品\n- **Pi**: 個人向け感情サポートAIアシスタント (iOS/Android/Web)\n- **Inflection-2.5**: GPT-4クラスのフラッグシップモデル\n- **Inflection API**: 企業向けAPI (感情的知性特化)\n- **Inflection for Enterprise**: カスタマーサポート・HR向け法人ソリューション\n\n### 特徴・強み\n- **EQ (感情的知性)**: 共感・傾聴・励ましが得意。メンタルヘルスサポートに特化\n- **非批判的会話**: ユーザーを判断せず受け入れるトーン\n- **長期的関係性**: 過去の会話を記憶して個人化されたアシスタントに\n- **安全設計**: 危機介入・自傷リスク検知と適切なリソース案内\n\n> 公式: https://inflection.ai/ | Pi: https://pi.ai/',
  'https://inflection.ai/',
  '2026-04-13',
  1,
  true
),
(
  'inflection',
  'models',
  'Inflection AI モデル一覧',
  E'## Inflection AI モデル一覧\n\n### Inflection モデルシリーズ\n| モデル | パラメータ | 特徴 | ベンチマーク |\n| --- | --- | --- | --- |\n| **Inflection-2.5** | 非公開 | GPT-4クラス・EQ特化 | 多くのタスクでGPT-4に匹敵 |\n| **Inflection-2** | 非公開 | 中間性能 | GPT-3.5超え |\n| **Inflection-1** | 非公開 | 初代モデル | — |\n\n### 感情的知性 (EQ) の技術\n```\nInflection の差別化要素:\n\n1. Tone Modeling\n   - 共感的・支持的・非批判的なトーンを学習\n   - ユーザーの感情状態を文脈から推定して応答を調整\n\n2. Long-Term Persona Memory\n   - 会話横断でユーザーの好み・悩み・目標を記憶\n   - 「先週話していた仕事の悩み、その後どうなった?」等の継続性\n\n3. Crisis Detection\n   - 自傷・自殺のリスクシグナルを検知\n   - 適切な専門機関リソースを案内\n\n4. Motivational Interviewing\n   - 行動変容を促すコーチングアプローチを組み込み\n```\n\n### Pi の主要機能\n| 機能 | 内容 |\n| --- | --- |\n| **感情サポート** | 悩み相談・ストレス解消・励まし |\n| **学習コーチ** | 知識の説明・学習計画サポート |\n| **キャリアアドバイス** | 履歴書添削・面接練習 |\n| **創作支援** | アイデア出し・執筆フィードバック |\n| **音声会話** | 自然な音声で会話 (6つの音声スタイル) |\n\n### 料金\n| プラン | 価格 | 内容 |\n| --- | --- | --- |\n| Free | 無料 | 1日あたりの会話制限あり |\n| Pi Pro | $9.99/月 | 無制限会話・高度な音声 |',
  'https://inflection.ai/',
  '2026-04-13',
  2,
  true
),
(
  'inflection',
  'api',
  'Inflection AI API 利用方法',
  E'## Inflection AI API 利用方法\n\n### Inflection Enterprise API\n法人向けAPIとして、感情的知性を活かしたカスタマーサポート・HR応用に特化。\n\n```bash\n# APIキー取得: https://inflection.ai/enterprise\nexport INFLECTION_API_KEY="your_api_key"\n```\n\n### REST API (基本)\n```python\nimport requests\n\nAPI_URL = "https://api.inflection.ai/v1/chat"\nheaders = {\n    "Authorization": f"Bearer {API_KEY}",\n    "Content-Type": "application/json"\n}\n\npayload = {\n    "model": "inflection-2.5",\n    "messages": [\n        {\n            "role": "system",\n            "content": "You are a compassionate and empathetic assistant. Your role is to listen, support, and encourage the user without judgment."\n        },\n        {\n            "role": "user",\n            "content": "最近仕事がうまくいかなくて落ち込んでいます"\n        }\n    ],\n    "temperature": 0.9,\n    "max_tokens": 512\n}\n\nresponse = requests.post(API_URL, json=payload, headers=headers)\nprint(response.json()["choices"][0]["message"]["content"])\n```\n\n### EQ パラメータ\n```python\n# Inflection 独自パラメータ\npayload_with_eq = {\n    "model": "inflection-2.5",\n    "messages": [...],\n    "tone": "empathetic",         # empathetic / supportive / motivational\n    "crisis_detection": True,     # 危機介入シグナルの検知\n    "persona_memory_id": "user_123",  # 長期記憶のユーザーID\n}\n```\n\n### Enterprise 活用例\n```python\n# カスタマーサポート向け感情認識\nresponse = client.analyze_sentiment(\n    text=customer_message,\n    return_emotion=True  # angry / frustrated / satisfied / confused\n)\nif response.emotion == "frustrated":\n    # 謝罪優先の返答に切り替え\n    ...\n```\n\n### リソース\n- 公式: https://inflection.ai/\n- Pi: https://pi.ai/\n- Enterprise: https://inflection.ai/enterprise\n- Research Blog: https://inflection.ai/blog',
  'https://inflection.ai/',
  '2026-04-13',
  3,
  true
),
(
  'inflection',
  'news',
  'Inflection AI 最新情報',
  E'## Inflection AI 最新情報 (2026-04-13)\n\n### 注目トピック\n- **Mustafa SuleimanがMicrosoft AIのCEOに就任**: 2024年3月、Microsoft がInflectionから主要研究者を獲得。Mustafa SuleimanはMicrosoft AI部門を率いる\n- **Inflection AI 独立継続**: MicrosoftへのCEO移籍後もInflection AIは独立企業として継続。Sean WhiteがCEOに就任\n- **Inflection-2.5 公開**: GPT-4に匹敵するとされる最新モデル。感情的知性 (EQ) に加えて一般的な推論性能も大幅向上\n- **Inflection for Enterprise**: カスタマーサポート・社員メンタルヘルス向けのB2B製品を本格展開\n- **Pi 音声機能拡張**: 6種類の音声スタイル (穏やか/活発/プロフェッショナル等) を追加\n- **累計ダウンロード数500万超**: Piアプリのモバイルダウンロードが急増\n\n### DeepMind創業者との繋がり\nMustafa Suleimanは**DeepMind**(Google買収済み)の共同創業者。DeepMindで培った\n「AIを人間の役に立てる」という理念がInflectionの「感情的知性AI」という形で体現されている。\n\n### 市場ポジション\n| 項目 | Inflection Pi | ChatGPT | Claude |\n| --- | --- | --- | --- |\n| 主な用途 | 感情サポート・個人AI | 汎用 | 推論・コード |\n| EQ特化 | ◎ 最高レベル | △ | △ |\n| 音声会話 | ◎ 標準搭載 | ○ Advanced Voice | △ |\n| 記憶機能 | ◎ 長期個人化 | ○ Memory機能 | △ |\n| 危機介入 | ◎ 専門設計 | △ | △ |\n\n> 公式: https://inflection.ai/ | Pi: https://pi.ai/',
  'https://inflection.ai/',
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
