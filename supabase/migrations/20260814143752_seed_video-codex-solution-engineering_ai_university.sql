-- AI大学: YouTube 公開動画を埋め込み学習コンテンツとして登録する。

INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active
)
VALUES (
  'openai',
  'video_codex_solution_engineering',
  'Codexをソリューションエンジニアリングの相棒にする【日本語解説】',
  $content$# 学習ゴール

Codexを、顧客理解から提案・試作・デモ調整まで伴走するソリューションエンジニアリングのパートナーとして活用する流れを理解します。

# この動画から学べること

- 技術から考え始めるのではなく、顧客の課題・業界・目的を先に整理します。
- 顧客のウェブサイトや背景情報をCodexへ渡し、状況に沿った提案と試作の土台を短時間で作ります。
- Codexとの対話を重ね、用途に合うデモへ調整しながら、顧客へ届けるまでの作業を効率化します。
- Codexを単なるコード生成ツールではなく、顧客理解から実装まで協働するパートナーとして使います。

# 実践してみよう

実在または架空の顧客を1社選び、「解決したい課題」「守るべき制約」「見せたい成果」を各1行で書いてください。その3点をCodexへ渡し、15分で試せるデモ案を3つ提案させます。最も顧客価値が明確な案を1つ選び、追加質問をしながら実装手順まで具体化しましょう。

# 参照と注記

参考動画: [Codex as a Solutions Engineering Partner](https://www.youtube.com/watch?v=_jNbM8pV9oI)（OpenAI）

この教材と掲載動画は、公開されている参考動画を基に独自に構成・収録した日本語の要約・解説であり、OpenAI公式の翻訳・吹替ではありません。参考資料の英語自動生成字幕を調査入力として使用しているため、字幕には誤りが含まれる可能性があります。$content$,
  'https://www.youtube.com/watch?v=AfDbWgga8bs',
  '2026-08-14',
  0,
  true
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;
