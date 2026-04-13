-- Windows版#63: AI大学47社目 — Apple Intelligence
-- Appleが開発するオンデバイスAI。iOS/macOS/iPadOSに深く統合

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'apple',
  'overview',
  'Apple Intelligence とは',
  E'## Apple Intelligence とは\n\n**Apple Intelligence** は2024年のWWDC24で発表された、Appleの**パーソナルインテリジェンスシステム**。\niPhone・iPad・Macに深く統合され、オンデバイスAIとクラウドAIを組み合わせて動作する。\n\n### コアコンセプト\n- **オンデバイス優先**: 個人データはデバイス上で処理。プライバシー最優先\n- **Private Cloud Compute**: デバイスで処理しきれない場合のみAppleサーバーで実行\n- **システム統合**: Siri・メール・メッセージ・Safari等のOS標準アプリと深く連携\n- **App Intents**: サードパーティアプリもApple Intelligenceに機能を公開可能\n\n### 主要機能\n- **Writing Tools**: テキストの書き直し・要約・校正 (全アプリ共通)\n- **Image Playground**: テキストからイラスト生成\n- **Genmoji**: カスタム絵文字生成\n- **Visual Intelligence**: カメラで物体認識・情報取得\n- **Smart Reply**: メール・メッセージの返信候補を自動生成\n- **Notification Summary**: 通知を要約して重要度順に表示\n- **Siri 2.0**: コンテキスト理解の大幅強化・アプリ横断操作\n\n### 対応デバイス\n- iPhone 15 Pro / 16 以降 (A17 Pro / A18チップ)\n- iPad (M1チップ以降)\n- Mac (M1チップ以降)\n\n> 公式: https://www.apple.com/apple-intelligence/',
  'https://www.apple.com/apple-intelligence/',
  '2026-04-13',
  1,
  true
),
(
  'apple',
  'models',
  'Apple Intelligence モデル・技術一覧',
  E'## Apple Intelligence モデル・技術\n\n### オンデバイスモデル\n| モデル | 特徴 | 用途 |\n| --- | --- | --- |\n| **Apple Foundation Model (AFM)** | 約3Bパラメータ・オンデバイス | Writing Tools・Smart Reply |\n| **AFM Server** | より大規模・Private Cloud Compute | 複雑な推論・生成 |\n| **Stable Diffusion (カスタム)** | 画像生成・オンデバイス | Image Playground・Genmoji |\n\n### Private Cloud Compute\n```\nデバイス上で処理できない場合:\n1. 暗号化されたリクエストをAppleサーバーに送信\n2. Apple Silicon搭載サーバーで処理\n3. データはサーバーに保存されない (ステートレス)\n4. 第三者監査で検証可能\n```\n\n### Apple 開発者向け AI ツール\n| フレームワーク | 用途 |\n| --- | --- |\n| **Core ML** | オンデバイスML推論 |\n| **Create ML** | カスタムモデル訓練 |\n| **App Intents** | Siri / Apple Intelligence 連携 |\n| **Writing Tools API** | テキスト編集機能をアプリに統合 |\n| **SiriKit** | 音声コマンド対応 |\n\n### 特徴的な設計哲学\n- **プライバシー第一**: 個人データはデバイス上で処理\n- **セマンティック理解**: メール・メッセージ・カレンダーの横断的な文脈理解\n- **パーソナライズ**: ユーザーの行動パターンに基づく最適化\n- **透明性**: AI生成コンテンツは明示的に表示',
  'https://machinelearning.apple.com/',
  '2026-04-13',
  2,
  true
),
(
  'apple',
  'api',
  'Apple Intelligence 開発者ガイド',
  E'## Apple Intelligence 開発者ガイド\n\n### 注意: 公開APIは限定的\nApple Intelligenceは**エンドユーザー向け機能**であり、他社AI APIのような汎用的なREST APIは提供されていない。開発者はAppleのフレームワーク経由でAI機能にアクセスする。\n\n### Writing Tools API (iOS 18+)\n```swift\n// WritingToolsで要約機能をアプリに追加\nimport WritingTools\n\nlet writingTools = WritingToolsBehavior.default\n// システムのWriting Toolsメニューが自動で表示される\n```\n\n### App Intents (Siri連携)\n```swift\nimport AppIntents\n\nstruct OrderCoffee: AppIntent {\n    static var title: LocalizedStringResource = "Order Coffee"\n    static var description = IntentDescription("Orders your favorite coffee")\n    \n    @Parameter(title: "Coffee Type")\n    var coffeeType: CoffeeType\n    \n    func perform() async throws -> some IntentResult {\n        let order = CoffeeOrder(type: coffeeType)\n        try await order.place()\n        return .result(dialog: "Ordered \\(coffeeType.name)!")\n    }\n}\n```\n\n### Core ML (オンデバイス推論)\n```swift\nimport CoreML\n\nlet config = MLModelConfiguration()\nlet model = try MyCustomModel(configuration: config)\nlet prediction = try model.prediction(input: inputData)\n```\n\n### Image Playground API\n```swift\nimport ImagePlayground\n\n// Image Playground シートを表示\nImagePlaygroundSheet(isPresented: $showPlayground) { url in\n    // 生成画像のURLを受け取る\n    generatedImageURL = url\n}\n```\n\n### リソース\n- Apple Developer: https://developer.apple.com/apple-intelligence/\n- Core ML: https://developer.apple.com/machine-learning/\n- App Intents: https://developer.apple.com/documentation/appintents\n- WWDC Sessions: https://developer.apple.com/videos/',
  'https://developer.apple.com/apple-intelligence/',
  '2026-04-13',
  3,
  true
),
(
  'apple',
  'news',
  'Apple Intelligence 最新情報',
  E'## Apple Intelligence 最新情報 (2026-04-13)\n\n### 注目トピック\n- **iOS 18.4**: Apple Intelligence 日本語対応が正式リリース (2025年4月)\n- **Siri + ChatGPT連携**: Siriが回答できない質問をChatGPTにフォールスルー (ユーザー許可制)\n- **Image Playground**: テキストからイラスト・スケッチ・アニメーション生成\n- **Visual Intelligence**: iPhone 16のカメラで物体を認識→即座に情報取得\n- **Priority Notifications**: AIが通知を重要度で自動分類・要約\n- **Clean Up (写真)**: 写真から不要な物体をAIで自動除去\n- **Apple Foundation Model**: 独自開発の言語モデル。論文公開で透明性確保\n\n### 業界への影響\nApple Intelligence は20億台超のAppleデバイスに展開される史上最大規模のAIデプロイメント。\nオンデバイスAI優先のアプローチはプライバシー重視の新標準を提示。\nGoogleのGemini Nano・Qualcomm NPUと共に「エッジAI」時代を牽引。\n\n### 競合比較\n| 項目 | Apple Intelligence | Google Gemini | Samsung Galaxy AI |\n| --- | --- | --- | --- |\n| 処理場所 | オンデバイス優先 | クラウド+オンデバイス | クラウド中心 |\n| プライバシー | 最高 (PCC) | 中 | 中 |\n| 対応言語 | 英語+日本語等 | 40+言語 | 13言語 |\n| API公開 | 限定的 (App Intents) | 公開 (Gemini API) | 限定的 |\n\n> 公式: https://www.apple.com/apple-intelligence/',
  'https://www.apple.com/apple-intelligence/',
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
