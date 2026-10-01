-- Issue #4951: apply the Adobe Firefly course refresh as a new migration.
-- PR #5222 updated the already-applied 20260413040000 seed in place, so
-- production correctly reported "Remote database is up to date" and did not
-- receive those row changes. This forward-only migration replays the current
-- canonical seed and verifies the learner-facing contract before commit.

-- Windows版#62: AI大学44社目 — Adobe Firefly
-- 公式情報を確認し、用途・モデル・契約条件から採用可否を判断する実践講座

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'adobe_firefly',
  'overview',
  'Adobe Firefly とは',
  E'## Adobe Firefly とは\n\nAdobe Firefly は、画像・動画・音声・ベクターなどの制作を支援するAdobeの生成AI環境です。Fireflyアプリだけでなく、Photoshop、Illustrator、Adobe Express、Premiereなどの制作フローでも利用できます。\n\n### 「商用利用できるか」を4段階で判断する\n1. **モデル提供元を確認**: Adobe Fireflyモデルか、Firefly内で選べるパートナーモデルかを記録する。\n2. **提供状態を確認**: 一般提供か、beta・preview・early accessかを画面表示と最新の製品条件で確認する。\n3. **権利と用途を確認**: 入力素材の権利、人物の肖像・プライバシー、商標、業界規制、利用地域を確認する。\n4. **証跡を残す**: 使用モデル、プロンプト、入力素材、生成日時、編集内容、Content Credentialsの有無を制作記録に残す。\n\nAdobeは自社Fireflyモデルについて、許諾を得たAdobe Stockなどのコンテンツと著作権が失効した公開コンテンツを学習元として説明しています。また、一般提供されたFirefly機能の出力は商用プロジェクトで利用できると案内しています。ただし、これは個別成果物の適法性を保証する説明ではありません。beta等は画面表示と最新条件を別途確認してください。\n\nパートナーモデルは学習方針、機能、契約条件、商用利用への適合性がモデルごとに異なります。Adobeも、特定案件に適するかは制作者が判断するよう案内しています。法務判断が必要な案件は組織の担当者へ確認し、この教材を法的助言として扱わないでください。\n\n### 公式確認先（2026-09-02確認）\n- Fireflyの概要: https://www.adobe.com/products/firefly.html\n- Adobeの生成AI方針: https://www.adobe.com/ai/overview/firefly/gen-ai-approach.html\n- パートナーモデル: https://www.adobe.com/products/firefly/partner-models.html\n- Firefly FAQ: https://helpx.adobe.com/firefly/get-set-up/learn-the-basics/adobe-firefly-faq.html',
  'https://www.adobe.com/products/firefly.html',
  '2026-09-02',
  1,
  true
),
(
  'adobe_firefly',
  'models',
  'Adobe Firefly 機能・モデル選定ガイド',
  E'## Adobe Firefly 機能・モデル選定ガイド\n\nモデル名や提供条件は更新されるため、固定した世代番号を暗記せず、制作目的から機能を選び、実行時にモデル選択欄と公式ページを確認します。\n\n| 制作目的 | 機能領域 | 成果物の例 | 選定時の確認 |\n| --- | --- | --- | --- |\n| キービジュアル制作 | 画像生成・画像編集 | 広告画像、商品背景、合成案 | 解像度、参照画像の権利、Adobe/パートナーモデル |\n| 動画制作 | 動画生成・動画編集 | 短尺クリップ、補間、Bロール | 秒数、解像度、フレームレート、プレミアム機能の消費量 |\n| 音声制作 | 音声・効果音・翻訳 | 効果音、ナレーション、翻訳音声 | 声・言語・同意、秒数、公開範囲 |\n| デザイン展開 | ベクター・デザイン | 配色案、ベクター素材、テンプレート | 編集可能性、ブランド規定、出力形式 |\n| 企画・比較 | Firefly Boards | ムードボード、構成案、関係者レビュー | 参照素材の出典、比較したモデル、採用理由 |\n| 外部モデル活用 | パートナーモデル | 案件に適した画像・動画・音声 | 学習方針、提供条件、商用適合性、組織ポリシー |\n\n### 選定メモのテンプレート\n```text\n役割 / 制作目的:\n選択した機能・モデル:\nAdobeモデル / パートナーモデル:\n一般提供 / beta等:\n入力素材の権利確認:\n期待する出力仕様:\nContent Credentials・制作記録:\n採用 / 条件付き採用 / 不採用 と理由:\n```\n\n### 公式確認先（2026-09-02確認）\n- 現在の機能一覧: https://www.adobe.com/products/firefly/features.html\n- パートナーモデル一覧: https://www.adobe.com/products/firefly/partner-models.html',
  'https://www.adobe.com/products/firefly/features.html',
  '2026-09-02',
  2,
  true
),
(
  'adobe_firefly',
  'api',
  'Adobe Firefly API・クレジット導入判断',
  E'## Adobe Firefly API とクレジットの導入判断\n\nAdobe Firefly Services APIは、承認済みの制作フローへ生成・編集機能を組み込むための選択肢です。認証方式、利用可能な操作、レート制限、価格、利用条件は変更されるため、サンプルの固定値を本番設計へ転用せず、実装時点のAPIリファレンスと契約を確認してください。資格情報はクライアントへ埋め込まず、組織の秘密管理と最小権限を使います。\n\n### クレジット見積り演習\n1. Adobeの「Generative credits FAQ」を開き、対象機能を**標準**または**プレミアム**に分類する。\n2. 使用モデル、解像度・秒数・文字数など、消費量を左右する条件を記録する。パートナーモデルは個別のレートを確認する。\n3. `1成果物あたりの試行回数 × 1回の消費量 × 月間成果物数 × 利用者数`で月間需要を見積もる。\n4. 現在の契約に含まれるアクセスとクレジットをAdobeアカウントで確認し、20%の再生成余力を加える。\n5. 上限到達時の対応を、待機・品質/尺の変更・承認付き追加購入・別ワークフローから選ぶ。\n\n料金や月間付与数を教材へ固定しないでください。標準機能でも例外があり、プレミアム機能はモデルや出力条件で消費量が変わります。\n\n### 導入判定\n- **採用**: 品質、権利確認、予算、監査記録を満たす。\n- **条件付き採用**: beta、パートナーモデル、機微素材などに追加承認を設定する。\n- **不採用**: 条件を確認できない、予算上限を守れない、必要な証跡を残せない。\n\n### 公式確認先（2026-09-02確認）\n- Generative credits FAQ: https://helpx.adobe.com/creative-cloud/apps/generative-ai/generative-credits-faq.html\n- Firefly Services API: https://developer.adobe.com/firefly-services/docs/firefly-api/\n- Adobe Developer Console: https://developer.adobe.com/console',
  'https://developer.adobe.com/firefly-services/docs/firefly-api/',
  '2026-09-02',
  3,
  true
),
(
  'adobe_firefly',
  'news',
  'Adobe Firefly 30分実践課題',
  E'## Adobe Firefly 30分実践課題\n\nマーケティング、デザイン、動画制作のいずれかの役割を1つ選び、案件への採用可否まで説明できる成果物を作ります。実在人物・第三者のロゴ・権利不明の素材は使いません。\n\n### 進め方\n- **0〜5分: 要件定義** — 対象者、媒体、目的、出力仕様、禁止事項を1枚のメモにする。\n- **5〜10分: 選定** — 機能とモデルを選び、Adobe/パートナー、一般提供/beta、選定理由を記録する。\n- **10〜20分: 制作** — プロンプトを作成し、画像1点、5〜10秒の短尺案1点、または音声/デザイン案1点を生成・編集する。\n- **20〜25分: コスト確認** — 標準/プレミアムを分類し、公式FAQの現行レートで1成果物と月間運用のクレジットを見積もる。\n- **25〜30分: 証跡と判断** — プロンプト、入力素材、モデル、日時、編集内容、Content Credentialsの有無を記録し、採用/条件付き採用/不採用を説明する。\n\n### 提出物\n1. 生成・編集した成果物1点\n2. 要件、プロンプト、選択機能・モデルを記した制作メモ\n3. クレジット見積りと上限到達時の代替案\n4. 権利・提供状態・Content Credentialsの確認結果\n5. 採用判断と根拠（100〜200字）\n\n### 20点ルーブリック（合格14点、各0〜4点）\n| 観点 | 4点の条件 |\n| --- | --- |\n| 要件適合 | 役割、対象者、媒体、目的、仕様が成果物に反映されている |\n| 選定根拠 | 機能、モデル提供元、提供状態を比較して理由を説明できる |\n| 制作品質 | プロンプトと編集意図が明確で、実務で評価できる成果物になっている |\n| コスト | 現行FAQを参照し、試行回数・出力量・利用者数を含む見積りがある |\n| ガバナンス | 入力権利、利用条件、証跡、Content Credentials、必要な承認を確認している |\n\n1項目でも0点がある場合は、合計点にかかわらず再提出です。',
  'https://www.adobe.com/products/firefly/features.html',
  '2026-09-02',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
DO $migration$
BEGIN
  IF (
    SELECT count(*)
    FROM ai_university_content
    WHERE provider = 'adobe_firefly'
      AND category IN ('overview', 'models', 'api', 'news')
      AND published_at::date = DATE '2026-09-02'
      AND is_active
  ) <> 4 THEN
    RAISE EXCEPTION 'Adobe Firefly course refresh did not update all four categories';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM ai_university_content
    WHERE provider = 'adobe_firefly'
      AND category = 'models'
      AND title = 'Adobe Firefly 機能・モデル選定ガイド'
      AND source_url = 'https://www.adobe.com/products/firefly/features.html'
      AND content LIKE '%選定メモのテンプレート%'
      AND content LIKE '%パートナーモデル%'
  ) THEN
    RAISE EXCEPTION 'Adobe Firefly model selection contract is incomplete';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM ai_university_content
    WHERE provider = 'adobe_firefly'
      AND category = 'api'
      AND source_url = 'https://developer.adobe.com/firefly-services/docs/firefly-api/'
      AND content LIKE '%クレジット見積り演習%'
      AND content LIKE '%標準%'
      AND content LIKE '%プレミアム%'
  ) THEN
    RAISE EXCEPTION 'Adobe Firefly credit exercise contract is incomplete';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM ai_university_content
    WHERE provider = 'adobe_firefly'
      AND category = 'overview'
      AND content LIKE '%「商用利用できるか」を4段階で判断する%'
      AND content LIKE '%パートナーモデル%'
      AND content LIKE '%法的助言%'
  ) THEN
    RAISE EXCEPTION 'Adobe Firefly commercial-use decision contract is incomplete';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM ai_university_content
    WHERE provider = 'adobe_firefly'
      AND category = 'news'
      AND title = 'Adobe Firefly 30分実践課題'
      AND content LIKE '%20点ルーブリック%'
      AND content LIKE '%クレジット見積り%'
      AND content LIKE '%Content Credentials%'
  ) THEN
    RAISE EXCEPTION 'Adobe Firefly practical exercise contract is incomplete';
  END IF;
END
$migration$;